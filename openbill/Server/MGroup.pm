package openbill::Server::Mgroup;
use strict;
use dpl::Db::Database;
use dpl::Db::Table;
use openbill::Server::BaseDb;
use openbill::MGroup;
use Exporter;
use vars qw(@ISA);
@ISA = qw(Exporter
          openbill::Server::BaseDb);

openbill::Server::Base::addSOAPObject(mgroup=>'openbill::Server::Mgroup');


sub METHOD_get {
  my ($self,$id) = @_;
  my $s = mgroup()->Load($id)|| return undef;
  return $s->DataFull();
}

sub METHOD_list {
  my ($self,$where) = @_;
  return mgroup()->DataList($where);
}

sub METHOD_addMethod {
  my ($self,$mid,$p) = @_;
  $p->{mgroup_id}=$mid;
  return table('mgroup_method')->Create($p);
}

sub METHOD_deleteMethod {
  my ($self,$mid,$p) = @_;
  $p->{mgroup_id}=$mid;
  return table('mgroup_method')->Delete($p);
}

sub METHOD_listMethods {
  my ($self,$mid,$p) = @_;
  return table('mgroup_method')->List({mgroup_id=>$mid});
}

sub METHOD_create {
  my ($self,$data) = @_;
  my $res = mgroup()->Create($data) || return undef;
  return $res->ID();
}

sub METHOD_delete {
  my ($self,$id) = @_;
  return mgroup($id)->Delete($id);
}

sub METHOD_modify {
  my ($self,$id,$data) = @_;
  return mgroup($id)->Modify($data);
}

1;
