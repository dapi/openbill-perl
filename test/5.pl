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
print "Init\n";
openbill::System::Init({
                   -config=>'/home/danil/projects/openbill/utils/system.xml',
                   -terminal=>1
                  });
print "Connect\n";
my $db = db('test');
$db->Connect();
my $dbh = $db->{dbh};

my $i=20000000;
print "Start\n";
while ($i) {
  unless ($i % 1000) {
    print "Create shot\n";
    my $sth = $dbh->prepare_cached('insert into shots values (?,?,?,?,?,?,?,?,?)');
    my $rv = $sth->execute($i/1000,1,'2003-01-01',undef,'2003-01-01',undef,undef,100,1);
  }
  my $sth = $dbh->prepare_cached('insert into ulog values (?,?,?,INET_ATON(?),INET_ATON(?),?,?,?,?)');
  my $rv = $sth->execute(1,1,2,'10.100.2.1','10.100.2.10',5,'eth0','eth1',"FORWARD");
  $i--;
  print "\r$i ";
}

print "\nDone.\n";

$db->Commit();
$db->Disconnect();
