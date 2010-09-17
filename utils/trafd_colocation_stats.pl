#!/usr/bin/perl
#use strict;
use Number::Format qw(:subs);
use Date::Handler;
use IO::File;
use Date::Parse;
use IPC::Open3;
use IPC::Open2;
use strict;
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

#my $IP='217.107.177.196';
my $IP='10.100';

my $KBYTES=1000;
my $MBYTES=$KBYTES*$KBYTES;
my $GBYTES=$MBYTES*$KBYTES;
my $tz=undef;#'+400';
my $file = $ARGV[0];# || '/var/trafd/trafd.eth0';
print "Одну минуту..\n";
my %TRAF; # month -> port -> is_local/foreign -> in
my $ALL;
my ($mintime,$maxtime);
my ($all,$line,$time,$parsedlines);
my $by_port=0;
foreach (@ARGV) {
  parsefile($_);
}
sub parsefile {
  my $file = shift;
  print "$file\n";
  my $format = $by_port ? 'orionet_col' : 'iopenbill';
  my $cmd="/usr/local/bin/traflog -o $format -a -n -i ./$file";
  my $err;
  local *CATCHERR = IO::File->new_tmpfile();
  my $pid = open3(gensym, \*FILE, ">&CATCHERR", $cmd);
  #my $pid = open2(\*FILE, gensym,  $cmd);
  my $code = $?;

  while (<FILE>) {
    s/\n|\r//g;
    $line++;
    next unless $_;
    next if /From.*Port|Summary/;
    if (s/.* at (.+)\s+-\s+(.+)$//) {
      #     my ($dfrom,$dto)=($1,$2);
      #     my $time_from = str2time($dfrom,$tz) || die("Немогу разобрать время: $dfrom");
      #     my $time_to = str2time($dto,$tz) || die("Немогу разобрать время: $dto");
      #     my $date = new Date::Handler({ date => $time_to,
      #                                    time_zone => 'Europe/Moscow',
      #                                    locale => 'ru_RU.KOI8-R'});
      #     $time = (($date->Year()*12+$date->Month())*31+$date->Day())*24+$date->Hour();
      #     $traffic{$time}={date=>
      #                      new Date::Handler({ date => {
      #                                                   year => $date->Year(),
      #                                                   month => $date->Month(),
      #                                                   day => $date->Day(),
      #                                                   hour => $date->Hour(),
      #                                                   min => 0,
      #                                                   sec => 0,
      #                                                  },
      #                                          time_zone => 'Europe/Moscow',
      #                                          locale => 'ru_RU.KOI8-R'})} unless exists $traffic{$time};
      next;
    }

    my ($t,$from,$from_port,$to,$to_port,$bytes);
    if ($by_port) {
      ($t,$from,$from_port,$to,$to_port,$bytes) = split(/\s+/,$_);
    } else {
      ($t,$from,$to,$bytes) = split(/\s+/,$_);
    }

    unless ($t) {
      #    print STDERR "$_\n";
      next;
    }
    if ($from=~/10\.100\./ && $to=~/10\.100\./) {
      next;
    }
    my $time = new Date::Handler({ date => $t,
                                   time_zone => 'Europe/Moscow',
                                   locale => 'ru_RU.KOI8-R'});
    $mintime=$time if $time<$mintime || !$mintime;
    $maxtime=$time if $time>$maxtime;
    my $month = $time->TimeFormat('%B-%d');
    $TRAF{$month}={all=>{0=>0,1=>0,all=>0}} unless exists $TRAF{$month};
    my $mt = $TRAF{$month};
    my $port;
    my $local; # 0 - remote, 1 - local, 2 - unknown
    my $is_in;
    if ($from=~/^$IP/) {
      $port=$from_port;
      $local=IsLocal($to);
      #    $is_in=0;
    } elsif ($to=~/^$IP/) {
      $port=$to_port;

      #   $is_in=1;
    } else {
      $local=IsLocal($from) && IsLocal($to);
      $port=0;
      $local=2 unless $local;
    }
    #  $mt->{$port}={0=>{0=>0,1=>0},1=>{0=>0,1=>0}} unless exists $mt->{$port};
    #  $mt->{$port}->{$local}->{$is_in}+=$bytes;
    if ($by_port) {
      $mt->{$port}={0=>0,1=>0} unless exists $mt->{$port};
      $mt->{$port}->{$local}+=$bytes;
    }
    $mt->{all}->{$local}+=$bytes;
    $mt->{all}->{all}+=$bytes;
    $ALL+=$bytes;
    $parsedlines++;
  }
  waitpid($pid, 0);
}


sub IsLocal {
  my $ip = shift;
  return 1 if $ip=~/^10\.100/ || $ip=~/^10\.20/ || $ip=~/^10\.30/ || $ip=~/^192\.168/ || $ip=~/^217\.107\.177/ || $ip=~/^213\.59\.74/ || $ip=~/^81\.4\.242/;
  return 0;
}

foreach my $month (sort keys %TRAF) {
  print "MONTH: $month\n";
  my $table = Text::FormatTable->new(' r | r | r | r ');
  $table->head('порт','глобальный','локальный','неизвестный');
  $table->rule('-');
  my $m = $TRAF{$month};
  my $by_port=0;
  if ($by_port) {
    foreach my $port (sort keys %$m) {
      #    $table->row($port,"$m->{$port}->{0}->{0}/$m->{$port}->{0}->{1}","$m->{$port}->{1}->{0}/$m->{$port}->{1}->{1}");
      $table->row($port,FormatBytes($m->{$port}->{0}),FormatBytes($m->{$port}->{1}),FormatBytes($m->{$port}->{2}));
    }
  } else {
    $table->row('ALL',FormatBytes($m->{all}->{0}),FormatBytes($m->{all}->{1}),FormatBytes($m->{all}->{2}));
  }
  $table->rule('=');
  print $table->render(70);
  print "ВСЕГО:\t".FormatBytes($m->{all}->{all})."\n";
}


print "Минимальное время: $mintime, $maxtime\n";
print "Всего строк: $line, обработано $parsedlines\n";

#
# $table->head('время',map {$_} sort keys %ips);
# $table->rule('-');
#
# my $a;
# foreach my $t (sort keys %traffic) {
#   my @a;
#   my $r=0;
#   foreach (sort keys %ips) {
#     my $s = $traffic{$t}->{$_};
#     push @a,FormatBytes($s);
#     $r=1 if $s;
#   }
#   $table->row($traffic{$t}->{date}->TimeFormat('%b %d %H:00'),@a)
#     if $r;
#
# }
# $table->rule('=');
# print $table->render(90);
# print "ВСЕГО:\t".FormatBytes($all)."\n";


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
