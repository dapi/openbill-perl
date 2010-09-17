package openbill::Collector;
use strict;
use openbill::Host;
use openbill::Base;
use openbill::Router;
use openbill::Period;
use openbill::Utils;
use openbill::Locker;
use dpl::Context;
use dpl::System;
use dpl::Log;
use dpl::Error;
use dpl::Db::Table;
use dpl::Db::Filter;
use dpl::Db::Database;
use openbill::Collector::LogShot;
use openbill::Collector::DayShot;
use openbill::Collector::MinutShot;
use openbill::System;
use Error qw(:try);
use Exporter;
use vars qw(@ISA
            %GETLOG_STATUS
            @EXPORT);

@ISA=qw(Exporter
        openbill::Base);

@EXPORT=qw(collector);

%GETLOG_STATUS=(OPT=>2,ARCHIVE=>1,REPORT=>2,WARNING=>2,EXISTS=>1,ROTATE=>2,ZERO=>1,COLLECT=>1,SEND=>2,ERROR=>2,EXIT=>1,DELETE=>1,SENDFILES=>2,ROTATE=>2);


sub collector {
  return openbill::Collector->instance('collector',@_);
}

sub string {
  my $self = shift;
  my $str = $self->SUPER::string(@_);
  $str.="\n\tgroup by: ".join(', ',@{$self->{extdata}->{group_by}})."\n\tclasses [default: $self->{extdata}->{classes}->{default}]: ";
  my $c = $self->{extdata}->{classes}->{classes};
  foreach (keys %$c) {
    $str.="$_=".join(', ',@{$c->{$_}})." ";
  }
  return $str;
}

sub DataFull {
  my ($self,$key) = @_;
  $self->Load() unless $self->isLoaded();
  return $key ? $self->{data}->{$key} : $self->{data};
}

sub Create  {
  my ($self,$data) = @_;
  $self->checkParams($data,'name','module','arc_dir','work_dir');
  return $self->SUPER::Create($data);
}

sub GetNotRemovedList {
  my ($self,$router) = @_;
  my $rid = $router->ID();
  my $id = $self->ID();
  my $list  = db()->SelectAndFetchAll(qq(select * from log_shot
                                         where is_removed=0 and router_id=$rid and collector_id=$id
                                         and shottime is not null));
  my @a;
  my $max=500;
  my $count=0;
  my $name = $router->Data('hostname');
  foreach (@$list) {
#    my $ft = filter('datetime')->FromSQL($_->{filetime});
#    $ft->TimeZone('GMT');
#    my $file = $ft->TimeFormat("$name-%Y-%m-%d-%H:%M-%Z.log");
    push @a,$_->{filename};
    last if $count++>$max;
  }
  return \@a;
}


sub MarkRemovedLogs {
  my ($self,$router,$list) = @_;
  logger()->info("Отмечаю логи как удалённые");
  foreach (split(/\s+/,$list)) {
    my ($r,$ft,$d) = $self->ParseFiletime($_);
    fatal("Удалённый лог [rotuer_id:".$r->ID()."] не соответсвует обрабатываемому роутеру [router_id:".$router->ID()."]")
      unless $r->ID()==$router->ID();
    my $shot = logshot()->Load({collector_id=>$self->ID(),
                                filetime=>$ft,
                                router_id=>$r->ID()});
    if ($shot) {
      $shot->MarkAsRemoved($r,$ft);
    } else {
      logger()->error("Ненайден снимок для пометки удалённым rid:".$r->ID()." filetime:$ft");
    }
  }
  db()->Commit();
}

sub ArchiveLog {
  my ($self,$dir,$file) = @_;
  my $arc_dir = $self->Data('arc_dir') || fatal("В коллекторе не установлен архивный каталог статистики");
#  logger()->debug("Кладу в архив $file");
  rename("$dir/$file", "$arc_dir/$file") || fatal("Немогу переместить файл статистики $file в ахивный каталог $arc_dir");
}


# TODO
# Переделать - сначала просматривать файлы, изходя из их имени вытаскивать роутер и коллектор

