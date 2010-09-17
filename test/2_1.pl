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
use Date::Parse;
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval);
openbill::System::Init('/home/danil/projects/obs/utils/system.xml');

my $local_ifaces = [qw(eth0)];
my $local_ips = ConvertToNumeric(qw(10.100.0.0/16
                                    192.168.0.0/16
                                    217.107.177.196
                                    217.107.177.162
                                    217.107.177.187
                                    217.107.177.180
                                    217.107.177.3
                                    217.107.177.6
                                    217.107.177.185)); # берутся из таблицы роутеров

my $report_date=GetLastDate('2003-05-01');

my $ALL;
my $INET;
my %TEST;

$|=1;
my $db = db('test');
$db->Connect();
my $dbh = $db->{dbh};
my @files;
if (-f $ARGV[0]) {
  @files=@ARGV;
} else {
  @files = GetFiles($ARGV[0]);
}

ParseFiles();
$dbh->do("delete from ulog_error");
CheckErrors();
$dbh->do("delete from minut_traffic");
UpdateMinuts();
$dbh->do("delete from day_traffic");
UpdateDays();

Report();

$db->Commit();
$db->Disconnect();

sub GetFiles {
  my $dir = shift;
  my @files;
  opendir(DIR,$dir) || die "error open dir $dir";
  foreach (readdir(DIR)) {
    my $file = "$dir/$_";
    if (!/\.$/ && -d $file) {
      push @files, GetFiles($file)
    } elsif (/\.log$/) {
      push @files,$file;
    }
  }
  closedir(DIR);
  return  @files;

}

sub Report {
  print "\nText:\t$ALL\n";
  my $sth=$dbh->prepare_cached("select sum(bytes) as sum from minut_traffic");
  my $rv = $sth->execute();
  my $h = $sth->fetchrow_hashref();
  $sth->finish();
  my $a = $h->{sum};
  print "Minut:\t$a,";
  $sth=$dbh->prepare_cached("select sum(bytes) as sum from minut_traffic where class=0");
  $rv = $sth->execute();
  $h = $sth->fetchrow_hashref();
  $sth->finish();
  print " inet:\t$h->{sum}\n";
  $a-=$ALL;
  print "diff:\t$a\n";
}

sub UpdateDays {
  my $t0 = [gettimeofday];
  print "\nUpdate Days:";
  my $q = qq(
             insert into day_traffic
             select ip, date, class, sum(bytes)
             from minut_traffic group by ip, date, class
            );
  #  print "\n$q\n";
  my $sth = $dbh->prepare_cached($q);
  my $rv  = $sth->execute();
  my $elapsed = tv_interval ( $t0 );
  $elapsed=~s/\.(.{2}).+$/.$1/g;
  print "\nDay update time is $elapsed seconds\n";
  # ;
}

sub CheckErrors {
  my $t0 = [gettimeofday];
  my $elapsed = tv_interval ( $t0 );

  $elapsed=~s/\.(.{2}).+$/.$1/g;
  print "\nCheck errors time is $elapsed seconds\n";
}

sub UpdateMinuts {
  my $t0 = [gettimeofday];
  print "\nUpdate Minuts:";
  # а)
  my $src_ip_local = GetLocalIpQuery('src_ip');
  my $dst_ip_local = GetLocalIpQuery('dst_ip');
  my $q = qq(insert into minut_traffic
             select from_unixtime(logtime-mod(logtime,300)), from_unixtime(logtime-mod(logtime,300)),
             dst_ip, src_ip, ($src_ip_local) , ?, sum(bytes) from ulog u, shots_log s
             where u.shot_id=s.shot_id and closetime is null and ($dst_ip_local)
             group by from_unixtime(logtime-mod(logtime,300)), dst_ip, src_ip);
  my $sth = $dbh->prepare_cached($q);
  my $rv  = $sth->execute('in');
  print '.';
  my $q = qq(insert into minut_traffic
             select from_unixtime(logtime-mod(logtime,300)), from_unixtime(logtime-mod(logtime,300)),
             src_ip, dst_ip, ? , ?, sum(bytes) from ulog u, shots_log s
             where u.shot_id=s.shot_id and closetime is null and ($src_ip_local) and not ($dst_ip_local)
             group by from_unixtime(logtime-mod(logtime,300)), src_ip, dst_ip);
  $sth = $dbh->prepare_cached($q);
  $rv=$sth->execute(0,'out');
  print '.';
  # надо ещё сделать проверку всех пакетов прошедших-вышедших через внешний интерфейс
  my $elapsed = tv_interval ( $t0 );
  $elapsed=~s/\.(.{2}).+$/.$1/g;
  print "\nMinuts update time is $elapsed seconds\n";
}

