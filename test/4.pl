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

$|=1;
openbill::System::Init('/home/danil/projects/obs/utils/system.xml');

my $db = db('test');
$db->Connect();
my $dbh = $db->{dbh};
my $sth = $dbh->prepare_cached("delete from ip_stats;");
$sth->execute();
foreach my $d (1..1) {
  $d="0$d" if $d<10;
  print "$d: ";
  foreach my $r (0..2) {
    foreach my $s (0..50) {
      print ".";
      my $sid = $s+($r+$d*20)*50;
      foreach my $i (0..50) {
        my $value = 174325760+$i+$s*500;
        my $ip = join('.',$value >> 24,($value >> 16) & 255, ($value >> 8) & 255, $value & 255);
        $value = 1174325760+$i;
        my $ip2 = join('.',$value >> 24,($value >> 16) & 255, ($value >> 8) & 255, $value & 255);
        foreach my $p (1..33) {
          my $time = 100000000+((($d*24+$s)*30)+$p)*60;
          my $sth = $dbh->prepare_cached("insert into ip_stats values (?,FROM_UNIXTIME(?),FROM_UNIXTIME(?),?,?,?,?,?,?)");
          $sth->execute($sid,$time,$time,$ip,$ip2,4000,'eth1','eth0','forward');
        }
      }
    }
  }
}

$db->Commit();
$db->Disconnect();