sub LoadTraff {
  my ($self,$p) = @_;
  my $db = db();
  $self->{lines}=0;
  StartTimer('load');
  my $dir = $self->Data('work_dir') || fatal("В коллекторе не установлен рабочий каталог статистики");
  my ($shots,$errors,$bytes);
#  my $lock = Locker('ulog','write');
  opendir(DIR,$dir) || fatal("Не могу открыть каталог статистики '$dir'");
  my $ext = $self->Data('ext');
  print "\nКоллектор ".$self->Data('name')."\nВсего файлов для загрузки ($dir,$ext) "
    if setting('terminal');
  #  my @f = grep {$ext ? /$ext$/x : -f "$dir/$_"} readdir(DIR);
  my @f = grep {-f "$dir/$_"} readdir(DIR);
  print "(".scalar @f.") " if setting('terminal');
  # TODO Оптимизировать сортировку. Надо ли её использовать вообще?
  # TODO сделать сортировку подате, а не по имени бриджа, как сейчас
  my $all = $p->{sort} ? [sort {
    my $aa=substr($a,length($a)-24,24);
    my $bb=substr($b,length($a)-24,24);
    $aa cmp $bb;
  } @f] : \@f;
  print " - " if setting('terminal');
  my $count = scalar @$all;
  do {
    my @files;
    if ($p->{max}) {
      @files=splice(@$all,0,$p->{max});
      @$all=splice(@$all,$p->{max}) if $p->{partes};
    } else {
      @files=@$all;
    }

    my $max = scalar @files;
    unless ($max) {
      print "нет.\n" if setting('terminal');
      logger()->debug('Файлов для загрузки в базу нет');
      return {};
    }
    $p->{size}=500000000 unless $p->{size};
    try {

      # TODO
      # Сделать проверку на страйший filetime и может на загшружать если дата загружаемого старше файла
      #    my $oldest = logshot()->GetOldestFiletimes();
      print "$max\n" if setting('terminal');
      # TODO Надо чтобы минимальная-максимальная дата передавались в эту процедуру. Исключить use period, service
      # TODO ?Запомнить удалйнные снимки и просигнализировать если они не будут загружены в будущем
      # TODO Загружать таблицу роутеров предварительно и не закрывать эту таблицу
      # TODO Надо брать все сервисы, которыйе могут использовать ulog
      openbill::Period::period()->CreateIfNeed(today());
      my $mindate = openbill::Period::period()->GetMinimalOpenDate();
      my $maxdate = today()+setting('today_plus');
      fatal('internal error') unless $mindate;
      logger()->debug("Ограничение по датам: $mindate - $maxdate");
      # TODO  Может блокировать весь ulog и проверять?
      logshot()->DeleteBroken();
      foreach my $file (@files) {
#        last if IsInterrupted();
        $shots++;
        try {
          print "\r$max/$shots ($file) - " if setting('terminal');
          $bytes+=$self->LoadLogFile($db,$mindate->Epoch(),$maxdate->Epoch(),
                                     $dir,$file,$p->{force},$p->{size});
          my $b = FormatBytes($bytes,1);
          my $sec = GetTimer('load',0);
          print "$b байт / $self->{lines} строк / $sec сек.  " if setting('terminal');
        } catch openbill::Collector::Error with {
          my $e = shift;
          print STDERR "Строка $self->{lines}\n";

          logger()->error("Файл не загружен - $e ".$e->stringify());
        };
      }
      closedir(DIR);
      print "\n"  if setting('terminal');
      return {shots=>$shots,
              timer=>GetTimer('load'),
              errors=>$errors,
              bytes=>$bytes};
    } finally {
      print "Ok.\n" if setting('terminal');
    };
  } while ($p->{partes});
}

sub init {
  my ($self,$id,$data) = @_;
  return $self unless $self->isLoaded();
#  return $self unless $id;
#  $self->Load($id,$data);
  my $module = $self->Data('module');
  return $self if !$module || $module eq ref($self);
  return $self->changeClass(openbill::System::GetModules('collector')->{$module}->{file},$module);
}