sub UpdateMinuts_faqe {
  my $t0 = [gettimeofday];
  print "\nUpdate Minuts:";
  # а)
  my $in_ifaces_local = GetLocalIfacesQuery('in_iface');
  my $out_ifaces_local = GetLocalIfacesQuery('out_iface');
  my $src_ip_local = GetLocalIpQuery('src_ip');
  my $dst_ip_local = GetLocalIpQuery('dst_ip');
  my $q = qq(insert into minut_traffic
             select from_unixtime(logtime-mod(logtime,300)), from_unixtime(logtime-mod(logtime,300)),
             dst_ip, src_ip, ($src_ip_local) , ?, sum(bytes) from ulog u, shots_log s
             where u.shot_id=s.shot_id and closetime is null and (prefix=? or prefix=?) and not ($in_ifaces_local)
             group by from_unixtime(logtime-mod(logtime,300)), dst_ip, src_ip);
  #  print "\n$q\n";
  my $sth = $dbh->prepare_cached($q);
  my $rv  = $sth->execute('in','forward','input');
  print '.';
  # в)
  $q = qq(insert into minut_traffic
          select from_unixtime(logtime-mod(logtime,300)), from_unixtime(logtime-mod(logtime,300)),
          src_ip, dst_ip, ($dst_ip_local), ?, sum(bytes) from ulog u, shots_log s
          where u.shot_id=s.shot_id and closetime is null and (prefix=? or prefix=?) and not ($out_ifaces_local)
          group by from_unixtime(logtime-mod(logtime,300)), src_ip, dst_ip);
  #  print "\n$q\n";
  $sth = $dbh->prepare_cached($q);
  $rv=$sth->execute('out','forward','output');
  print '.';

  # д)
  $q = qq(insert into minut_traffic
          select from_unixtime(logtime-mod(logtime,300)), from_unixtime(logtime-mod(logtime,300)),
          dst_ip, src_ip, ?, ?, sum(bytes) from ulog u, shots_log s
          where u.shot_id=s.shot_id and closetime is null and prefix=? and ($out_ifaces_local)
          group by from_unixtime(logtime-mod(logtime,300)), dst_ip, src_ip);
  #  print "\n$q\n";
  $sth = $dbh->prepare_cached($q);
  $rv=$sth->execute(1, 'in','output');
  print '.';

  # ф)
  $q = qq(insert into minut_traffic
          select from_unixtime(logtime-mod(logtime,300)), from_unixtime(logtime-mod(logtime,300)),
          src_ip, dst_ip, ?, ?, sum(bytes) from ulog u, shots_log s
          where u.shot_id=s.shot_id and closetime is null and ($in_ifaces_local) and (prefix=? or (($out_ifaces_local) and prefix=?))
          group by from_unixtime(logtime-mod(logtime,300)), src_ip, dst_ip);
  # print "\n$q\n";
  $sth = $dbh->prepare_cached($q);
  $rv=$sth->execute(1, 'in', 'input','forward');
  print '.';

  # надо ещё сделать проверку всех пакетов прошедших-вышедших через внешний интерфейс
  my $elapsed = tv_interval ( $t0 );
  $elapsed=~s/\.(.{2}).+$/.$1/g;
  print "\nMinuts update time is $elapsed seconds\n";
}

sub GetLocalIpQuery {
  my $ip = shift;
  return join(' or ',map {$_->{bits} ? "$_->{mask} = $ip >> $_->{bits}" : "$_->{mask}=$ip"} @$local_ips);
}

sub GetLocalIfacesQuery {
  my ($iface) = @_;
  return join(' or ',map {"$iface='$_'"} @$local_ifaces);
}

