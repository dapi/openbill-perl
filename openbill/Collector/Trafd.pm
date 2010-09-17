package openbill::Collector::Trafd;
use strict;
use locale;
use openbill::DataType::Date;
use IPC::Open3;
use Symbol qw(gensym);
use openbill::Host;
use Date::Parse;
use openbill::Locker;
use openbill::Base;
use openbill::Router;
use openbill::Period;
use openbill::Utils;
use openbill::Locker;
use openbill::Collector::LogShot;
use openbill::System;
use dpl::Context;
use dpl::Log;
use dpl::Db::Database;
use dpl::Db::Filter;
use dpl::Db::Table;
use dpl::Error;
use dpl::Error::Interrupt;
use Time::Format qw(%time %strftime %manip);
use Error qw(:try);
use Exporter;
use vars qw(@ISA
            @EXPORT);


my $local_from=inet_aton('10.100.0.0');
my $local_to=inet_aton('10.100.255.255');

# TODO
# предусмотреть проверку на совместимость с используемым сервисом
# Сделать проверку на последнюю дату при загоне в минуты и дни

@ISA=qw(Exporter
        openbill::Collector);

sub moduleDesc { 'Сборщик статистики trafd' }


sub ParseFiletime {
  my ($self,$file) = @_;
  my @a = ($file=~/^(.+)-(\d{4})-(\d{2})-(\d{2})-(\d{2})[-:](\d{2})(:\d{1,2})?(-.+)?\.trafd\.(.+)$/);
  unless (@a) {
    logger()->debug("Неверное имя файла1: $file");
    return undef;
  }
  my ($hostname,$year,$month,$day,$hour,$min,$sec,$tz,$iface)=@a;
  my $router = router()->Load({hostname=>$hostname})
    || fatal("Такой роутер ненайден: $hostname ($file)");
  $sec=~s/\://; $sec='0' unless $sec; $sec="0$sec" if $sec<10 && $sec!~/^0/;
  my $dstr = "$year-$month-$day $hour:$min:$sec";
  $tz=~s/^\-//;
  $tz='Europe/Moscow' unless $tz; # TODO перенсти в конфиг
  my $time = str2time($dstr,$tz) || fatal("Немогу разобрать время: $file ($dstr,$tz)");
  my $dh = openbill::DataType::Date->new({date=>$time,
                               time_zone=>$tz
                              }); # TODO TImez-one в  конфиг или в базу роутеров
  my $data = table('router_collector')->
    Load({collector_id=>$self->ID(),
          router_id=>$router->ID()});
  unless ($data) {
    logger()->error("нет данных для этого роутера ($file) и коллектора - ".$self->ID()."  rid:".$router->ID());
    return undef;
  }
  $data->{iface} = $iface;
  return ($router,$dh,$data,$iface);
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
#    my $file = $ft->TimeFormat("$name-%Y-%m-%d-%H:%M-%Z.trafd.$_->{iface}");
    push @a,$_->{filename};
    last if $count++>$max;
  }
  return \@a;
}


sub IsIfaceExcluded {
  my ($self,$data) = @_;
  my @ifaces = split(/,/,$data->{exclude_ifaces});
  foreach (@ifaces) {
    return 1 if $_ eq $data->{iface};
  }
  return undef;
}

