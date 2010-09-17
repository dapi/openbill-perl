#!/usr/bin/perl
use strict;

use Number::Format qw(:subs);
use Date::Handler;
use Date::Parse;
use Text::FormatTable;

my $KBYTES=1000;
my $MBYTES=$KBYTES*$KBYTES;
my $GBYTES=$MBYTES*$KBYTES;


my $line=0;
my $total;
my %SITE=(ztotal=>{});

my @local=('10.100',
           '217.107.177',
           '213.59.74',
           '81.4.242',
           '192.168',
           '10.20.30',
           '10.20.40',
          );


while (<>) {
  s/\n|\r//g;
  $line++;
  my $l = ParseLine($_);
  $total +=$l->{bytes};
  SaveLine($l);

}

my $table = Text::FormatTable->new(' r | r | r | r | r ');
$table->head('сайт','graph','dyn','other','TOTAL');
$table->rule('-');

foreach my $site (sort keys %SITE) {
  $table->row($site,'','','','');
  $table->head('сеть','graph','dyn','other','TOTAL');
  $table->rule('=');
  Output($table,$SITE{$site});
  $table->rule('-');
}
print $table->render(90);
print "\nTOTAL:\t".FormatBytes($total)."\n";

sub Output {
  my ($table,$s) = @_;
  foreach my $net (sort keys %$s) {
    $table->row($net,map {FormatBytes($s->{$net}->{$_})} qw(graph dyn other all));
  }

}

sub SaveLine {
  my $l = shift;
  $SITE{$l->{site}}={} unless exists $SITE{$l->{site}};
  my $s = $SITE{$l->{site}};

  my $is_local = isLocal($l->{host});
  $s->{$is_local}->{$l->{type}}+=$l->{bytes};
  $s->{$is_local}->{all}+=$l->{bytes};
  $s->{total}->{$l->{type}}+=$l->{bytes};
  $s->{total}->{all}+=$l->{bytes};

  my $st = $SITE{ztotal};
  $st->{$is_local}->{$l->{type}}+=$l->{bytes};
  $st->{$is_local}->{all}+=$l->{bytes};
  $st->{total}->{$l->{type}}+=$l->{bytes};
  $st->{total}->{all}+=$l->{bytes};
}

sub isLocal {
  my $ip = shift;
  foreach (@local) {
    return 'local' if $ip=~/^$_/x;
  }
  return 'inet';
}

sub ParseLine {
  my $s = shift;
  my %h;
  $s=~s/(\S+)\s+//;
  $h{host} = $1;
  $s=~s/(\S+)\s+//;
  $h{site} = $1;
  $h{site} =~s/^www\.//;
  $s=~s/(\S+)\s+//;
  $h{u} = $1;
  $s=~s/\[([^\[\]]+)\]\s+//;
  $h{time} = ParseTime($1);
  $s=~s/\"([^\"]+)\"\s+//;
  $h{req} = $1;
  $s=~s/(\d+)\s+//;
  if ($h{req}) {
    $h{path}=$h{req};
    $h{path}=~s/^(\S+)\s+//;
    $h{path}=~s/\s+(\S+)$//;
    if ($h{path}=~/jpg/i || $h{path}=~/gif/i || $h{path}=~/png/i || $h{path}=~/swf/i) {
      $h{type}='graph';
    } elsif ($h{path}=~/\?/) {
      $h{type}='dyn';
    } else {
      $h{type}='other';
    }
  }
  $h{code} = $1;
  $s=~s/(\d+)\s+//;
  $h{bytes} = $1;
  $s=~s/\"([^\"]+)\"\s+//;
  $h{referer} = $1;
  $s=~s/(\d+)$//;
  $h{timeout} = $1;
  return \%h;
}


sub ParseTime {
  my $time = shift;
  my %t;
  ($t{day},$t{month},$t{year},$t{hour},$t{minut},$t{sec},$t{tz})=$time=~/^(\d+)\/(\S+)\/(\d+):(\d+):(\d+):(\d+)\s+(.\d+)/;
  return \%t;
}


sub FormatBytes {
  my ($bytes,$type) = @_;
  return 'ref:'.ref($bytes) if ref($bytes);
  return '-' if !$bytes && $bytes ne '0';
  my $show_bytes = 'M';
  #  return $bytes if defined $show_bytes && !$show_bytes;
  if ($type) {
    while ($bytes=~s/(\d)(\d{3})( |$)/$1 $2$3/) {  1;  }
         } else {
           if ($bytes > $GBYTES) {
             $bytes=round($bytes/$MBYTES,0);
             while ($bytes=~s/(\d)(\d{3})( |$)/$1\`$2$3/) {
               1;
             }
                    ;
                    $bytes="$bytes Мб";
                  } elsif ($show_bytes ne 'k' && ($bytes > $MBYTES || $show_bytes eq 'M')) {
                    $bytes=round($bytes/$MBYTES,2).' Мб';
                  } elsif ($bytes > 9999 || $show_bytes eq 'k') {
                    $bytes=round($bytes/$KBYTES,2).' Кб';
                  } else {
                    $bytes="$bytes байт";
                  }
           }
           return $bytes;
         }