sub ParseFiles {
  $dbh->do("delete from ulog");
  $dbh->do("delete from shots_log");
  my $max = scalar @files;
  my $i=0;
  my $lines=0;
  foreach my $file (@files) {
    $i++;
    print "\r$max/$i";
    open(FILE,$file) ||  die "error open file $file";
    my ($path,$hostname,$year,$month,$day,$hour,$min)=
      ($file=~/^(.*\/)?(\S+)-(\d{4})-(\d{2})-(\d{2})-(\d{2}):(\d{2})\.log$/);
    my $sid = CreateShotLog($hostname,"$year-$month-$day $hour:$min:00");
    while (<FILE>) {
      $lines++;
      s/\n$//;
      my @a = split("\t");
      splice(@a,1,1) if $a[2]=~/^\d{9,10}$/;
      my ($hostname,$time,$prot,
          $sip,$sp,$dip,$dp,
          $packets,$bytes,
          $in_iface,$out_iface,
          $prefix)=@a;
      next if $prefix eq 'F_DENY';
      my $logtime = $report_date > $time ? $report_date : $time;
      my $sth = $dbh->prepare_cached('insert into ulog values (?,?,?,INET_ATON(?),INET_ATON(?),?,?,?,?)');
      $ALL+=$bytes;
      $sth->execute($sid,$time,$logtime,$sip,$dip,$bytes,$in_iface,$out_iface,$prefix);
    }
    $db->Commit();
    close(FILE);
  }
}

sub GetLastDate {
  my $date = shift;
  my $rd = str2time($date,'-0000');
  $rd+=24*60*60+1;
  #die new Date::Handler({date=>$rd,
#                         time_zone=>'Russia/Moscow',
#                         locale=>'ru_RU.koi8-r'
#                        });
  return $rd;
}

sub CreateShotLog {
  my ($hostname,$filetime) = @_;
  my $sth = $dbh->prepare_cached('insert into shots_log (hostname, filetime, shottime) values (?,?,now())');
  $sth->execute($hostname,$filetime);
  $sth=$dbh->prepare_cached("select last_insert_id() as id");
  my $rv = $sth->execute();
  my $h = $sth->fetchrow_hashref();
  $sth->finish();
  return $h->{id};
}


sub IsIfaceLocal {
  my $iface = shift;
  foreach (@$local_ifaces) {
    return 1 if $iface eq $_;
  }
  return 0;
}

sub IsIpLocal {
  my $i = shift;
  my $ip =$i;                   #unpack("N", pack("C4", split(/\./, $i)));
  foreach (@$local_ips) {
    return 1 if $_->{mask} == $ip || ($_->{bits} && ($_->{mask} == $ip >> $_->{bits}));
  }
  return 0;
}

sub ConvertToNumeric {
  my @t;
  for (@_) {
    my ($quad, $bits) = m!^(\d+\.\d+\.\d+\.\d+)(?:/(\d+))?!g;
    my $matchbits = 32 - ($bits || 32);
    my $int = unpack("N", pack("C4", split(/\./, $quad)));
    my $mask = $int >> $matchbits;
    push @t => { mask => $mask, bits => $matchbits };
  }
  return \@t;
}



=pod

1. таблица без индексов
  200981 запись за 40 сек


select count(bytes), src_ip from ulog group by src_ip
  26017 rows in set (0.90 sec)

  select sum(bytes), dst_ip from ulog where prefix='forward' and in_iface='eth1' group by dst_ip;
11 rows in set (0.45 sec)

  select from_unixtime(unixtime-mod(unixtime,300)) as t,
  sum(bytes) from ulog group by from_unixtime(unixtime-mod(unixtime,300));
2252 rows 1.65 sec

  select sum(bytes), src_ip from ulog where prefix='input' and in_iface='eth1' group by src_ip;



2. таблица с индексами (hostname, in_iface), (hostname, out_iface)
  200981 записей 1m3s

  select hostname, in_iface from ulog group by hostname, in_iface;
3 rows, 0.43 сек

  select date from ulog group by date;
10 rows in set (2.66) сек

  - external upload

  select from_unixtime(unixtime-mod(unixtime,300)) as t, sum(bytes),
  src_ip from ulog where prefix='forward' and in_iface='eth0' group by
  from_unixtime(unixtime-mod(unixtime,300)), src_ip;

