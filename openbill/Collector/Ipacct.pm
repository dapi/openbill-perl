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
# ������������� �������� �� ������������� � ������������ ��������
# ������� �������� �� ��������� ���� ��� ������ � ������ � ���

@ISA=qw(Exporter
        openbill::Collector::Trafd);

sub moduleDesc { '������� ���������� ipacct' }


sub ParseFiletime {
  my ($self,$file) = @_;
  my @a = ($file=~/^(.+)-(\d{4})-(\d{2})-(\d{2})-(\d{2})[-:](\d{2})(:\d{2})?(-.+)?\.ipacct\.(.+)$/);
  unless (@a) {
    logger()->debug("�������� ��� �����1: $file");
    return undef;
  }
  my ($hostname,$year,$month,$day,$hour,$min,$sec,$tz,$iface)=@a;




  # !!!!!
  ## ORIONET HACK
  #!!!!

  #$hostname='radius' if $hostname eq 'vpn.orionet.ru';



  my $router = router()->Load({hostname=>$hostname})
    || fatal("����� ������ ��������: $hostname");
  $sec=~s/\://; $sec='0' unless $sec; $sec="0$sec" if $sec<10 && $sec!~/^0/;
  my $dstr = "$year-$month-$day $hour:$min:$sec";
  $tz=~s/^\-//;
  $tz='Europe/Moscow' unless $tz; # TODO �������� � ������
  my $time = str2time($dstr,$tz) || fatal("������ ��������� �����: $file ($dstr,$tz)");
  my $dh = openbill::DataType::Date->new({date=>$time,
                               time_zone=>$tz
                              }); # TODO TImez-one �  ������ ��� � ���� ��������
  my $data = table('router_collector')->
    Load({collector_id=>$self->ID(),
          router_id=>$router->ID()});
  unless ($data) {
    logger()->error("��� ������ ��� ����� ������� � ���������� - ".$self->ID()."  rid:".$router->ID());
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
    logger()->error("������ ����� $file ������� �������: $max_size");
    print "������ ����� $file ������� �������: $max_size\n";
    fatal("������ ����� $file ������� �������: $max_size");
#    return undef;
  }


  open(FILE,"$dir/$file") ||  fatal("������ ������� ���� $file");
  # TODO ������ ����� ������� ���� ��� ����������� ������� � �� ��������� ���������� ���� ���� ����
  # TODO ������������ ��� �������� ������������ ����� ��� ������ - �� ����� ������ ��� ��������� � ��������� �����

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
        logger()->error("������ ����� $file ��� ���������. ������ ��� � ��������� ������.");
        $shot->Delete();
        $shot = undef;
      } else {
        logger()->debug("������ ���� $file ��� ��������� � �������. ������� ��� �� ���̣����, ��������..");
        $shot->MarkAsNotRemoved();
        $check=1;
      }
    } else {
      logger()->error("������ ����� $file ��� ��������� � �� ������! ������ ��� � ������ ����� ������.");
      $shot->Delete();
      $shot = undef;
    }
  }

  # TODO ������� ���������� �������� �� �������� (limittime)
  #    if ($dh<$oldest->{$rid}) {
  #      logger()->warn("log-���� $file ������� ���� ��� �������� (������ ������ �������� ������).");
  #      return undef;
  #    }
  $shot = logshot()->Create({router_id=>$router->ID(),
                             collector_id=>$self->ID(),
                             filename=>$file,
                             filetime=>$dh,
                             iface=>$iface})
    unless $shot;
  if ($self->IsIfaceExcluded($data)) {
    logger()->debug("��������� ������ ������� ��� �����ޣ����");
    # ������ ���� ���������, ����� ������� ����� ���� ������ � �������
    $shot->Close(undef,undef,0,0,0);
    $self->ArchiveLog($dir,$file);
    return 0;
  }
  my $line=0;
  my $maxerrors = 1;

  my $sid = $shot->ID();
  my ($all,$minlogtime,$maxlogtime)=(0,$maxdate,0);

  unless (open(FILE,"$dir/$file")) {
    logger()->error("�� ���� ������� ���� $dir/$file");
    return undef;
  }
  my $l;

  my $antivirus=1;
  my $virus_bytes=0;
  my %virus_traff;
  # TODO  ������� ����������� ������������� ������
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
        logger()->error("������ Time::TAI64::tai2unix($1) � ������ $line");
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
      # TODO ������� �������������� ��������� �� ����/����

      if ($antivirus) {
        my $v = $self->CheckVirus($time,$sip,$d_port,$bytes,$packets,\%virus_traff);
        $virus_bytes+=$v;
        next if $v;
      }

      my $sth = $db->{dbh}->prepare_cached('insert into traflog values (?,?,?,INET_ATON(?),INET_ATON(?),?,?,?,?)');
      my $logtime = $time;
      if ($logtime>$maxdate) {
        logger()->warn("����� ������ �� �������� $logtime>$maxdate");
        $logtime=$maxdate;
        $maxs++;
      } elsif ($logtime<$mindate) {
        logger()->warn("����� ������ �� ��������� ��������� ������� $logtime<$mindate");
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
  logger()->warn("������� ��������� �� �������� �������  $mindate-$maxdate - ($mins:$maxs) ") if $maxs || $mins;
  if ($check) {
    my $b = $shot->Data('bytes');
    if ($all == $b) {
      logger()->warn("���� $file ��� ��� ��������");
      $self->ArchiveLog($dir,$file);

      return 0;
    } else {
      logger()->error("������ log-����� $file ����� ������ �������: record:$b <> file:$all");
      return 0;
    }
  } else {
    $self->{lines}+=$line;
    print STDERR "������ $file ��������. �������: $all, ��������� ������: $virus_bytes\n";
    $self->SaveVirusTraffic($sid,\%virus_traff);
#    die 1;
    logger()->debug("������ $file ��������. �������: $all, ��������� ������: $virus_bytes");
    $shot->Close($minlogtime,$maxlogtime,$mins,$maxs,$all,$virus_bytes);

    $self->ArchiveLog($dir,$file);
  }
  return $all;
}

1;
