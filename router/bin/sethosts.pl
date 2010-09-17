#!/usr/bin/perl
#. /usr/local/openbill/router/etc/ulog-conf.sh
use IO::File;
use strict;
use Data::Serializer;
use Data::Dumper;

my %config=(
            users_dump=>'/usr/local/openbill/router/etc/users.dump',
            users_fw=>'/usr/local/openbill/router/etc/users.fw',
            users_dhcpd=>'/usr/local/openbill/router/etc/users.dhcpd',
            ethers=>'/usr/local/openbill/router/etc/ethers',
           );

my $data = readdata();

WriteUsersFiles($data);

RestartDHCPD();
RestartFirewall();
print STDERR "DONE: OK\n";
#RestartARP(); перезапускаеся в firewall


sub WriteUsersFiles {
  my $data = shift;
  my $dhcpd = openfile($config{users_dhcpd});
  my $fw = openfile($config{users_fw});
  my $ethers = openfile($config{ethers});
  foreach my $h (@{$data->{hosts}}) {
    $dhcpd->print("host $h->{hostname} { hardware ethernet $h->{mac}; fixed-address $h->{ip}; }\n");
    $ethers->print("$h->{ip} $h->{mac}\n");
    $fw->print("echo User \"$h->{ip} - $h->{access_name} ($h->{hostname})\"\n");
    foreach (@{$h->{access_rules}}) {
      s/\$IP/$h->{ip}/g;
      s/\$MAC/$h->{mac}/g;
      $fw->print("$_\n");
    }
    $fw->print("\n");
  }
  closefile($dhcpd);
  closefile($fw);
  closefile($ethers);
}



sub RestartDHCPD  {
  print STDERR "INFO: Restart DHCPD\n";
  my $res = `killall -TERM dhcpd`;
  print STDERR "WARNING: Can't restart DHCPD ($?: $res)\n"  if $?;
}

sub RestartARP {
  print STDERR "INFO: Restart ARP\n";
  my $res = `/sbin/arp -f $config{ethers}`;
  print STDERR "WARNING: Can't restart ARP ($?: $res)\n"  if $?;
}

sub RestartFirewall {
  print STDERR "INFO: Restart Firewall\n";
  my $res = `/etc/rc.d/rc.firewall users 2&>1`;
  print STDERR "WARNING: Can't restart Firewall ($?: $res)\n"  if $?;
}


sub closefile {
  my ($file) = @_;
  $file->close  || print STDERR "ERROR: Can't close file\n"
}

sub openfile {
  my ($name) = @_;
  my $fh = new IO::File;
  unless ($fh->open("> $name")) {
    print STDERR "ERROR: Can't open '$name'\n";
    exit 1;
  }
  return $fh;
}


sub readdata {
  my $s = Data::Serializer->new();
  my $serialized;
  my $file = openfile($config{users_dump});
  while (<>) {
    $serialized.=$_;
    $file->print($_);
  }

  closefile($file);

  print STDERR "RECEIVE: OK\n";

  my $data = $s->deserialize($serialized);

  unless ($data) {
    print STDERR "ERROR: No data\n";
    exit 2;
  }


}
