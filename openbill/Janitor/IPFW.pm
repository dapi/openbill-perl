package openbill::Janitor::IPFW;
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
        openbill::Janitor::IPTables);

sub CreateTarFile {
  my ($self,$hosts) = @_;
  my $ipfw;
  my $ipfw_table;
  my $dhcpd;
  my $ethers;
  unless (@$hosts) {
    print STDERR "no hosts $self $self->{id}\n";
    return undef;
  }
#  print STDERR "Create Tar File $self $self->{id}\n";
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
    my $a = $ipfw_index + $h->{host_id};
    my $line="\${add_sub} $a $h->{timestamp}/$h->{access_name}/$h->{access_type} ";
    foreach my $rule (@{$h->{access_rules}}) {
      $rule=~s/\$ip/$h->{ip}/mg;
      $rule=~s/\$mac/lc($h->{mac})/emg;
      $line.="'$rule' ";
    }
    $ipfw.="$line\n";
    $ipfw_table.="$h->{ip} $h->{access_type}-$h->{access_name}\n";
  }
  my $tar = Archive::Tar->new;
  $tar->add_data('ipfw.users',$ipfw);
  $tar->add_data('ipfw_table.users',$ipfw_table);
  $tar->add_data('dhcpd.users',$dhcpd);
  $tar->add_data('ethers',$ethers);

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

sub remoteUpdate {
  my ($self,$router,$hosts) = @_;
  my $r = $router->Data();
  #  print "Обновляю привратника на $r->{hostname}: ";
  my $tar = $self->CreateTarFile($hosts);
#  print STDERR "CC: $router\n";
  return undef unless $tar;

  if ($tar) {

 #   print STDERR "C: $COMMAND_LINE\n";
    my $status = RemoteExecute($COMMAND_LINE,\%JANITOR_STATUS,
                               {login=>$r->{login},
                                hostname=>$r->{hostname},
                                ip=>$r->{real_ip}},
                               $tar
                              );
    if ($status && ref($status) && $status->{DONE} eq 'OK' && !$status->{ERROR}) {
#      print "OK\n";
      return 1;
    }
    $status->{ERROR}=[] unless $status->{ERROR};
    print "Ошибка обновления привратника  $r->{hostname} ($status->{DONE}, ".join(',',@{$status->{ERROR}}).")!\n";
    return undef;
  } else {
    print "Ошибка обновления привратника $r->{hostname} - не создан tar файл\n";
    return undef;
  }
}

1;
