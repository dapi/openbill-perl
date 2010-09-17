package openbill::Server::Street;
use strict;
use dpl::Db::Database;
use openbill::Server::BaseDb;
use openbill::Street;
use Exporter;
use vars qw(@ISA);
@ISA = qw(Exporter
          openbill::Server::BaseDb);

openbill::Server::Base::addSOAPObject(street=>'openbill::Server::Street');

sub METHOD_get {
  my ($self,$id) = @_;
  my $s = street()->Load($id)
    || return undef;
  return $s->DataFull();
}

sub METHOD_list {
  my ($self,$where) = @_;
  return street()->DataFullList($where);
}

sub METHOD_find {
  my ($self,$street) = @_;
  my $s = street()->Find($street);
  return ref($s) ? $s->ID() : undef;
}

sub METHOD_create {
  my ($self,$data) = @_;
  my $res = street()->Create($data) || return undef;
  return $res->ID();
}

sub METHOD_delete {
  my ($self,$id) = @_;
  return street($id)->Delete($id);
}

sub METHOD_modify {
  my ($self,$id,$data) = @_;
  return street($id)->Modify($data);
}

1;
