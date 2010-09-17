#!/usr/bin/perl
use DBD::Pg;

my $dbh = DBI->connect("dbi:Pg:dbname=test", "postgres", "");
$dbh->{AutoCommit}=0;
my $i;
$|=1;

my $sth = $dbh->prepare("select sum(bytes) as bytes, date, time, router_id, ip, dip, class, is_in from minut_traffic where date=(date '2004-01-01' + integer ?) group by date, time, router_id, ip, dip, class, is_in order by time, router_id, ip, dip, class") || die 1;
$sth->execute($n) || die 2;
while (my $h = $sth->fetchrow_hashref()) {
}
my $rv = $dbh->do($q) || die;
$dbh->commit();


=cut





  =pod
