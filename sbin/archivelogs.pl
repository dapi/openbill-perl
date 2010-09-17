#!/usr/bin/perl
use strict;
use Date::Calc;
use LockFile::Simple qw(lock trylock unlock);
use Number::Format qw(:subs);
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval);

my $count;
my $dir = $ARGV[0];
my $arc_dir = $ARGV[1];
$|=1;
unless (-d $dir && -d $arc_dir) {
  print "��������� �������: /�������/��/�����������/ /�������/���/�������/\n";
  print "\n��� ��������� ��������� � ����� ���� hostname-2003-10-08.tar.bz2\n��� ����� ���� hostname-2003-10-08-*.log � ������� �� � �����\n\n";
  exit 1;
}

my $lockfile = '/var/run/archivelogs';
die "������ ������� �������"
  unless lock($lockfile);
$SIG{'HUP'} = 'IGNORE';
my $t0 = [gettimeofday];
my %CACHE;
my $count = 0;
opendir(DIR,$dir);
print "������ ��������: 0";
foreach my $file (readdir(DIR)) {
  next if $file=~/^\./ || !-f "$dir/$file";
  print "\r������ ��������: $count";
  if ($file=~/^(\S+-\d{4}-\d{2})-(\d{2}-\d{2}:\d{2})(-GMT)?\.(.+)$/) {
    my $key = "$1-$4";
    $CACHE{$key} = [] unless $CACHE{$key};
    push @{$CACHE{$key}}, $file;
    $count++;
  } elsif  ($file=~/^(\S+-\d{4}-\d{2})-(\d{2}-\d{2}:\d{2})((:\d{2})?\.minut)$/) {
    my $key = "$1-minut";
    $CACHE{$key} = [] unless $CACHE{$key};
    push @{$CACHE{$key}}, $file;
    $count++;
  } else {
    print STDERR "\n����������� ������ ����� �����: $file\n";
  }
}
closedir(DIR);
print "\r������ ��������: $count ������.\n";
print "������������� (".(keys %CACHE)." �������):\n";
my $c="01";
chdir($dir);
foreach my $arc (sort keys %CACHE) {
  my @files = @{$CACHE{$arc}};
  my $size = scalar @files;
  my $count = 0;
#  $c="0$c" if $c<10;
  my $e=' (����)' if -f $arc;
  print "[$c]  $arc$e: $size - ..";
  while (my @piece = splice(@files,0,100)) {
    my $files = join(' ',@piece);
    # tar �� ��������� ��������� ����� � ������ �����
    #    `tar --remove-files -C $dir -zuf $arc_dir$arc.tar.bz2 $files`;
    `rar mf -ep -o- -m5 $arc_dir$arc.rar $files`;
    die "������ ���������z rar $?" if $?;
    $count += scalar @piece;
    print "\r[$c]  $arc$e: $size - $count";
  }
  $c++;
  print "\n";
}

unlock($lockfile);

print "��������� �������: ".round(tv_interval($t0),2)." ���.\n";
