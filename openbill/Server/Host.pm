package openbill::Server::Host;
use strict;
use dpl::Db::Database;
use dpl::Db::Table;
use openbill::Server::BaseDb;
use openbill::Host;
use openbill::Client;
use openbill::Utils;
use openbill::Sendmail;
use openbill::Manager;
use dpl::Context;
use Exporter;
use vars qw(@ISA);
@ISA = qw(Exporter
          openbill::Server::BaseDb);

openbill::Server::Base::addSOAPObject(host=>'openbill::Server::Host');

sub METHOD_get {
  my ($self,$id) = @_;
  my $s = host()->Load($id)
    || return undef;
  my $data=$s->DataFull();
  $data->{attaches} =
    table('host_attach_log')->
      List({host_id=>$id});
  $data->{log} =
    table('host_log')->
      List({host_id=>$id});
  foreach (@{$data->{log}}) {
    $_->{manager}=manager($_->{manager_id})->DataFull();
  }
  return $data;
}

sub METHOD_check_link {
  my ($self,$id) = @_;
  my $s = host()->Load($id)
    || return undef;
  return $s->CheckLink();
}

sub METHOD_access_types {
  my $self = shift;
  my @a;
  my $res = db()->SuperSelectAndFetchAll('select type, count(name) from access_mode group by type order by type');
  foreach (@$res) {
    push @a,$_->{type};
  }
  return \@a;
}

sub METHOD_list {
  my ($self,$where) = @_;
  if (ref($where) && $where->{ip}) {
    $where->{ip}=inet_aton($where->{ip});
  }
  return host()->DataFullList($where);
}

sub METHOD_list_all {
  my ($self,$month) = @_;
  #  push @$where,"
  $month=dpl::System::today() unless $month;
  my $sth = db()->Query('select * from host');
  my @l;
  my %clients;
  my %tariff;
  while ($_=$sth->fetchrow_hashref()) {
    if ($_->{client_id}) {
      $clients{$_->{client_id}}=client($_->{client_id})->
        FindCurrentTariff($month)
          unless $clients{$_->{client_id}};
      $_->{tariff_id}=$clients{$_->{client_id}};

      $tariff{$_->{tariff_id}} =
        openbill::Tariff::tariff($_->{tariff_id})->Data()
            unless $tariff{$_->{tariff_id}};

      $_->{tariff} = $tariff{$_->{tariff_id}};
    }
    $_->{host}=inet_fromint($_->{ip},$_->{bits});
    push @l,$_;
  }
  $sth->finish();
  return \@l;
}



sub METHOD_create {
  my ($self,$data) = @_;
  $data->{manager_id}=context('manager')->ID();
  my $host = host()->Create($data) || return undef;
  my $res = $host->DataFull();
  my $c = client($host->Data('client_id'));
  if ($c) {
    notify('create_host',{host=>$res,
                          client=>$c->DataFull()});
    $host->AttachToClient($c);
  }
  return $host->ID();
}

sub METHOD_delete {
  my ($self,$id) = @_;
  my $h = host()->Load($id) || return undef;
  return $h->Delete();
}

sub METHOD_modify {
  my ($self,$id,$data) = @_;
  my $host = host($id);
  my $old = $host->DataFull();
  my $res = $host->Modify($data);
  return undef unless $res;
  my $c = client($host->Data('client_id'));
  notify('modify_host',{new=>$host->DataFull(),
                        client=>$c->DataFull(),
                        old=>$old})
    if $c;
  return $res;

}

sub METHOD_attach {
  my ($self,$host,$client,$date,$comment) = @_;
  my $c = client($client);
  $date=ParseDate($date) if $date;
  return host($host)->AttachToClient($c,$date,$comment);
}


1;
