#!/usr/bin/perl
use DBD::Pg;

my $dbh = DBI->connect("dbi:Pg:dbname=test", "postgres", "");
$dbh->{AutoCommit}=0;

foreach (0..70) {
  merge($_);
}

sub merge {
  my $n = shift;
  my $id = getmax();
  print "$n: ";
  my $sth = $dbh->prepare("select sum(bytes) as bytes, date, time, router_id, ip, dip, class, is_in from minut_traffic where date=(date '2004-01-01' + integer ?) group by date, time, router_id, ip, dip, class, is_in order by time, router_id, ip, dip, class") || die 1;
  $sth->execute($n) || die 2;
  my ($date,$rid,$time,$ip,$dip,$class,$bytes_in,$bytes_out);
  while (my $h = $sth->fetchrow_hashref()) {
#    print '.';
    #    print STDERR  join(',',map {"$_=$h->{$_}"} keys %$h)."\n";
    if ($h->{router_id}==$rid && $h->{ip} eq $ip  && $h->{time} eq $time && $h->{dip} eq $dip && $h->{class}==$class) {
      if ($is_in) {
        $bytes_in=$bytes+0;
      } else {
        $bytes_out=$bytes+0;
      }
    } else {
      my $q = "insert into minut_traffic_new values (0,$rid,'$date','$time','$ip','$dip',$class,$bytes_in,$bytes_out)";
      if (defined $rid) {
        my $rv = $dbh->do($q) || die;
      }
      ($date,$rid,$ip,$time,$dip,$class) = ($h->{date},$h->{router_id},$h->{ip},$h->{time},$h->{dip},$h->{class});
      $bytes_out=0;
      $bytes_in=0;
    }
  }
  exit unless $date;
  my $q = "insert into minut_traffic_new values (0,$rid,'$date','$time','$ip','$dip',$class,$bytes_in,$bytes_out)";
  my $rv = $dbh->do($q) || die;
  $dbh->commit();
  print "ok\n";
}


sub getmax {
  my $sth = $dbh->prepare("select sum(shot_id) as shot_id from minut_traffic") || die 1;
  $sth->execute() || die 2;
  my $h = $sth->fetchrow_hashref();
  $sth->finish();
  return $h->{shot_id};
}


=cut

  real    9m59.737s
  user    2m56.090s
  sys     0m11.550s

  create table test (key int, value int);

CREATE RULE test_insert AS ON INSERT TO test
    WHERE NEW.key in (select key from test)
    DO INSTEAD
    UPDATE test set value=value+NEW.value;


  =pod