sub LoadLogFile {
  my ($self,$db,$mindate,$maxdate,$dir,$file,$force_load) = @_;
#  return undef;
  my $iface=$file;
  $iface=~s/^.+\.//;
  my ($router,$dh,$data,$iface) = $self->ParseFiletime($file);
  return undef unless $router;
  open(FILE,"$dir/$file") ||  fatal("Немогу открыть файл $file");
  # TODO Узнать самую младшун дату для конкретного роутера и не добавлять статистику ниже этой даты
  # TODO Использовать для проверки загруженност файла его размер - не стоит заново его загружать и проверить байты

  my $check;
  my $rid = $router->ID();
  my $shot = logshot()->Load({collector_id=>$self->ID(),
                              iface=>$iface,
                              filetime=>$dh,
                              router_id=>$rid})
    || logshot()->Load({collector_id=>$self->ID(),
                        filename=>$file});
  if ($shot) {
    if ($shot->Data('shottime')) {
      if ($force_load) {
        logger()->error("Снимок файла $file уже существут. Удаляю его и закачиваю заново.");
        $shot->Delete();
        $shot = undef;
      } else {
        logger()->debug("Снимок фала $file уже существут и закачан. Отмечаю как не удалённый, проверяю..");
        $shot->MarkAsNotRemoved();
        $check=1;
      }
    } else {
      logger()->error("Снимок файла $file уже существут и не закрыт! Удаляю его и создаю новую запись.");
      $shot->Delete();
      $shot = undef;
    }
  }

  # TODO сделать нормальную проверку на старость (limittime)
  #    if ($dh<$oldest->{$rid}) {
  #      logger()->warn("log-файл $file слишком стар для загрузки (старше самого старшего снимка).");
  #      return undef;
  #    }
  $shot = logshot()->Create({router_id=>$router->ID(),
                             collector_id=>$self->ID(),
                             filename=>$file,
                             filetime=>$dh,
                             iface=>$iface})
    unless $shot;
  if ($self->IsIfaceExcluded($data)) {
    logger()->debug("Интерфейс снимка помечен как исключённый");
    # Запись надо создавать, чтобы удалить потом этот снимок с роутера
    $shot->Close(undef,undef,0,0,0);
    $self->ArchiveLog($dir,$file);
    return 0;
  }
  my $line=0;
  my $maxerrors = 1;
  my $sid = $shot->ID();
  my ($all,$minlogtime,$maxlogtime)=(0,$maxdate,0);
  my ($maxs,$mins)=(0,0);
  my ($date_from,$date_to);
  my ($time_from,$time_to);
  my $line = $self->Data('traflog_line');
  my $cmd = "$line $dir/$file";
  local *CATCHERR = IO::File->new_tmpfile();
  logger()->debug("Запуск traflog: '$cmd'");
  my $pid = open3(gensym, \*FILE, ">&CATCHERR", $cmd);
  my $code = $?;
  my $l;
  # TODO  Сделать кеширование парсированный данных
  my $antivirus=1;
  my $virus_bytes=0;
  my %virus_traff;

  while (<FILE>) {
#    print STDERR "$_\n";
    s/\n|\r//g;
    next unless $_;
    my ($time,$sip,$dip,$bytes) = split(/\s+/);
    #    die "$time - $mindate - $maxdate";
    $line++;
    $all+=$bytes;
    unless ($check) {
      # $time+=300*60;
      # TODO Сделать автоматическую коррекцию по лето/зима
#      next if $antivirus && $self->CheckVirus($sip,$d_port,\%virus_traff);
      my $sth = $db->{dbh}->prepare_cached('insert into traflog values (?,?,?,INET_ATON(?),INET_ATON(?),?,?,?,?)');
      my $logtime = $time;
      if ($logtime>$maxdate) {
        logger()->warn("Время пакета из будущего $logtime>$maxdate");
        $logtime=$maxdate;
        $maxs++;
      } elsif ($logtime<$mindate) {
        logger()->warn("Время пакета из прошлого закрытого периода $logtime<$mindate");
        $logtime=$mindate;
        $mins++;
      }
      $minlogtime=$logtime if $logtime<$minlogtime;
      $maxlogtime=$logtime if $logtime>$maxlogtime;
      $sth->execute($sid,$logtime,$time,$sip,$dip,$bytes,$iface,'-','-');
      if ($l++>1000) {
        print '.';
        $db->{dbh}->commit();
        $l=0;
      }
    }
  }
  my $exit = $?;
  waitpid($pid, 0);
  if ($exit) {
    logger()->error("Ошибка запуска traflog ($cmd): $exit, загружено $all байт");
    return 0;
  }
  logger()->warn("Записей выходящих за открытые пределы  $mindate-$maxdate - ($mins:$maxs) ") if $maxs || $mins;
  if ($check) {
    my $b = $shot->Data('bytes');
    if ($all == $b) {
      logger()->warn("Файл $file уже был загружен");
      $self->ArchiveLog($dir,$file);
      return 0;
    } else {
      logger()->error("Снимок log-файла $file имеет другой траффик: record:$b <> file:$all, перемещают в спецпапку");
      my $d = '/mnt/stats/bad_traff';
      rename("$dir/$file", "$d/$file") || fatal("Немогу переместить файл статистики $file в ахивный каталог $d");
      return 0;
    }
  } else {
    $self->{lines}+=$line;
    print STDERR "Снимок $file загружен. Траффик: $all, Вирусовый трафик: $virus_bytes\n";
    #    $self->SaveVirusTraffic($sid,\%virus_traff);

    logger()->debug("Снимок $file загружен. Траффик: $all");
    $shot->Close($minlogtime,$maxlogtime,$mins,$maxs,$all);
    $self->ArchiveLog($dir,$file);
  }
  return $all;
}

sub MarkRemovedLogs {
  my ($self,$router,$list) = @_;
  logger()->info("Отмечаю логи как удалённые");
  foreach (split(/\s+/,$list)) {
    my ($r,$ft,$d,$iface) = $self->ParseFiletime($_);
    fatal("Удалённый лог [rotuer_id:".$r->ID()."не соответсвует обрабатываемому роутеру [router_id:".$router->ID()."]")
      unless $r->ID()==$router->ID();
    my $shot = logshot()->Load({collector_id=>$self->ID(),
                                iface=>$iface,
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


sub CheckVirus {
  my ($self,$time,$sip,$d_port,$bytes,$packets,$virus_traff) = @_;
  return undef unless $self->IsClient($sip) &&
    $self->AreVirusPort($d_port);

  my $date = $strftime{'%Y-%m-%e',$time};
  my $k = "$date:$sip:$d_port";
  #          print STDERR "save_virus: $k\n";
  $virus_traff->{$k}={} unless exists $virus_traff->{$k};
  my $v = $virus_traff->{$k};
  $v->{bytes}+=$bytes;
  $v->{records}++;
  $v->{packets}+=$packets;
  return $bytes;
}


sub AreVirusPort {
  my $self = shift;
  my $p = shift;
  return ($p>=135 && $p<=139) || $p==445;
}

sub IsClient {
  my $self = shift;
  my $ip =  inet_aton($_[0]);
  return ($ip>=$local_from && $ip<=$local_to);
}


sub SaveVirusTraffic {
  my ($self,$sid,$t) = @_;

  my $db = db();

  foreach my $k (keys %$t) {
    my ($date,$ip,$port)=split(':',$k);
#    print STDERR "VIRUS detected $date $ip->$port\n";
    my $v = $t->{$k};
    my $res = $db->
      SuperSelectAndFetch('select * from viruslog where shot_id=? and date=? and ip=INET_ATON(?) and port=?',
                             $sid,$date,$ip,$port);
    if ($res) {
      $db->Query('update viruslog set bytes=bytes+?, records=records+?, packets=packets+? where shot_id=? and date=? and ip=INET_ATON(?) and port=?',
                 $v->{bytes},$v->{records},$v->{packets},
                 $sid,$date,$ip,$port);
    } else {
      $db->Query('insert into viruslog values (?,?,INET_ATON(?),?,?,?,?)',
                 $sid,$date,$ip,$port,
                 $v->{bytes},$v->{records},$v->{packets}
                );

    }
  }
}


1;
