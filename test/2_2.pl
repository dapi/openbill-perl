#!/usr/bin/perl
use lib qw(/home/danil/projects/openbill/
           /home/danil/projects/dpl/);
use Date::Handler;
use dpl::XML;
use NetAddr::IP;
use dpl::Error;
use dpl::Db::Database;
use dpl::Db::Table;
use strict;
use openbill::System;
use Benchmark;

openbill::System::Init('/home/danil/projects/obs/utils/system.xml');

my $local_ifaces = [qw(eth0)];
my $local_ips = ConvertToNumeric('10.100.0.0/16','192.168.0.0/16','217.107.177.196');

my $report_date=0;

$|=1;
my $db = db('test');
$db->Connect();
my $dbh = $db->{dbh};
my $sth = $dbh->prepare_cached("delete from ulog");
$sth->execute();
my @files;
if (-f $ARGV[0]) {
  @files=@ARGV;
} else {
  my $dir = $ARGV[0];
  opendir(DIR,$dir) || die "error open dir $ARGV[0]";
  @files = map {"$dir/$_"} grep {/\.log$/} readdir(DIR);
  closedir(DIR);
}
my $max = scalar @files;
my $i=0;
my $lasttime=0;
my $maxtime=0;
my $interval=300;
my %cache=();
foreach (@files) {
  $i++;
  print "\r$max/$i";
  open(FILE,$_) ||  die "error open file $_";
  while (<FILE>) {
    s/\n$//;
    my ($hostname,$time,$prot,
        $sip,$sp,$dip,$dp,
        $packets,$bytes,
        $in_iface,$out_iface,
        $prefix)=split("\t");
    #    my $dipi=unpack("N", pack("C4", split(/\./, $dip)));
    #    my $sipi=unpack("N", pack("C4", split(/\./, $sip)));
    my ($iloc,$oloc) = (IsIfaceLocal($in_iface),IsIfaceLocal($out_iface));
    my ($sloc,$dloc) = (IsIpLocal($sip),IsIpLocal($dip));
    my $date = new Date::Handler({date=>$time});
    $maxtime=$time if $maxtime<$time;
    $lasttime=$time unless $lasttime;
    if ($prefix eq 'FORWARD') {
      if ($iloc) {
        SaveToBuffer($sip,$bytes,'out');
      } elsif ($oloc) {
        SaveToBuffer($dip,$bytes,'in');
      }
    }
    FlushBuffer($maxtime) if $lasttime+$interval>=$maxtime;
  }
  FlushBuffer($maxtime);
  close(FILE);
}

$db->Commit();
$db->Disconnect();

sub SaveToBuffer {
  my ($ip,$bytes,$dir) = @_;
  $cache{$ip}={in=>0,out=>0} unless $ip;
  $cache{$ip}->{$dir}+=$bytes;
}

sub FlushBuffer {
  my $maxtime = shift;
  my $q = 'insert into minut_traffic values (FROM_UNIXTIME(?),FROM_UNIXTIME(?),?,?,?,?)';
  foreach (keys %cache) {
    my $d = $cache{$_};
    my $sth = $dbh->prepare_cached($q);
    $sth->execute($maxtime,$maxtime,$_,0,'in',$d->{in})
      if $d->{in};
    $sth = $dbh->prepare_cached($q);
    $sth->execute($maxtime,$maxtime,$_,0,'out',$d->{out})
      if $d->{out};
  }
  $lasttime=$maxtime;
  %cache=();
}

sub IsIfaceLocal {
  my $iface = shift;
  foreach (@$local_ifaces) {
    return 1 if $iface eq $_;
  }
  return 0;
}

sub IsIpLocal {
  my $i = shift;
  my $ip = unpack("N", pack("C4", split(/\./, $i)));
  foreach (@$local_ips) {
    return 1 if $_->{mask} == $ip || ($_->{bits} && ($_->{mask} == $ip >> $_->{bits}));
  }
  return 0;
}

sub ConvertToNumeric {
  my @t;
  for (@_) {
    my ($quad, $bits) = m!^(\d+\.\d+\.\d+\.\d+)(?:/(\d+))?!g;
    my $matchbits = 32 - ($bits || 32);
    my $int = unpack("N", pack("C4", split(/\./, $quad)));
    my $mask = $int >> $matchbits;
    push @t => { mask => $mask, bits => $matchbits };
  }
  return \@t;
}



=pod

  вставка 3m43, 4 больших индекса
  130598 записей




=cut
