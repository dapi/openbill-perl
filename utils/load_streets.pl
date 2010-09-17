#!/usr/bin/perl
use XBase;
use locale;
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

my $table = table('street');

while (<>) {
  s/\n//;

  if ($table->Load({name=>$_})) {
    print "åóôø: $_";
    $table->Modify({comment=>''},{name=>$_});
  } else {
    $table->Create({name=>$_,city_id=>1});
    print "$_";
  }
  print "\n";
}


$db->Commit();
$db->Disconnect();
