#!/usr/bin/perl
#use strict;
use Number::Format qw(:subs);
use Date::Handler;
use IO::File;
use Date::Parse;
use IPC::Open3;
use IPC::Open2;
use Text::FormatTable;
use Symbol qw(gensym);

use POSIX qw(:termios_h);
my ($term, $oterm, $echo, $noecho, $fd_stdin);

$fd_stdin = fileno(STDIN);
$term     = POSIX::Termios->new();
$term->getattr($fd_stdin);
$oterm     = $term->getlflag();

$echo     = ECHO | ECHOK | ICANON;
$noecho   = $oterm & ~$echo;

sub cbreak {
  $term->setlflag($noecho);     # ok, so i don't want echo either
  $term->setcc(VTIME, 1);
  $term->setattr($fd_stdin, TCSANOW);
}

sub cooked {
  $term->setlflag($oterm);
  $term->setcc(VTIME, 0);
  $term->setattr($fd_stdin, TCSANOW);
}

sub readkey {
  my $key = '';
  cbreak();
  sysread(STDIN, $key, 1);
  cooked();
  return $key;
}

END { cooked() }


my $KBYTES=1000;
my $MBYTES=$KBYTES*$KBYTES;
my $GBYTES=$MBYTES*$KBYTES;
my @local_ips = ('192.168.0.1',
                 '192.168.0.2',
                 '192.168.0.3',
                 '192.168.0.4',
                 '192.168.0.5');
my %ips;
my %foreign_ips;
my %traffic;
my $tz=undef;#'+400';
my $file = $ARGV[0] || '/var/trafd/trafd.eth0';
print "Одну минуту..\n";
my $cmd="/usr/local/bin/traflog -a -n -i $file";
my $err;
 local *CATCHERR = IO::File->new_tmpfile();
my $pid = open3(gensym, \*FILE, ">&CATCHERR", $cmd);
#my $pid = open2(\*FILE, gensym,  $cmd);
my $code = $?;
my ($all,$line,$time);
while (<FILE>) {
  s/\n|\r//g;
  next unless $_;
  next if /From.*Port|Summary/;
  if (s/.* at (.+)\s+-\s+(.+)$//) {
    my ($dfrom,$dto)=($1,$2);
    my $time_from = str2time($dfrom,$tz) || die("Немогу разобрать время: $dfrom");
    my $time_to = str2time($dto,$tz) || die("Немогу разобрать время: $dto");
    my $date = new Date::Handler({ date => $time_to,
                                   time_zone => 'Europe/Moscow',
                                   locale => 'ru_RU.KOI8-R'});
    $time = (($date->Year()*12+$date->Month())*31+$date->Day())*24+$date->Hour();
    $traffic{$time}={date=>
                     new Date::Handler({ date => {
                                                  year => $date->Year(),
                                                  month => $date->Month(),
                                                  day => $date->Day(),
                                                  hour => $date->Hour(),
                                                  min => 0,
                                                  sec => 0,
                                                 },
                                         time_zone => 'Europe/Moscow',
                                         locale => 'ru_RU.KOI8-R'})} unless exists $traffic{$time};
    next;
  }
  $line++;
  my @a = /^\s*(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/;
  die("Неверная строка: '$_'")
    unless @a;
  my ($from,$fp,$to,$tp,$proto,$bytes,$all_bytes)=@a;
  $fp=0 if $fp eq 'client';
  $tp=0 if $tp eq 'client';
  $all+=$bytes;
  SaveLine($from,$to,$bytes);
}
waitpid($pid, 0);

my $table = Text::FormatTable->new(' r | '.join(' | ',map {"l"} keys %ips));
$table->head('время',map {$_} sort keys %ips);
$table->rule('-');

my $a;
foreach my $t (sort keys %traffic) {
  my @a;
  my $r=0;
  foreach (sort keys %ips) {
    my $s = $traffic{$t}->{$_};
    push @a,FormatBytes($s);
    $r=1 if $s;
  }
  $table->row($traffic{$t}->{date}->TimeFormat('%b %d %H:00'),@a)
    if $r;

}
$table->rule('=');
print $table->render(90);
print "ВСЕГО:\t".FormatBytes($all)."\n";

sub ShowTime {
  my $t = shift;

}

sub SaveLine {
  my ($from,$to,$bytes) = @_;
  foreach (@local_ips) {
    if ($from eq $_) {
      $ips{$from}=1;
      $traffic{$time}->{$from}+=$bytes
        unless $to=~/^192.168.0/ || $to=~/^169./;
      return;
    } elsif ($to eq $_) {
      $ips{$to}=1;
      $traffic{$time}->{$to}+=$bytes
        unless $from=~/^192.168.0/ || $from=~/^169./ ;
      return;
    }
  }
  return if $from=~/^192.168.0/ || $from=~/^169./;
  $foreign_ips{$from}=1;
  $traffic{$time}->{$from}+=$bytes;
  $ips{$from}=1;
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

    print "\nЖми любую клавишу для выхода:\n";
    readkey();
