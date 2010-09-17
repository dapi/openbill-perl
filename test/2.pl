#!/usr/bin/perl
use lib qw(/home/danil/projects/openbill/
           /home/danil/projects/dpl/);
use dpl::XML;
use NetAddr::IP;
use dpl::Error;
use dpl::Db::Database;
use dpl::Db::Table;
use strict;
use openbill::System;
use Benchmark;

openbill::System::Init('/home/danil/projects/obs/utils/system.xml');

my $db = db('test');
$db->Connect();
my $dbh = $db->{dbh};
#my $sth = $dbh->prepare_cached("delete from ip_stats;");
#$sth->execute();
while (<>) {
  my ($hostname,$packet_time,$prot,
      $sip,$sp,$dip,$dp,
      $packets,$bytes,
      $in_iface,$out_iface,
      $prefix)=split("\t");
  my $dipi=unpack("N", pack("C4", split(/\./, $dip)));
  my $sipi=unpack("N", pack("C4", split(/\./, $sip)));
#  my $dipi=0;
#  my $sipi=0;
  my $sth = $dbh->prepare_cached("insert into ip_stats values (?,FROM_UNIXTIME(?),FROM_UNIXTIME(?),?,?,?,?,?,?,?,?)");
  $sth->execute($hostname,$packet_time,$packet_time,$sip,$sipi,$dip,$dipi,$bytes,$in_iface,$out_iface,$prefix);
}

$db->Commit();
$db->Disconnect();
