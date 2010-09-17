#!/usr/bin/perl
use strict;

my @clients;
my @classes;

sub help {
  my $str = shift;
  print STDERR "ERROR: $str\n"
    if $str;
  print "Usage: aggregate.pl client=10.100.0.0/16 client=192.168.1.0/24 class1=217.107.177.196 class1=10.100.0.0/16 class2=192.168.0.0/24\n";
  exit 100;
}
sub inet_aton {  my $ip = shift;  return unpack("N", pack("C4", split(/\./, $ip))); }
sub inet_ntoa {  my $value = shift;  return join('.',$value >> 24,($value >> 16) & 255, ($value >> 8) & 255, $value & 255); }
sub inet_atobm {  my ($quad,$b, $bits) = $_[0]=~m!^(\d+\.\d+\.\d+\.\d+)([:/](\d+))?!g;  $bits=32-($bits || 32);  my $int = unpack("N", pack("C4", split(/\./, $quad))); return { mask => $int >> $bits, bits => $bits }; }

foreach (@ARGV) {
  if (/^client=(.+)/) {
    my $a = inet_atobm($1);
    push @clients,$a;
    print STDERR "client=$1\n";
  } elsif (/^class(\d)=(.+)/) {
    help("No class defined '$1'") unless $1;
    my $n = $1-1;
    my $c = $classes[$n] || [];
    print STDERR "class$1=$2\n";
    my $a = inet_atobm($2);
    push @$c,$a;
    $classes[$n]=$c;
  } else {
    help("Unknown options: $_");
  }
}

help("No clients defined") unless @clients;
help("No classes defined") unless @classes;

my %traff;

while (<STDIN>) {
  next unless $_;
  s/^\s+//;
  my ($src,$dst,$packets,$bytes)=split(/\s+/,$_);
  next if $src eq 'Source' || !$src;
  my ($client,$class);
  if (isClient($src)) {
    $client=$src;
    $class=whichClass($dst);
  } elsif (isClient($dst)) {
    $client=$dst;
    $class=whichClass($src);
  } else {
    $client="UNKNOWN-$src-$dst";
    $class=0;
  }
  my $c = $traff{$client};
  if ($c) {
    $c->[$class]+=$bytes
  } else {
    $c=[0,0,0]; $c->[$class]+=$bytes;
    $traff{$client}=$c;
  }
}

foreach (keys %traff) {
  my $t = $traff{$_};
  print "$_\t$t->[0]\t$t->[1]\t$t->[2]\n";
}


sub isClient {
  my $ip = inet_aton(shift);
  foreach (@clients) {
    my $i = $_->{bits} ? $ip >> $_->{bits} : $ip;
    return 1 if $i==$_->{mask};
  }
  return undef;
}


sub whichClass {
  my $ip = inet_aton(shift);
  foreach my $n (0..1) {
    my $c = $classes[$n];
    foreach (@$c) {
      my $i = $_->{bits} ? $ip >> $_->{bits} : $ip;
      return $n+1 if $i==$_->{mask};
    }
  }
  return 0;
}
