package openbill::Server::Manager;
use strict;
use dpl::Db::Database;
use openbill::Server::BaseDb;
use openbill::Manager;
use Exporter;
use vars qw(@ISA);
@ISA = qw(Exporter
          openbill::Server::BaseDb);

openbill::Server::Base::addSOAPObject(manager=>'openbill::Server::Manager');


sub METHOD_get {
  my ($self,$id) = @_;
  my $s = manager()->Load($id)|| return undef;
  return $s->DataFull();
}



sub METHOD_list {
  my ($self,$where) = @_;
  return manager()->DataFullList($where);
}

sub METHOD_create {
  my ($self,$data) = @_;
  my $res = manager()->Create($data) || return undef;
  return $res->ID();
}

sub METHOD_delete {
  my ($self,$id) = @_;
  return manager($id)->Delete($id);
}

sub METHOD_modify {
  my ($self,$id,$data) = @_;
  return manager($id)->Modify($data);
}

sub METHOD_changePassword {
  my ($self,$id,$password) = @_;
  $id=$self->{manager}->ID() unless $id;
  return manager($id)->Modify({password=>$password});
}

1;
