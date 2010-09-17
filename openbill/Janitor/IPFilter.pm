package openbill::Janitor::IPFilter;
use strict;
use Data::Serializer;
use openbill::Utils;
use openbill::Host;
use openbill::Router;
use openbill::Janitor;
use openbill::AccessMode;
use dpl::Context;
use dpl::System;
use dpl::Db::Filter;
use dpl::Db::Table;
use dpl::Db::Database;
use Archive::Tar;
use dpl::Error;
use Exporter;
use vars qw(@ISA
            %JANITOR_STATUS
            $COMMAND_LINE

            @EXPORT);

%JANITOR_STATUS=(RECEIVE=>2,EXECUTE=>2,ERROR=>2,DONE=>1);

sub moduleDesc { 'Привратник по ipf на flash router' }

$COMMAND_LINE="$SSH -i \${keysdir}\${hostname} \${login}@\${ip} /etc/orionet/bin/getsync.sh";

@ISA=qw(Exporter
        openbill::Janitor::IPTables);

sub CreateTarFile {
  my ($self,$hosts) = @_;

  my $ipf;
  my $ipnat;
  my $dhcpd;
  my $ethers;
  return undef unless @$hosts;
  foreach my $h (@$hosts) {
    # ip, mac, hostname, access_name, access_rules, client_id
    $ipf.="\n# client: $h->{client_id}, access: $h->{access_name}, host: $h->{hostname}, mac: $h->{mac}\n";
    $ipnat.="\n# client: $h->{client_id}, access: $h->{access_name}, host: $h->{hostname}, mac: $h->{mac}\n";
    $dhcpd.="host $h->{hostname} { hardware ethernet $h->{mac}; fixed-address $h->{ip}; }\n";
    foreach (@{$h->{access_rules}}) {
      if (s/ipf:\s+//) {
        $ipf.="$_\n";
      } elsif (s/ipnat:\s+//) {
        $ipnat.="$_\n";
      } else {
        fatal("Не известный тип строки: $_");
      }
    }
    $ipf=~s/\$ip/$h->{ip}/mg;
    $ipnat=~s/\$ip/$h->{ip}/mg;
    $ipf.="\n";
    $ipnat.="\n";
    $ethers.="$h->{ip} $h->{mac}\n";
    # $ipf_conf
  }
  my $tar = Archive::Tar->new;
  $tar->add_data('ipf.conf.users',$ipf);
  $tar->add_data('ipnat.conf.users',$ipnat);
  $tar->add_data('users.dhcpd',$dhcpd);
  $tar->add_data('ethers',$ethers);

  my $fh = IO::String->new();
  my $length = $tar->write($fh);
  unless ($length) {
    logger()->error("Не могу создать tar архив для привратника $self->{id}");
    return undef;
  }
  my $sr = $fh->string_ref();
  return $$sr;
}

sub remoteUpdate {
  my ($self,$router,$hosts) = @_;
  my $r = $router->Data();
#  print "Обновляю привратника на $r->{hostname}: ";
  my $tar = $self->CreateTarFile($hosts);
  return undef unless $tar;
  if ($tar) {
    my $status = RemoteExecute($COMMAND_LINE,\%JANITOR_STATUS,
                               {login=>$r->{login},
                                hostname=>$r->{hostname},
                                ip=>$r->{real_ip}},
                               $tar
                              );
    if ($status && ref($status) && $status->{DONE} eq 'OK' && !$status->{ERROR}) {
 #     print "OK\n";
      return 1;
    }
    #print "Ошибка обновления привратника $r->{hostname} ($status->{DONE}, ".join(',',@{$status->{ERROR}}).")!\n";
    print "Ошибка обновления привратника $r->{hostname} ($status->{DONE})!\n";
    return undef;
  } else {
    print "Ошибка обновления привратника $r->{hostname} - не создан tar файл\n";
  }
}

1;
