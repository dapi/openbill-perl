package openbill::EMail;
use strict;
use openbill::Utils;
use openbill::Base;
use openbill::Client;
use openbill::Router;
use openbill::Janitor;
use openbill::Address;
use openbill::AccessMode;
use dpl::Context;
use dpl::System;
use dpl::Log;
use dpl::Error;
use dpl::Db::Filter;
use dpl::Db::Table;
use dpl::Db::Database;
use openbill::Sendmail;
use Error qw(:try);
use Exporter;
use vars qw(@ISA
            @EXPORT);

@ISA=qw(Exporter
        openbill::Base);

@EXPORT=qw(email);

sub email {
  return openbill::EMail->instance('email',@_);
}

sub DataFull {
  my ($self,$key) = @_;
  $self->Load() unless $self->isLoaded();
  $self->{data}->{client}||=client($self->{data}->{client_id})->string()
    if $self->{data}->{client_id};
  return $key ? $self->{data}->{$key} : \%{$self->{data}};
}

sub List {
  my ($self,$where) = @_;
  return $self->SUPER::List($where);
}

sub Create  {
  my ($self,$data) = @_;
  $data={} unless $data;
  $self->checkParams($data,'email','client_id');
  $data->{createtime}=today();
  return $self->SUPER::Create($data);
}


1;
