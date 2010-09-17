package openbill::Janitor::IPFW_Table;
use strict;
use Data::Serializer;
use openbill::Utils;
use openbill::Host;
use openbill::Router;
use openbill::Janitor;
use openbill::AccessMode;
use openbill::Utils;
use dpl::Context;
use dpl::System;
use dpl::Db::Filter;
use dpl::Db::Table;
use dpl::Db::Database;
use dpl::Log;
use IO::String;
use IO::File;
use Archive::Tar;
use dpl::Error;
use Exporter;
use vars qw(@ISA
            %JANITOR_STATUS
            $COMMAND_LINE

            @EXPORT);

%JANITOR_STATUS=(RECEIVE=>2,EXECUTE=>2,ERROR=>2,DONE=>1);

sub moduleDesc { 'Привратник по ipfw' }

$COMMAND_LINE="$SSH -i \${keysdir}\${hostname} \${login}@\${ip} /usr/local/openbill/janitors/getsync.sh";

@ISA=qw(Exporter
        openbill::Janitor::IPFW);

sub CreateTarFile {
  my ($self,$hosts) = @_;
  my $ipfw;
  my $dhcpd;
  my $ethers;
  return undef unless @$hosts;
  my $ipfw_index = 10000;
  my %hs;
  foreach my $h (@$hosts) {
    # ip, mac, hostname, access_name, access_rules, client_id
    #    $ipfw.="\n# client: $h->{client_id}, access: $h->{access_name}, host: $h->{hostname}, mac: $h->{mac}\n";

    my $mac = lc($h->{mac});
	my $hostname = $h->{hostname};
    unless ($h->{is_vpn}) {
      $mac=~s/\s+//g;
      if ($mac=~/[^a-f0-9:]/) {
        logger()->error("Неверный mac-адрес ($mac), host_id=".$h->ID());
        print STDERR "Неверный mac-адрес ($mac), host_id=".$h->ID()."\n";
        next;
      }
	  $hostname=~s/\s+//g;
	  $hostname=~s/[^a-z_0-9]/_/ig;
	  $hostname=~s/^[^a-z]/a/ig;
	  while (exists $hs{$hostname}) { $hostname.="_"; };
#	  print "hostname: $hostname\n";
    }
    my $mac = lc($h->{mac});
    $ethers.="$h->{ip} $h->{mac}\n";
    $dhcpd.="host $hostname { hardware ethernet $h->{mac}; fixed-address $h->{ip}; }\n";
    my $line="$h->{ip} $h->{access_name}-$h->{access_type}\n";
    $ipfw.="$line\n";
  }
  my $tar = Archive::Tar->new;
  $tar->add_data('ipfw_table.users',$ipfw);
  # $tar->add_data('dhcpd.users',$dhcpd);
  # $tar->add_data('ethers',$ethers);

  my $fh = IO::String->new();
  my $fhf = IO::File->new('> /tmp/t');
  my $l = $tar->write($fhf);
  my $length = $tar->write($fh);
#  die "$l $length";
  unless ($length) {
    logger()->error("Не могу создать tar архив для привратника $self->{id}");
    return undef;
  }
#   my $sr = $fh->string_ref();
#   unless ($sr) {
#     print STDERR "(2) Не могу создать tar архив для привратника $self->{id}\n";
#     logger()->error("(2) Не могу создать tar архив для привратника $self->{id}");
#     return undef;
#   }
  #  die "$sr";
  return `cat /tmp/t`;
#  return $$sr;
}


1;
