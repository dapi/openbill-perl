#!/usr/bin/perl
use strict;
use POSIX qw(:termios_h);
use Data::Serializer;
my ($term, $oterm, $echo, $noecho, $fd_stdin);

my $obj = Data::Serializer->new(
                                serializer => 'Storable',
#                                digester   => 'MD5',
#                                cipher     => 'DES',
                               );


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

my $ipt='/usr/local/sbin/iptables';
my $ipts='/usr/local/sbin/iptables-save';
my $iface='eth1';

my $real_ip='10.20.30.15';

my %ip=(1=>'10.100.21.201',
        2=>'10.100.21.202',
        3=>'10.100.21.203',
        4=>'10.100.21.204',
        5=>'10.100.21.205',
        6=>'10.100.21.206');

my %on = LoadData();
ResetIp(\%on);

if ($ARGV[0] eq 'start') {
  print "start\n";
#  `$ipt -F`;
#  `$ipt -F -t nat`;
#  `$ipt -t nat -A POSTROUTING -o $iface -j SNAT --to $real_ip`;
#  `$ipt -A FORWARD -m limit --limit 10/minute -j LOG --log-level info --log-prefix DENY_`;
#  `$ipt -A FORWARD -j DROP`;
#  foreach (keys %ip) {
#    `$ipt -I FORWARD -d $ip{$_} -j ACCEPT`;
#    `$ipt -I FORWARD -s $ip{$_} -j ACCEPT`;
#  }
  exit 1;
} else {
  my $k;
  do {
    ShowList();
    $k = readkey();
#    if ($k eq '0') {
#      my $off=1 unless  keys %on;
#      map {exists $on{$ip{$_}} || $off ? ToggleIP($_) : 1;} keys %ip;
    #
    if (exists $ip{$k}) {
      ToggleIP($k);
    }

    SaveData();
    #   `$ipts > /etc/iptables.save`;
  } while ($k ne 'x');
  ResetIp(\%on);
}

sub ResetIp {
  print "Restart firewall..";
  `/etc/rc.d/rc.firewall users`;
  print "\nSetting data..";
  foreach (keys %ip) {
    if ($on{$_}) {
      SetIpOn($ip{$_});
    } else {
      SetIpOff($ip{$_});
    }
  }
  print "\n";
}

sub SaveData {
  open(FILE,'> /tmp/devita.perm');
  print FILE $obj->serialize(\%on);
  close(FILE);
#  print "SaveData: ".join(',',%on)."\n";
}

sub LoadData {
  print "Load data..";
  open(FILE,'/tmp/devita.perm');
  my $str;
  while (<FILE>) {
    $str.=$_;
#    die "- $str";
  }
#  die "- $_";
  my $a = $obj->deserialize($str);
  close(FILE);
  #die join(',',%$a);
  my %h;
  foreach (keys %ip) {
    $h{$_}=$a->{$_} || 0;
  }
  print "\n";
#  die join(',',%h);
  return %h;
}

sub SetIpOn {
  my $i = shift;
  `$ipt -I USER_FORWARD -d $i -j DROP`;
  `$ipt -I USER_FORWARD -s $i -j DROP`;
}

sub SetIpOff {
  my $i = shift;
#  `$ipt -D USER_FORWARD -d $i -j DROP`;
#  `$ipt -D USER_FORWARD -s $i -j DROP`;
}

sub ToggleIP {
  my ($num) = @_;
#  print "SaveData1 ($num): ".join(',',%on)."\n";
  if ($on{$num}) {
#    SetIpOn($ip{$num});
    $on{$num}=0;
  } else {
#    SetIpOff($ip{$num});
    $on{$num}=1;
  }
#  print "SaveData2 ($num): ".join(',',%on)."\n";
}

sub ShowList {
  print "\n-----------------------------\nСписок хостов:\n";
  foreach (sort keys %ip) {
    my $is_on = $on{$_} ?  'ВКЛЮЧЕН' : 'выключен';
    print "$_ - $ip{$_} - $is_on\n";
  }
  #  print "0 - включить/выключить всех\nx - выйти\n";
  print "x - выйти\n";
}
