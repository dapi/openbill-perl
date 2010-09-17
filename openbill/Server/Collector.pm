package openbill::Server::Collector;
use strict;
use dpl::Db::Database;
use openbill::Server::BaseDb;
use openbill::Collector;
use Exporter;
use vars qw(@ISA);
@ISA = qw(Exporter
          openbill::Server::BaseDb);

openbill::Server::Base::addSOAPObject(collector=>'openbill::Server::Collector');

sub METHOD_list {
  my ($class,$p)=@_;
  $p={} unless $p;
  my $list = openbill::Collector::collector->List($p);
  return  [map {$_->DataFull()} @$list];
}

sub METHOD_get {
  my ($class,$id) = @_;
  my $c = openbill::Collector::collector($id) || return undef;
  return $c->DataFull();
}

sub METHOD_create {
  my ($self,$data) = @_;
  my $res = collector()->Create($data) || return undef;
  return $res->ID();
}


sub METHOD_delete {
  my ($self,$id) = @_;
  return collector($id)->Delete($id);
}

sub METHOD_modify {
  my ($self,$id,$data) = @_;
  return collector($id)->Modify($data);
}

sub METHOD_collect {
  my ($self,$p) = @_;
  my $collectors = collector()->List();
  foreach (@$collectors) {
    $_->Collect($p);
  }
  return 1;
}


1;
