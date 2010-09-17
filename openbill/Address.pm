package openbill::Address;
use strict;
use openbill::Host;
use openbill::Base;
use openbill::Building;
use dpl::Db::Table;
use Exporter;
use vars qw(@ISA
            @EXPORT);

@ISA=qw(Exporter
        openbill::Base);

@EXPORT=qw(address);

sub address {
  return openbill::Address->instance('address',@_);
}

sub building {
  my $self = shift;
  my $bid = $self->Data('building_id');
  return openbill::Building::building($bid)
    || $self->fatal("Дом с ID=$bid ненайдена");
}

sub string {
  my $self = shift;
  return $self->building()->string().', кв. '.$self->Data('room');
}

sub Create  {
  my ($self,$data) = @_;
  $self->checkParams($data,'room');
  return $self->SUPER::Create($data);
}

sub DataFull {
  my ($self,$key) = @_;
  $self->Load() unless $self->isLoaded();
  my $b = $self->building();
  $self->{data}->{building}||=$b->Data('number');
  $self->{data}->{street}||=$b->street()->Data('name');
  return $key ? $self->{data}->{$key} : $self->{data};
}

sub Find {
  my ($self,$hr) = @_;
  my $a = $self->{table}->Load($hr) || return undef;
  $self->SetData($self->{table}->get());
  $self->SetID($self->Data($self->{idname}));
  return $self;
}


1;
