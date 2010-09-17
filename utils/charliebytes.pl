#!/usr/bin/perl
use strict;
use Text::FormatTable;
use Number::Format qw(:subs);
my @local=('10.100',
           '217.107.177',
           '213.59.74',
           '81.4.242',
           '192.168',
           '10.20.30',
           '10.20.40',
          );
my %ports=(zall=>{});
my %TRAF;

my $ip = $ARGV[0];
my $ALL;
print "Локальные адреса: ".join(', ',@local).", IP хоста $ip\n";
die 'Не указан IP' unless $ip;
while (<STDIN>) {
  next unless my ($from,$fp,$to,$tp,$type,$bytes)=/^\s*(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/;
  next if $from eq 'FROM';
  if ($from eq $ip) {
    my $is_local = isLocal($to);
    $TRAF{$is_local}={} unless exists $TRAF{$is_local};
    $TRAF{$is_local}->{$fp}+=$bytes;
    $TRAF{$is_local}->{zall}+=$bytes;
    $TRAF{zall}->{$fp}+=$bytes;
    $TRAF{zall}->{zall}+=$bytes;
    $ports{$fp}=1;
  } elsif ($to eq $ip) {
    my $is_local = isLocal($from);
    $TRAF{$is_local}={} unless exists $TRAF{$is_local};
    $TRAF{$is_local}->{$tp}+=$bytes;
    $TRAF{$is_local}->{zall}+=$bytes;
    $TRAF{zall}->{$tp}+=$bytes;
    $TRAF{zall}->{zall}+=$bytes;
    $ports{$tp}=1;
  } else {
    $TRAF{unknown}->{unknown}=$bytes;
  }
  $ALL+=$bytes;
}

my $table = Text::FormatTable->new(' r | '.join(' | ',map {"r"} keys %TRAF));
$table->head('Порт',sort keys %TRAF);
$table->rule('-');
foreach my $port (sort keys %ports) {
  $table->row($port,map {FormatBytes($TRAF{$_}->{$port})} sort keys %TRAF)
    if $TRAF{zall}->{$port}>10000000;
}
#$table->row('ALL',$ALL);
$table->rule('=');
print $table->render(70);


#print "\nЛокаль\t\tИнетернет\tИтого\n$local\t$inet\t".($local+$inet)."\n";


sub isLocal {
  my $ip = shift;
  foreach (@local) {
    return $_ if $ip=~/^$_/x;
  }
  return 'inet';
}


sub FormatBytes {
  my ($bytes) = @_;
  my $m = round($bytes/1000000,0);
  return '' unless $m;

}
