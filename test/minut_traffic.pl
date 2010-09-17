#!/usr/bin/perl
use DBD::Pg;

my $dbh = DBI->connect("dbi:Pg:dbname=test", "postgres", "");
$dbh->{AutoCommit}=0;
my $i;
$|=1;
#$dbh->do('BEGIN') || die 'error';
#$dbh->do('START TRANSACTION ISOLATION LEVEL SERIALIZABLE') || die 'error';
merge($_);
#load();

sub merge {
  my $n = shift;
  print "$n: ";
  my $sth = $dbh->prepare("select sum(bytes_in) as bytes_in, sum(bytes_out) as bytes_out, date, time, router_id, ip, dip, class from minut_traffic group by date, time, router_id, ip, dip, class order by time, router_id, ip, dip, class") || die 1;
  $sth->execute() || die 2;
  my ($date,$rid,$time,$ip,$dip,$class,$bytes_in,$bytes_out);
  while (my $h = $sth->fetchrow_hashref()) {
    print '.';
    my $q = "insert into minut_traffic_new values (0,$h->{router_id},'$h->{date}','$h->{time}','$h->{ip}','$h->{dip}',$h->{class},$h->{bytes_in},$h->{bytes_out})";
    my $rv = $dbh->do($q) || die;
  }
  $dbh->commit();
  print "ok\n";
}

# sum(bytes)=73376139357

sub load {
  my $last;
  while (<>) {
#    print '.';
    #($shot_id,$router_id,$timestamp,$ip,$dip,$class,$is_in,$bytes)
    my ($sid,$rid,$date,$time,$timestamp,$ip,$dip,$class,$is_in,$bytes)=(/INSERT INTO minut_traffic VALUES \((\d+),(\d+),'([0-9\-]+)','([0-9\- :]+)','([0-9\- :]+)',(\d+),(\d+),(\d+),'(in|out)',(\d+)\)/);
    $ip=inet_ntoa($ip);
    $dip=inet_ntoa($dip);
    $dbh->do("insert into minut_traffic values (?,?,?,?,?,?,?,?)",undef ,
             $rid,$date,$time,$ip,$dip,$class,$is_in ? $bytes : 0,$is_in ? 0 : $bytes) || die "error line ($i) '$_'";
    if (++$i>$last+1000) {
      print "\r$i";
      $last=$i;
      last if $i>=100000;
    }
  }
  print "\nCommit: ";
  $dbh->commit();
  print "OK\n";
}

sub inet_aton {
  my $ip = shift;
  return unpack("N", pack("C4", split(/\./, $ip)));
}

sub inet_ntoa {
  my $value = shift;
  return join('.',$value >> 24,($value >> 16) & 255, ($value >> 8) & 255, $value & 255)
}



=pod

  10000 записей:

  autocommit=1 -   19 sec
  autocommit=0 -   4 sec

  100000 записей:
  inet  - 45/19.4, 47/19
  bigint - 39

  500000 записей:
  bigint  - 3m37/1m34
  inet    - 3m33/1m30


  100000 записей
  простое добавление 1m12, в следующий раз было 2m6
  merge потом заняло 1m25с
  добавление с обновлением 3m56 (59500 записей) (через RULE)

  =cut
