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
my $sth = $dbh->prepare_cached("delete from day_traffic");
$sth->execute();
foreach my $m (1..12) {
  $m="0$m" if $m<10;
  print "$m: ";
  foreach my $d (1..30) {
    $d="0$d" if $d<10;
    print ".";
    foreach my $i (0..1000) {
      my $value = 1678376960+$i;
      my $ip = join('.',$value >> 24,($value >> 16) & 255, ($value >> 8) & 255, $value & 255);
      my $date="00-$m-$d";
      my $sth = $dbh->prepare_cached("insert into day_traffic values (?,?,?,?)");
      $sth->execute($ip,$date,6000,600);
    }
  }
  print "\n";
}

$db->Commit();
$db->Disconnect();
