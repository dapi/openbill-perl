#!/usr/bin/perl
use lib qw(/home/danil/projects/openbill/
           /home/danil/projects/dpl/);
use dpl::Error;
use dpl::Db::Database;
use dpl::Db::Table;
use dpl::Db::Filter;
use dpl::System;
use strict;

dpl::System::Define('openbill','/usr/local/openbill/etc/system.xml');

#my $db = db();
my $db = db('pg');
#my $db2 = db('pg');

$db->Connect();

#$db2->Connect();

$|=1;

my $interval = 300;



#my $sth = db()->Select("select log_shot.shot_id,router_id,FROM_UNIXTIME(logtime) as logtime,src_ip,dst_ip,traflog.bytes,in_iface,out_iface,prefix from traflog, log_shot where log_shot.shot_id>=63000 and traflog.shot_id=log_shot.shot_id");
#while (my $r=$sth->fetchrow_hashref()) {
#  $r->{prefix}=0; $r->{src_ip}=inet_ntoa($r->{src_ip}); $r->{dst_ip}=inet_ntoa($r->{dst_ip});
#  $r->{in_iface}=0;$r->{out_iface}=1;
#  my $s = $db2->{dbh}->prepare_cached('insert into traflog values (?,?,?,?,?,?,?,?,?)');
#  my $rv = $s->execute($r->{shot_id},$r->{router_id},$r->{logtime},$r->{src_ip},$r->{dst_ip},$r->{bytes},$r->{in_iface},$r->{out_iface},$r->{prefix});
#}
#$db2->Commit();
#$db2->Disconnect();

# по ip за день
my %ip_day;
# по ip за минуты
my %ip_minut;
# по ip по серверам за день
my %ip_day_dst;
# по ip по серверам за минуты
my %ip_minut_dst;
# по клиентам за день
my %client_day;
# неизвестные записи (адреса ни источника ни получателя не принадлежат клиентам)
my @unknown_recs;

my %clients_hash;

print "query: ";
my $sth = $db->Select("select date_trunc('hour',logtime) as logtime, sum(bytes) as bytes, src_ip, dst_ip from traflog where shot_id>=64000 group by router_id, dst_ip, src_ip, date_trunc('hour',logtime)");
print "fetch\n";

my $i;
while (my $r=$sth->fetchrow_hashref()) {
  my ($ip,$dst);
  $i++;
  print "\r$i";
  my %b;

  if (IsIPClient($r->{src_ip})) {
    $ip = $r->{src_ip}; $dst = $r->{dst_ip};
    $b{out} = $r->{bytes};
  } elsif (IsIPClient($r->{dst_ip})) {
    $ip = $r->{dst_ip}; $dst = $r->{src_ip};
    $b{in} = $r->{bytes};
  } else {
    push @unknown_recs,$r;
    next;
  }

  my $class = WhichClass($dst);
  my $date = $r->{logtime} - 3*60*60;

  IncBytes(\%ip_day,$date,$r->{router_id},$ip,$class,\%b);
  IncBytes(\%ip_minut,$r->{logtime},$r->{router_id},$ip,$class,\%b);

  IncBytes(\%ip_day_dst,$date,$r->{router_id},$ip,$dst,$class,\%b);
  IncBytes(\%ip_minut_dst,$r->{logtime},$r->{router_id},$ip,$dst,$class,\%b);

  IncBytes(\%client_day,$date,GetClient($r->{router_id},$ip),$class,\%b);
}
print " Done\n";
print "Unknown: "; print scalar @unknown_recs; print "\n";
print "Finish: "; $sth->finish(); print "Ok\n";
print "Disconnect: "; $db->Disconnect(); print "Ok\n";

sub IncBytes {
  my ($hr,$b) = (shift,pop);
  $hr = recurs($hr,@_);
  $hr->{in}+=$b->{in}+0;
  $hr->{out}+=$b->{out}+0;
}

sub recurs {
  my ($hr,$key) = (shift,shift);
  $hr->{$key}={} unless exists $hr->{$key};
  return $hr->{$key};
}

sub LoadClientID {
  my ($rid,$ip) =  @_;
  my $a = $db->SelectAndFetchOne("select client_id from host where ip >> $ip and router_id=$rid");
  return $a && %$a ? $a->{client_id} : undef;
}

sub GetClient {
  my ($rid,$ip) = @_;
  if (exists $clients_hash{$rid}) {
    return $clients_hash{$rid}->{$ip} if exists $clients_hash{$rid}->{$ip};
    return $clients_hash{$rid}->{$ip}=LoadClientID($rid,$ip);
  } else {
    my $id = LoadClientID($rid,$ip);
    $clients_hash{$rid}={$ip=>$id};
    return $id;
  }
}

sub IsIPClient {
  my $ip = shift;
  return 10*265+100 == $ip >> 8;
}

sub WhichClass {
  my $ip = shift;
  return 10*265+100 == $ip >> 8;
}

sub inet_ntoa {
  my $value = shift;
  return join('.',$value >> 24,($value >> 16) & 255, ($value >> 8) & 255, $value & 255)
}
