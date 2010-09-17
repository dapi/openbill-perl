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

my $list = table('collector')->List();

foreach (@$list) {
  table('collector')->
    Modify({command_line=>"/usr/local/bin/$_->{command_line}"},
           $_->{collector_id});
}

$db->Commit();
$db->Disconnect();
