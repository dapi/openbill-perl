package openbill::Server::Address;
use strict;
use openbill::Server::BaseDb;
use openbill::Address;
use Exporter;
use vars qw(@ISA);
@ISA = qw(Exporter
          openbill::Server::BaseDb);


openbill::Server::Base::addSOAPObject(address=>'openbill::Server::Address');


sub METHOD_get {
  my ($self,$id) = @_;
  my $b = address()->Load($id) || return undef;
  return $b->DataFull();
}

sub METHOD_list {
  my ($self,$p) = @_;
  $p={} unless $p;
  my $list = openbill::Address::address()->List($p);
  return [map {$_->DataFull()} @$list];
}

sub METHOD_create {
  my ($self,$data) = @_;
  my $res = address()->Create($data) || return undef;
  return $res->ID();
}

sub METHOD_find_or_create {
  my ($self,$bid,$room) = @_;
  my $a = address()->Find({building_id=>$bid,room=>$room});
  if ($a) {
    return $a->ID();
  } else {
    my $res = address()->Create({building_id=>$bid,
                                 room=>$room}) || return undef;
    return $res->ID();
  }
}

sub METHOD_modify {
  my ($self,$id,$data) = @_;
  return address($id)->Modify($data);
}

sub METHOD_delete {
  my ($self,$id) = @_;
  return address($id)->Delete($id);
}



1;
