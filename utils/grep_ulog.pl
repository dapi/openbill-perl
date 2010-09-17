#!/usr/bin/perl
use Date::Handler;
use Date::Parse;
use Text::FormatTable;

my $date_from=undef;#'2004-06-22 00:00:00';
my $date_to=undef;#'2004-06-24 00:00:00';
my $grep_sip=undef;
my $grep_dip=undef;
my $grep_anyip=undef;
my $grep_sport=undef;
my $grep_dport=25;

my $time_zone='Europe/Moscow';
my $locale='ru_RU.KOI8-R';

my ($line,$all);

$date_from = new Date::Handler({ date => str2time($date_from),
                                 time_zone => $time_zone,
                                 locale => $locale,
                               }) if $date_from;
$date_to = new Date::Handler({ date => str2time($date_to),
                               time_zone => $time_zone,
                               locale => $locale,
                             }) if $date_to;

#print "$ip->$ip2 ($date_from -> $date_to)\n";
my $table = Text::FormatTable->new('r | r | l | r | l | l ');
$table->head('Время', 'От кого', 'Порт', 'К кому' , 'Порт' , 'Байт');
$table->rule('=');
while (<>) {
  $line++;
  s/\n$//;
  my @a = split("\t");
  my ($hostname,$time,$prot,
      $sip,$sp,$dip,$dp,
      $packets,$bytes,
      $in_iface,$out_iface,
      $prefix)=@a;
  next if $prefix=~/DENY/ || $sip eq '127.0.0.1' || $dip eq '127.0.0.1';
  my $date = new Date::Handler({ date => $time,
                                 time_zone => $time_zone,
                                 locale => $locale,
                               });
  last if $date_to && $date_to<$date;
  if ((!$date_to || $date<=$date_to)
      && (!$date_from || $date>=$date_from)
      && (!$grep_sip || $grep_sip eq $sip || $grep_anyip eq $sip)
      && (!$grep_dip || $grep_dip eq $dip || $grep_anyip eq $dip)
      && (!$grep_dport || $grep_dport eq $dp)
      && (!$grep_sport || $grep_sport eq $sp)
     ) {
    $table->row($date->TimeFormat('%D %X'),$sip,$sp,$dip,$dp,$bytes);
    $all+=$bytes;
  }
}
$table->rule();
print $table->render();

print "ИТОГО: $all\n";

sub inet_ntoa {
  my $value = shift;
  return join('.',$value >> 24,($value >> 16) & 255, ($value >> 8) & 255, $value & 255)
}
