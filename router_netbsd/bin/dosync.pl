#!/usr/local/bin/perl
#use strict;

my $SRC = '/tmp/sync/';
my $DST = '/etc/orionet';

my $if_ext=`cat /etc/orionet/ifs/ext`;
my $if_int=`cat /etc/orionet/ifs/int`;
my $ip_ext=`cat /etc/orionet/ips/ext`;
my $ip_int=`cat /etc/orionet/ips/int`;


my %handlers=(ipf=>\&ipf,
              ipnat=>\&ipnat,
              copy=>\&copy,
	      dhcpd=>\&copy,
              arp=>\&arp);

my %files=('ipf.conf.users'=>'ipf',
           'ipf.conf.footer'=>'ipf',
           'ipf.conf.header'=>'ipf',
           'users.dhcpd'=>'dhcpd',
           'ipnat.conf.users'=>'ipnat',
           'ethers'=>'arp',
          );


my %found;

# Устанавливаем обработчики для каждого файл
foundFiles();

sub foundFiles {
  my ($dir)=@_;
  my $src=$SRC.$dir;
  opendir(dir,$src) || die "Can't open src dir $src";
  foreach (readdir(dir)) {
    if (-f "$src$_") {
      my $h;
      if (exists $files{$dir.$_}) {
        $h = $files{$dir.$_};
        next unless $h;
      } else {
        $h='copy';
      }
      $found{$h}=[] unless exists $found{$h};
      push @{$found{$h}},$dir.$_;
    } else {
      foundFiles("$dir$_/")
        unless /^\./;
    }
  }
  closedir(dir);
}
# Выполняются обработчики

foreach (keys %found) {
  my $ref = $handlers{$_};
  unless ($ref) {
    print STDERR "ERROR: no ref for handler $_\n";
    next;
  }
  my @f = @{$found{$_}};
  print STDERR "EXECUTE: $_ - ".join(' ',@f);
  my $res = &$ref(@f);
  print STDERR " = $res\n";
}

print STDERR "DONE: OK\n";

exit 0;


sub copy {
  foreach my $file (@_) {
    `cp -f $SRC/$file $DST/$file`;
    #  `mv -f $src/$file $dst/$file`;
    return undef if $?;
  }
  return 'ok';
}


##############
# Обработчики
##############

sub ipf {
  return 'copy error' unless copy(@_);
  `cat /etc/orionet/ipf.conf.header /etc/orionet/ipf.conf.users /etc/orionet/ipf.conf.footer | sed -e 's/\$if_ext/$if_ext/g' | sed -e 's/\$if_int/$if_int/g' | sed -e 's/\$ip_ext/$ip_ext/g' | sed -e 's/\$ip_int/$ip_int/g' > /etc/orionet/ipf.conf`;
  return 'cat error' if $?;
  `/etc/rc.d/ipf restart`;
  `/etc/rc.d/ipnat start`;
  # restart ipf
  return 'ok';
}

sub ipnat {
  return 'copy error' unless copy(@_);
  `cat /etc/orionet/ipnat.conf.header /etc/orionet/ipnat.conf.users /etc/orionet/ipnat.conf.footer | sed -e 's/\$if_ext/$if_ext/g' | sed -e 's/\$if_int/$if_int/g' | sed -e 's/\$ip_ext/$ip_ext/g' | sed -e 's/\$ip_int/$ip_int/g' > /etc/orionet/ipnat.conf`;
  return 'cat error' if $?;
  `/etc/rc.d/ipnat stop`;
  `/etc/rc.d/ipnat start`;
  # restart ipf
  return 'ok';
}

sub dhcpd {
  return 'copy error' unless copy(@_);
  my $pid=`cat /var/run/dhcpd.pid`;
  chomp($pid);
  `kill -TERM $pid`;
  return $? ? 'error' : 'ok';
}

sub arp {
  return 'copy error' unless copy(@_);
  `/usr/sbin/arp -d -a`;
  `/usr/sbin/arp -f /etc/orionet/ethers`;
  return $? ? 'error' : 'ok';
}
