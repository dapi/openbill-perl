package openbill::Server::Tariff;
use strict;
use dpl::Db::Database;
use openbill::Server::BaseDb;
use openbill::Tariff;
use Exporter;
use vars qw(@ISA);
@ISA = qw(Exporter
          openbill::Server::BaseDb);

openbill::Server::Base::addSOAPObject(tariff=>'openbill::Server::Tariff');

sub METHOD_get {
  my ($self,$id) = @_;
  my $s = tariff()->Load($id)
    || return undef;
  return $s->Data();
}

sub METHOD_list {
  my ($self,$where) = @_;
  return tariff()->DataList($where);
}

sub METHOD_create {
  my ($self,$data) = @_;
  my $res = tariff()->Create($data) || return undef;
  return $res->ID();
}

sub METHOD_delete {
  my ($self,$id) = @_;
  return tariff($id)->Delete($id);
}

sub METHOD_modify {
  my ($self,$id,$data) = @_;
  return tariff($id)->Modify($data);
}

1;
