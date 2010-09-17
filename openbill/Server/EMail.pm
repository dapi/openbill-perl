package openbill::Server::EMail;
use strict;
use dpl::Db::Database;
use openbill::Server::BaseDb;
use openbill::EMail;
use openbill::Client;
use openbill::Utils;
use dpl::Error;
#use openbill::Sendmail;
use openbill::Error;
use Email::Valid;
use Exporter;
use vars qw(@ISA);
@ISA = qw(Exporter
          openbill::Server::BaseDb);

openbill::Server::Base::addSOAPObject(email=>'openbill::Server::EMail');

sub METHOD_get {
  my ($self,$email) = @_;
  my $s = email()->Load($email)
    || return undef;
  return $s->DataFull();
}

sub METHOD_list {
  my ($self,$where) = @_;
  return email()->DataFullList($where);
}

sub METHOD_create {
  my ($self,$data) = @_;
  my $list = email()->List({email=>$data->{email}});
  fatal("Такой email уже заведён на клиента ".$list->[0]->DataFull('client'))
    if @$list;
  my $client=client($data->{client_id})->Load() || fatal("Нет такого клиента: $data->{client_id}");
  fatal("Неверный email: $data->{email}")
    unless Email::Valid->address($data->{email});
  my $email = email()->Create($data) || return undef;
  my $res = $email->DataFull();
#  notify('create_email',{email=>$res});
  return $email->ID();
}

sub METHOD_delete {
  my ($self,$email) = @_;
  return email($email)->Delete();
}

sub METHOD_modify {
  my ($self,$email,$data) = @_;
  my $e = email($email);
  #  my $old = $e->DataFull();
  my $res = $e->Modify($data);
  return undef unless $res;
  #  notify('modify_old',{new=>$email->DataFull(),
#                       old=>$old});
  return $res;

}

1;
