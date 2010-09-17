#!/usr/bin/perl
use lib qw(/home/danil/projects/openbill/
           /home/danil/projects/dpl/);
use dpl::XML;
use dpl::Error;
use dpl::Db::Database;
use dpl::Db::Table;
use dpl::Db::Filter;
use Date::Language;
use Date::Parse;
use strict;
use openbill::System;
use openbill::AccessMode;
openbill::System::Init({
                        -config=>'/home/danil/projects/openbill/etc/system.xml',
                        -terminal=>1
                       });
my $db = db();
$db->Connect();

my $a = table('tariff_naked')->List();

foreach my $h (@$a) {
  $h->{serialized}=~s/(\d),/$1./g;
  print "$h->{name}\t$h->{mb_price}\t$h->{serialized}\n";
  table('tariff_naked')->Modify($h,$h->{id});
}

$db->Commit();
