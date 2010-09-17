#!/usr/bin/perl
use lib qw(/home/danil/projects/openbill/
           /home/danil/projects/dpl/);
use openbill::DataType::Date;
use openbill::DataType::DateTime;
use openbill::DataType::Time;
use Number::Format qw(:subs);

use dpl::Error;
use dpl::Db::Database;
use dpl::Db::Table;
use dpl::Db::Filter;
use dpl::System;
use strict;

$ENV{OPENBILL_ROOT}||='/usr/local/openbill/';
my $config = $ENV{OPENBILL_CONFIG} || "$ENV{OPENBILL_ROOT}etc/system.xml";
dpl::System::Define('openbill',$config);

my $db = db();
$db->Connect();
$|=1;
my $list = db()->SelectAndFetchAll("select * from payment where payment_method_id=2 and type=1 and date>='$ARGV[0]'");

my $all;

my %h=(100=>0,200=>0,300=>0,500=>0,1000=>0);

foreach (@$list) {
  next unless $_->{summa}==$_->{summa_order};
  my $s = $_->{summa_order};
  $all+=$s;
  my $r=100;
  $r=200 if $s>150;
  $r=300 if $s>250;
  $r=500 if $s>400;
  $r=1000 if $s>700;
  $h{$r}++;
}

$db->Commit();
$db->Disconnect();

my $avg = $all/$#$list;
my $count = $#$list;
print "Всего $all рублей на $count платежей ($avg)\n";
foreach (sort keys %h) {
  my $p = round($h{$_}*100/$count,0);
  print "$_ rub = $h{$_} раз ($p%)\n";
}