sub Create  {
  my ($self,$data) = (shift,shift);
  $self->checkParams($data,'name','module');
  return $self->SUPER::Create($data,@_);
}

sub Collect {
  my ($self,$p) = @_;
  StartTimer('download');
  my $lock = Locker('collector','write');
  my $list = table('router_collector')->
    List({collector_id=>$self->ID()});
  $p={} unless $p;
  unless ($p->{no_collect}) {
    foreach my $rc (@$list) {
      my $router = router($rc->{router_id});
      next if (!$rc->{is_active} || !$router->Data('is_active'))
        && $router->Data('hostname') ne $p->{router};
      next if exists $p->{router} && $router->Data('hostname') ne $p->{router};
      $self->CollectRouter($router,$rc);
    }
  }
  $self->LoadTraff($p);
}

sub CollectRouter {
  my ($self,$router,$rc) = @_;
  #  my $lock = Locker('collector::ulog','write',$router->ID());
  my $r= $router->Data();
  #  TODO ставить filelock
#   if (setting('terminal') && !$r->{is_active}) {
#     print "Скачиватие данных запрещено\n\n";
#     return 0;
#   }
  print "Сбор статистики с роутера $r->{hostname}: "
    if setting('terminal');
  my $dir = $rc->{work_dir} || $self->Data('work_dir');
  my $toremove = $self->GetNotRemovedList($router);
  logger()->debug("Соединяюсь с роутером $r->{hostname}");
  #TODO
  # Проверить почему не выходит, если каталог $dir для tar-а не указан. Tar выдаёт ошибку при этом.
  # Вэтом случае возможна архивация логов на роутере, при том, что они действительно не были переданы
  # Сделатьархиваци ютолько при повтороном  обращении - передавать дату последнего принятого лога.
  StartTimer('download');
  my $cl = $rc->{command_line} || $self->Data('command_line');

  $cl=~s/local\///; # TODO злой HACK

  my $status = RemoteExecute
    ($cl || fatal('Не указана командная строка'),\%GETLOG_STATUS,
     {login=>$rc->{login} || $r->{login},
      dir=>$dir,
      toremove=>join(' ',@$toremove),
      ip=>$r->{real_ip},
      hostname=>$r->{hostname}});
  my $s=GetTimer('download');
  my @files = split(/\s+/,$status->{COLLECT});
  my $count  = scalar @files;
  if ($count) {
    # TODO
    # Писать логи во временный каталоги потом их перемещать в рабочий
    print "$count файлов. $s сек.\n"
      if setting('terminal');
  } else {
    print "Нет новых файлов. $s сек.\n"
      if setting('terminal');
  }
  $self->MarkRemovedLogs($router,$status->{DELETE})
    if $status->{DELETE};
  $self->MarkRemovedLogs($router,$status->{ARCHIVE})
    if $status->{ARCHIVE};
  if ($status->{ROTATE}) {
    logger()->error("Счётчик был ротирован и не возвратился из ожидающего режима [router_id:$r->{router_id}]")
      unless $status->{ROTATE}->[$#{$status->{ROTATE}}] eq 'done';
  }
}

sub string {
  my $self = shift;
  my $d = $self->Data();
  my $id = $self->ID();
  return "[$id]\t$d->{name}\t$d->{module}\t$d->{comment}";
}

sub List {
  my ($self,$p) = @_;
  my @collectors;
  my $list = table('collector')->List();
  foreach (@$list) {
    next if $p->{module} && $_->{module}!=$p->{module};
    push @collectors, collector($_->{collector_id},$_);
  }
  return wantarray ? @collectors : \@collectors;
}

sub TruncateStats {
  my $self = shift;
  die 'not implemented';
}

sub error {
  my $self = shift;
  logger()->error(@_);
  throw openbill::Collector::Error(@_);
}

package openbill::Collector::Error;
@openbill::Collector::Error::ISA = qw(dpl::Error);


1;
