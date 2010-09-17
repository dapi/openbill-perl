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
# ������������� �������� �� ������������� � ������������ ��������
# ������� �������� �� ��������� ���� ��� ������ � ������ � ���
#



@ISA=qw(Exporter
        openbill::Collector);


sub moduleDesc { '������� ���������� ulog-acctd' }


sub ParseFiletime {
  my ($self,$file) = @_;
  my @a = ($file=~/^(.*\/)?(\S+)-(\d{4})-(\d{2})-(\d{2})-(\d{2}):(\d{2})(-.+)?\.log$/);
  fatal("�������� ��� �����: $file")
    unless @a;
  my ($path,$hostname,$year,$month,$day,$hour,$min,$tz)=@a;
  my $router = router()->Load({hostname=>$hostname})
    || fatal("����� ������ ��������: $hostname");
  my $dstr = "$year-$month-$day $hour:$min:00";
  $tz=~s/^\-//;
  $tz='GMT' unless $tz; # TODO �������� � ������
  my $time = str2time($dstr,$tz) || fatal(-text=>"������ ��������� �����: $file");
  my $dh = openbill::DataType::Date->new({date=>$time,
                                          time_zone=>$tz
                                         }); # TODO TImez-one �  ������ ��� � ���� ��������
  my $data = table('router_collector')->Load({collector_id=>$self->ID(),
                                              router_id=>$router->ID()})
    || fatal("��� ������ ��� ����� ������� � ���������� - ".$self->ID()."  rid:".$router->ID());
  return ($router,$dh,$data);
}

sub LoadLogFile {
  my ($self,$db,$mindate,$maxdate,$dir,$file,$force_load) = @_;
  open(FILE,"$dir/$file") ||  fatal("������ ������� ���� $file");
  # TODO ������ ����� ������� ���� ��� ����������� ������� � �� ��������� ���������� ���� ���� ����
  # TODO ������������ ��� �������� ������������ ����� ��� ������ - �� ����� ������ ��� ��������� � ��������� �����

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
  #      logger()->warn("Ulog-���� $file ������� ���� ��� �������� (������ ������ �������� ������).");
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
        logger()->error("������ $line � ulog-����� $file �������� �������� ����� �������� (".scalar @a."<>12)");
        # TODO
        # throw , ���� �� force
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
        #  $time+=300*60; # TODO ������� �������������� ��������� �� ����/����
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
        $sth->execute($sid,$logtime,$time,$sip,$dip,$bytes,$in_iface,$out_iface,$prefix);
        unless ($line && 1000) {
          print '.';
          $db->{dbh}->commit();
        }
      }
    }
    close(FILE);
    logger()->warn("������� ��������� �� �������� ������� $mindate-$maxdate - ($mins:$maxs) ") if $maxs || $mins;
    if ($check) {
      my $b = $shot->Data('bytes');
      if ($all == $b) {
        logger()->warn("���� $file ��� ��� ��������");
        $self->ArchiveLog($dir,$file);
        return 0;
      } else {
        logger()->error("������ ulog-����� $file ����� ������ �������: record:$b <> file:$all");
        return 0;
      }
    } else {
      $self->{lines}+=$line;
      logger()->debug("������ $file ��������. �������: $all");
      $shot->Close($minlogtime,$maxlogtime,$mins,$maxs,$all);
      $self->ArchiveLog($dir,$file);
    }
    return $all;
  } catch dpl::Error::Interrupt with {
    my $e = shift;
    $e->throw();
  } otherwise {
    my $e = shift;
    print STDERR "������ ($e) ��� �������� ����� $file (������: $line)\n";
    $e->throw(@_);
  } finally {
    my $shottime = $shot->Data('shottime');
    #    throw dpl::Error("������ ����� �� ������ ������! ($s)");
    unless ($shottime) {
      #      die '�� ������ �������' unless $delete;
      logger()->warn("������ ������������ ������ � ��� ����������, sid=",$shot->ID());
      my $save = $SIG{INT};
      $SIG{INT}='IGNORE';
      $shot->Delete();
      $SIG{INT}=$save;
    }
  };

}

1;
