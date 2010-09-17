package openbill::Collector::Ipcad;
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
use Error qw(:try);
use Exporter;
use vars qw(@ISA
            @EXPORT);

# TODO
# ������������� �������� �� ������������� � ������������ ��������
# ������� �������� �� ��������� ���� ��� ������ � ������ � ���

@ISA=qw(Exporter
        openbill::Collector::Trafd);

sub moduleDesc { '������� ���������� ipcad' }


sub ParseFiletime {
  my ($self,$file) = @_;
  my @a = ($file=~/^(.+)-(\d{4})-(\d{2})-(\d{2})-(\d{2})[-:](\d{2})(:\d+)?(-.+)?\.ipcad$/);
  fatal("�������� ��� �����1: $file") unless @a;
  my ($hostname,$year,$month,$day,$hour,$min,$sec,$tz,$iface)=@a;
  my $router = router()->Load({hostname=>$hostname})
    || fatal("����� ������ ��������: $hostname");
  $sec=~s/\://; $sec='0' unless $sec; $sec="0$sec" if $sec<10;
  my $dstr = "$year-$month-$day $hour:$min:$sec";
  $tz=~s/^\-//;
  $tz='Europe/Moscow' unless $tz; # TODO �������� � ������
  my $time = str2time($dstr,$tz) || fatal(-text=>"������ ��������� �����: $file");
  my $dh = openbill::DataType::Date->new({date=>$time,
                                          time_zone=>$tz
                                         }); # TODO TImez-one �  ������ ��� � ���� ��������
  my $data = table('router_collector')->
    Load({collector_id=>$self->ID(),
          router_id=>$router->ID()})
      || fatal("��� ������ ��� ����� ������� � ���������� - ".$self->ID()."  rid:".$router->ID());
  $iface='none' unless $iface;
  $data->{iface} = $iface;
  return ($router,$dh,$data,$iface,$time);
}


sub LoadLogFile {
  my ($self,$db,$mindate,$maxdate,$dir,$file,$force_load) = @_;
#  return undef;
  open(FILE,"$dir/$file") ||  fatal("������ ������� ���� $file");
  # TODO ������ ����� ������� ���� ��� ����������� ������� � �� ��������� ���������� ���� ���� ����
  # TODO ������������ ��� �������� ������������ ����� ��� ������ - �� ����� ������ ��� ��������� � ��������� �����
  my $iface=$file;
  $iface=~s/^.+\.//;
  my ($router,$dh,$data,$iface,$time) = $self->ParseFiletime($file);
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
  my ($maxs,$mins)=(0,0);
  my ($date_from,$date_to);
  my ($time_from,$time_to);
#  my $line = $self->Data('traflog_line');
#  my $cmd = "$line $dir/$file";
#  local *CATCHERR = IO::File->new_tmpfile();
#  logger()->debug("������ traflog: '$cmd'");
#  my $pid = open3(gensym, \*FILE, ">&CATCHERR", $cmd);
#  my $code = $?;
  my $l;
#  open(FILE,$file) || fatal("������ �������� ����� $file");
  # TODO  ������� ����������� ������������� ������
  while (<FILE>) {
    s/\n|\r//g;
    s/^\s+//;
    next if !$_ || /^Source/;
    next if !$_ || /^Account/;

    my ($sip,$dip,$packets,$bytes) = split(/\s+/);
    #    die "$time - $mindate - $maxdate";
    $line++;
    $all+=$bytes;
    unless ($check) {
      # $time+=300*60;
      # TODO ������� �������������� ��������� �� ����/����
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
            $sth->execute($sid,$logtime,$time,$sip,$dip,$bytes,$iface,'-','-');
      if ($l++>1000) {
        print '.';
        $db->{dbh}->commit();
        $l=0;
      }
    }
  }
  close(FILE);
#   my $exit = $?;
#   waitpid($pid, 0);
# #  die $line;
#   if ($exit) {
#     logger()->error("������ ������� traflog - $exit");
#     return $all;
#   }
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
    logger()->debug("������ $file ��������. �������: $all");
    $shot->Close($minlogtime,$maxlogtime,$mins,$maxs,$all);
    $self->ArchiveLog($dir,$file);
  }
  return $all;
}


1;
