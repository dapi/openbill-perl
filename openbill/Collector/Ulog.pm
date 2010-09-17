package openbill::Collector::Ulog;
use strict;
use locale;
use openbill::DataType::Date;
use openbill::Host;
use Date::Parse;
use openbill::Base;
use openbill::Router;
use openbill::Period;
use openbill::Utils;
use openbill::System;
use openbill::Collector::LogShot;
use dpl::Context;
use dpl::Log;
use dpl::Db::Database;
use dpl::Db::Filter;
use dpl::Error;
use dpl::Db::Table;
use dpl::Error::Interrupt;
use Error qw(:try);
use Exporter;
use vars qw(@ISA
            @EXPORT);

# TODO
# предусмотреть проверку на совместимость с используемым сервисом
# Сделать проверку на последнюю дату при загоне в минуты и дни
#



@ISA=qw(Exporter
        openbill::Collector);


sub moduleDesc { 'Сборщик статистики ulog-acctd' }


sub ParseFiletime {
  my ($self,$file) = @_;
  my @a = ($file=~/^(.*\/)?(\S+)-(\d{4})-(\d{2})-(\d{2})-(\d{2}):(\d{2})(-.+)?\.log$/);
  fatal("Неверное имя файла: $file")
    unless @a;
  my ($path,$hostname,$year,$month,$day,$hour,$min,$tz)=@a;
  my $router = router()->Load({hostname=>$hostname})
    || fatal("Такой роутер ненайден: $hostname");
  my $dstr = "$year-$month-$day $hour:$min:00";
  $tz=~s/^\-//;
  $tz='GMT' unless $tz; # TODO перенсти в конфиг
  my $time = str2time($dstr,$tz) || fatal(-text=>"Немогу разобрать время: $file");
  my $dh = openbill::DataType::Date->new({date=>$time,
                                          time_zone=>$tz
                                         }); # TODO TImez-one в  конфиг или в базу роутеров
  my $data = table('router_collector')->Load({collector_id=>$self->ID(),
                                              router_id=>$router->ID()})
    || fatal("нет данных для этого роутера и коллектора - ".$self->ID()."  rid:".$router->ID());
  return ($router,$dh,$data);
}

sub LoadLogFile {
  my ($self,$db,$mindate,$maxdate,$dir,$file,$force_load) = @_;
  open(FILE,"$dir/$file") ||  fatal("Немогу открыть файл $file");
  # TODO Узнать самую младшун дату для конкретного роутера и не добавлять статистику ниже этой даты
  # TODO Использовать для проверки загруженност файла его размер - не стоит заново его загружать и проверить байты

  my ($router,$dh,$data) = $self->ParseFiletime($file);
  my $check;
  my $rid = $router->ID();
  my $shot = logshot()->Load({collector_id=>$self->ID(),
                              filetime=>$dh,
                              router_id=>$rid})
    || logshot()->Load({collector_id=>$self->ID(),
                        filename=>$file});
  #  die 2;
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
  #      logger()->warn("Ulog-файл $file слишком стар для загрузки (старше самого старшего снимка).");
  #      return undef;
  #    }

  $shot = logshot()->Create({router_id=>$router->ID(),
                             filename=>$file,
                             collector_id=>$self->ID(),
                             filetime=>$dh})
    unless $shot;

  my $line=0;
  my $maxerrors = 1;
  my $sid = $shot->ID();
  my ($all,$minlogtime,$maxlogtime)=(0,$maxdate,0);
  my ($maxs,$mins)=(0,0);
  return try {
    while (<FILE>) {
      $line++;
      s/\n$//;
      my @a = split("\t");
      #      die $a[13] if scalar @a==13;# && $a[12]==-1;
      pop @a if scalar @a==13 && $a[12]=~/^-?\d+$/;
      splice(@a,1,1) if $a[2]=~/^\d{9,10}$/;
      splice(@a,9,1) if scalar @a==13 && $a[9] eq 'U';
#      if (scalar @a==10) {
#        my @b=@a;
#        @a=('',$a[0],0,$a[2],$a[3],$a[4],$a[5],1,$a[6],'-','-',$a[0]);
#      }
      unless (scalar @a==12) {
        print "\n" if setting('terminal');
        logger()->error("Строка $line в ulog-файле $file содержит неверное число столбцов (".scalar @a."<>12)");
        # TODO
        # throw , если не force
        unless ($maxerrors) {
          #          $shot->Delete();
          return undef;
        }
        $maxerrors--;
        next;
      }
      my ($hostname,$time,$prot,
          $sip,$sp,$dip,$dp,
          $packets,$bytes,
          $in_iface,$out_iface,
          $prefix)=@a;
      next if $prefix=~/DENY/ || $sip eq '127.0.0.1' || $dip eq '127.0.0.1';
      $all+=$bytes;
      unless ($check) {
        #  $time+=300*60; # TODO Сделать автоматическую коррекцию по лето/зима
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
        $sth->execute($sid,$logtime,$time,$sip,$dip,$bytes,$in_iface,$out_iface,$prefix);
        unless ($line && 1000) {
          print '.';
          $db->{dbh}->commit();
        }
      }
    }
    close(FILE);
    logger()->warn("Записей выходящих за открытые пределы $mindate-$maxdate - ($mins:$maxs) ") if $maxs || $mins;
    if ($check) {
      my $b = $shot->Data('bytes');
      if ($all == $b) {
        logger()->warn("Файл $file уже был загружен");
        $self->ArchiveLog($dir,$file);
        return 0;
      } else {
        logger()->error("Снимок ulog-файла $file имеет другой траффик: record:$b <> file:$all");
        return 0;
      }
    } else {
      $self->{lines}+=$line;
      logger()->debug("Снимок $file загружен. Траффик: $all");
      $shot->Close($minlogtime,$maxlogtime,$mins,$maxs,$all);
      $self->ArchiveLog($dir,$file);
    }
    return $all;
  } catch dpl::Error::Interrupt with {
    my $e = shift;
    $e->throw();
  } otherwise {
    my $e = shift;
    print STDERR "Ошибка ($e) при загрузке файла $file (строка: $line)\n";
    $e->throw(@_);
  } finally {
    my $shottime = $shot->Data('shottime');
    #    throw dpl::Error("Снимок имеет не верную стадию! ($s)");
    unless ($shottime) {
      #      die 'не должен удалять' unless $delete;
      logger()->warn("Удаляю недокачанный снимок и его статистику, sid=",$shot->ID());
      my $save = $SIG{INT};
      $SIG{INT}='IGNORE';
      $shot->Delete();
      $SIG{INT}=$save;
    }
  };

}

1;
