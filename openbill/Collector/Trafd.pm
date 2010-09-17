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
# ������������� �������� �� ������������� � ������������ ��������
# ������� �������� �� ��������� ���� ��� ������ � ������ � ���

@ISA=qw(Exporter
        openbill::Collector);

sub moduleDesc { '������� ���������� trafd' }


sub ParseFiletime {
  my ($self,$file) = @_;
  my @a = ($file=~/^(.+)-(\d{4})-(\d{2})-(\d{2})-(\d{2})[-:](\d{2})(:\d{1,2})?(-.+)?\.trafd\.(.+)$/);
  unless (@a) {
    logger()->debug("�������� ��� �����1: $file");
    return undef;
  }
  my ($hostname,$year,$month,$day,$hour,$min,$sec,$tz,$iface)=@a;
  my $router = router()->Load({hostname=>$hostname})
    || fatal("����� ������ ��������: $hostname ($file)");
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
    logger()->error("��� ������ ��� ����� ������� ($file) � ���������� - ".$self->ID()."  rid:".$router->ID());
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
  my ($maxs,$mins)=(0,0);
  my ($date_from,$date_to);
  my ($time_from,$time_to);
  my $line = $self->Data('traflog_line');
  my $cmd = "$line $dir/$file";
  local *CATCHERR = IO::File->new_tmpfile();
  logger()->debug("������ traflog: '$cmd'");
  my $pid = open3(gensym, \*FILE, ">&CATCHERR", $cmd);
  my $code = $?;
  my $l;
  # TODO  ������� ����������� ������������� ������
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
      # TODO ������� �������������� ��������� �� ����/����
#      next if $antivirus && $self->CheckVirus($sip,$d_port,\%virus_traff);
      my $sth = $db->{dbh}->prepare_cached('insert into traflog values (?,?,?,INET_ATON(?),INET_ATON(?),?,?,?,?)');
      my $logtime = $time;
      if ($logtime>$maxdate) {
        logger()->warn("����� ������ �� �������� $logtime>$maxdate");
        $logtime=$maxdate;
        $maxs++;
      } elsif ($logtime<$mindate) {
        logger()->warn("����� ������ �� �������� ��������� ������� $logtime<$mindate");
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
    logger()->error("������ ������� traflog ($cmd): $exit, ��������� $all ����");
    return 0;
  }
  logger()->warn("������� ��������� �� �������� �������  $mindate-$maxdate - ($mins:$maxs) ") if $maxs || $mins;
  if ($check) {
    my $b = $shot->Data('bytes');
    if ($all == $b) {
      logger()->warn("���� $file ��� ��� ��������");
      $self->ArchiveLog($dir,$file);
      return 0;
    } else {
      logger()->error("������ log-����� $file ����� ������ �������: record:$b <> file:$all, ���������� � ���������");
      my $d = '/mnt/stats/bad_traff';
      rename("$dir/$file", "$d/$file") || fatal("������ ����������� ���� ���������� $file � ������� ������� $d");
      return 0;
    }
  } else {
    $self->{lines}+=$line;
    print STDERR "������ $file ��������. �������: $all, ��������� ������: $virus_bytes\n";
    #    $self->SaveVirusTraffic($sid,\%virus_traff);

    logger()->debug("������ $file ��������. �������: $all");
    $shot->Close($minlogtime,$maxlogtime,$mins,$maxs,$all);
    $self->ArchiveLog($dir,$file);
  }
  return $all;
}

sub MarkRemovedLogs {
  my ($self,$router,$list) = @_;
  logger()->info("������� ���� ��� ���̣����");
  foreach (split(/\s+/,$list)) {
    my ($r,$ft,$d,$iface) = $self->ParseFiletime($_);
    fatal("���̣���� ��� [rotuer_id:".$r->ID()."�� ������������ ��������������� ������� [router_id:".$router->ID()."]")
      unless $r->ID()==$router->ID();
    my $shot = logshot()->Load({collector_id=>$self->ID(),
                                iface=>$iface,
                                filetime=>$ft,
                                router_id=>$r->ID()});
    if ($shot) {
      $shot->MarkAsRemoved($r,$ft);
    } else {
      logger()->error("�������� ������ ��� ������� ���̣���� rid:".$r->ID()." filetime:$ft");
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