3134 rows in set (0.97 sec)


  - external download

  select from_unixtime(unixtime-mod(unixtime,300)) as t, sum(bytes),
  dst_ip from ulog where prefix='forward' and in_iface='eth1' group by
  from_unixtime(unixtime-mod(unixtime,300)), dst_ip;

3248 rows in set (0.97 sec)


  - check ifaces

  select distinct dst_ip from ulog where prefix='input' and in_iface='eth1';
2 rows in set (0.39 sec)


  - check prefixes
  select prefix from ulog group by prefix;
4 rows in set (0.67 sec)


  - download to router (external)

  select from_unixtime(unixtime-mod(unixtime,300)) as t, sum(bytes),
  dst_ip from ulog where prefix='input' and in_iface='eth1' group by
  from_unixtime(unixtime-mod(unixtime,300)), dst_ip;

2152 rows in set (0.51 sec)

  - upload from router (local download for users)

  select from_unixtime(unixtime-mod(unixtime,300)) as t, sum(bytes),
  dst_ip from ulog where prefix='OUTPUT' and in_iface='eth0' group by
  from_unixtime(unixtime-mod(unixtime,300)), dst_ip;


- insert download

  insert into minut_traffic
  select from_unixtime(unixtime), from_unixtime(unixtime-mod(unixtime,300)), 0, 'in', sum(bytes), dst_ip
  from ulog where prefix='forward' and in_iface='eth1'
  group by from_unixtime(unixtime-mod(unixtime,300)), dst_ip;

3284 rows 1.29 sec


  - insert upload
  insert into minut_traffic
  select from_unixtime(unixtime), from_unixtime(unixtime-mod(unixtime,300)), 0, 'out', sum(bytes), src_ip
  from ulog where prefix='forward' and in_iface='eth0'
  group by from_unixtime(unixtime-mod(unixtime,300)), src_ip;

3134 rows 1.53 sec

  3. таблица c датой и unixtime и тремя индексами (hostname, in_iface),  (hostname,  out_iface), date_inf
  200981 запись за 2m6 сек


  4. таблица без индексов с цифровыми адресами
  200981 запись за 41 сек

  5. таже с занесением в shots_log (2256 записей)
  43 секунды


 6.

~/projects/openbill$ time ./test/2_1.pl /arc/pub/new/stats/archive/
4810/4810
Update time is 14.76 seconds

Text:   3326159957, inet:       1716948733
Minut:  3326159957, inet:       1716948733
diff:   0

real    2m34.251s
user    1m3.080s
sys     0m5.170s


7.
~/projects/openbill$ time ./test/2_1.pl /arc/pub/new/stats/
7047/7047 = 6198Mb. ulog - 769596 records, minut_traffic - 16659
Update time is 12.58 seconds

Text:   6198953207, inet:       3254213937
Minut:  6198953207, inet:       3254213937
diff:   0

real    4m18.932s
user    1m52.250s
sys     0m8.960s
~/projects/openbill$


8. учитывая shots
~/projects/openbill$ time ./test/2_1.pl /arc/pub/new/stats/
7047/7047 = 6198Mb. ulog - 769596 records, minut_traffic - 16659 records
Update time is 15 seconds

Text:   6198953207, inet:       3254213937
Minut:  6198953207, inet:       3254213937
diff:   0

real    4m33.955s
user    1m52.900s
sys     0m8.400s



insert into day_traffic select ip, date, class, direction,
sum(bytes)/1024 from minut_traffic group by ip, date, class,
direction;

Query OK, 1018 rows affected (0.56 sec)
Records: 1018  Duplicates: 0  Warnings: 0


Update Minuts:
Minuts update time is 347.54 seconds

Update Days:
Day update time is 3.20 seconds

Text:   62097111126, inet:      62097111126
Minut:  43883210783, inet:      15804560912
diff:   -18213900343

real    33m34.012s
user    10m48.660s
sys     0m56.420s


5305320 записей в ulog, 545915 в minut_traffic, 4763 в day_traffic
Update Minuts:..
Minuts update time is 306.85 seconds

Update Days:
Day update time is 2.56 seconds

Text:   62097162468
Minut:  62097162468, inet:      14479576741
diff:   0

real    29m43.611s
user    8m9.930s
sys     0m58.600s



=cut
