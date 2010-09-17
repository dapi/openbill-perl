package openbill::Server::Janitor;
use strict;
use dpl::Db::Database;
use openbill::Server::BaseDb;
use openbill::Janitor;
use Exporter;
use vars qw(@ISA);
@ISA = qw(Exporter
          openbill::Server::BaseDb);

openbill::Server::Base::addSOAPObject(janitor=>'openbill::Server::Janitor');

sub METHOD_get {
  my ($self,$id) = @_;
  my $s = janitor()->Load($id)
    || return undef;
  return $s->DataFull();
}

sub METHOD_list {
  my ($self,$where) = @_;
  return janitor()->DataList($where);
}

sub METHOD_create {
  my ($self,$data) = @_;
  my $res = janitor()->Create($data) || return undef;
  return $res->ID();
}

sub METHOD_delete {
  my ($self,$id) = @_;
  return janitor($id)->Delete($id);
}

sub METHOD_modify {
  my ($self,$id,$data) = @_;
  return janitor($id)->Modify($data);
}

sub METHOD_find {
  my ($self,$janitor) = @_;
  my $c = janitor()->Find($janitor);
  return ref($c) ? $c->DataFull() : $c;
}




1;
