package openbill::Collector::Ipacct;
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
use Time::TAI64;
use Error qw(:try);
use Exporter;
use vars qw(@ISA
            @EXPORT);


# TODO
# предусмотреть проверку на совместимость с используемым сервисом
# Сделать проверку на последнюю дату при загоне в минуты и дни

@ISA=qw(Exporter
        openbill::Collector::Trafd);

sub moduleDesc { 'Сборщик статистики ipacct' }


sub ParseFiletime {
  my ($self,$file) = @_;
  my @a = ($file=~/^(.+)-(\d{4})-(\d{2})-(\d{2})-(\d{2})[-:](\d{2})(:\d{2})?(-.+)?\.ipacct\.(.+)$/);
  unless (@a) {
    logger()->debug("Неверное имя файла1: $file");
    return undef;
  }
  my ($hostname,$year,$month,$day,$hour,$min,$sec,$tz,$iface)=@a;




  # !!!!!
  ## ORIONET HACK
  #!!!!

  #$hostname='radius' if $hostname eq 'vpn.orionet.ru';



  my $router = router()->Load({hostname=>$hostname})
    || fatal("Такой роутер ненайден: $hostname");
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
    logger()->error("нет данных для этого роутера и коллектора - ".$self->ID()."  rid:".$router->ID());
    fatal(1);
    return undef;
  }
  $data->{iface} = $iface;
  return ($router,$dh,$data,$iface);
}

sub LoadLogFile {
  my ($self,$db,$mindate,$maxdate,$dir,$file,$force_load,$max_size) = @_;
#  return undef;
  my $iface=$file;
  $iface=~s/^.+\.//;
  my ($router,$dh,$data,$iface) = $self->ParseFiletime($file);
  return undef unless $router;


  my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
	                       $atime,$mtime,$ctime,$blksize,$blocks)=stat("$dir/$file");
  if ($size>$max_size) {
    logger()->error("Сником файла $file слишком большой: $max_size");
    print "Сником файла $file слишком большой: $max_size\n";
    fatal("Сником файла $file слишком большой: $max_size");
#    return undef;
  }


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

  unless (open(FILE,"$dir/$file")) {
    logger()->error("Не могу открыть файл $dir/$file");
    return undef;
  }
  my $l;

  my $antivirus=1;
  my $virus_bytes=0;
  my %virus_traff;
  # TODO  Сделать кеширование парсированный данных
  my $ftime = $dh->Epoch();
  my ($maxs,$mins)=(0,0);
  while (<FILE>) {
    s/\n|\r//g;
    if (/exceed/) {
      logger()->error("$file - $_");
      next;
    }
    $line++;
    next unless $_;
    my $time;
    if (s/(\@[0-9a-z]+)\s+//) {
      $time = Time::TAI64::tai2unix($1);
      unless ($time) {
        logger()->error("Ошибка Time::TAI64::tai2unix($1) в строке $line");
        $time=$ftime;
      }
    } else {
      $time=$ftime;
    }
    my ($sip,$s_port,$dip,$d_port,$proto,$packets,$bytes) = split(/\t/,$_);
    #    die "$time - $mindate - $maxdate";
    $all+=$bytes;
    unless ($check) {
      # $time+=300*60;
      # TODO Сделать автоматическую коррекцию по лето/зима

      if ($antivirus) {
        my $v = $self->CheckVirus($time,$sip,$d_port,$bytes,$packets,\%virus_traff);
        $virus_bytes+=$v;
        next if $v;
      }

      my $sth = $db->{dbh}->prepare_cached('insert into traflog values (?,?,?,INET_ATON(?),INET_ATON(?),?,?,?,?)');
      my $logtime = $time;
      if ($logtime>$maxdate) {
        logger()->warn("Время пакета из будущего $logtime>$maxdate");
        $logtime=$maxdate;
        $maxs++;
      } elsif ($logtime<$mindate) {
        logger()->warn("Время пакета из прошлогго закрытого периода $logtime<$mindate");
        $logtime=$mindate;
        $mins++;
      }
      $minlogtime=$logtime if $logtime<$minlogtime;
      $maxlogtime=$logtime if $logtime>$maxlogtime;

      $sth->execute($sid,$time,$time,$sip,$dip,$bytes,$iface,'-','-');
      if ($l++>1000) {
        print '.';
        $db->{dbh}->commit();
        $l=0;
      }
    }
  }
  close(FILE);
  logger()->warn("Записей выходящих за открытые пределы  $mindate-$maxdate - ($mins:$maxs) ") if $maxs || $mins;
  if ($check) {
    my $b = $shot->Data('bytes');
    if ($all == $b) {
      logger()->warn("Файл $file уже был загружен");
      $self->ArchiveLog($dir,$file);

      return 0;
    } else {
      logger()->error("Снимок log-файла $file имеет другой траффик: record:$b <> file:$all");
      return 0;
    }
  } else {
    $self->{lines}+=$line;
    print STDERR "Снимок $file загружен. Траффик: $all, Вирусовый трафик: $virus_bytes\n";
    $self->SaveVirusTraffic($sid,\%virus_traff);
#    die 1;
    logger()->debug("Снимок $file загружен. Траффик: $all, Вирусовый трафик: $virus_bytes");
    $shot->Close($minlogtime,$maxlogtime,$mins,$maxs,$all,$virus_bytes);

    $self->ArchiveLog($dir,$file);
  }
  return $all;
}

1;
