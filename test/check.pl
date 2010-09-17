#!/usr/bin/perl
use lib qw(/home/danil/projects/openbill/
           /home/danil/projects/dpl/);
use dpl::XML;
use NetAddr::IP;
use dpl::Error;
use dpl::Db::Database;
use dpl::Db::Table;
use Date::Language;
use Date::Parse;
use strict;
use openbill::System;

openbill::System::Init({
                   -config=>'/home/danil/projects/openbill/utils/system.xml',
                   -terminal=>1
                  });

my $db = db();
$db->Connect();
my $a = $db->SelectAndFetchAll('select * from minut_shot');
my $last_id=0;
foreach my $c (@$a) {
my $b = GetBytes($c->{last_ushot_id});
print "$c->{id} $c->{dfrom} $c->{dto} $c->{bytes} = $b\n";
}

$db->Disconnect();

sub GetBytes {
	my $id = shift;
	my $b = $db->SelectAndFetchOne("select sum(bytes) as bytes from ulog_shot where shot_id>$last_id and shot_id<$id");
	$last_id=$id;
	return $b->{bytes};
}
