package openbill::Payment;
use strict;
use openbill::Host;
use openbill::Base;
use openbill::Client;
use openbill::Manager;
use dpl::Db::Table;
use dpl::Log;
use dpl::Error;
use Exporter;
use vars qw(@ISA
            @EXPORT);

@ISA=qw(Exporter
        openbill::Base);

@EXPORT=qw(payment);

sub payment {
  return openbill::Payment->instance('payment',@_);
}

sub Create  {
  my ($self,$data) = @_;
  $self->fatal("Сумма платежа не указана или отрицательна")
    unless $data->{summa}>0;
  $self->checkParams($data,'summa','client_id','date');
  return $self->SUPER::Create($data);
}

sub PreCreate {
  my ($self,$data) = @_;
  $self->checkParams($data,'client_id','date');
  return $self->SUPER::Create($data);
}

sub List {
  my ($self,$p,$order) = @_;
  my @p;
  if (exists $p->{from_id}) {
    push @p,"id>=$p->{from_id}";
    delete $p->{from_id};
  }
  push @p, $p
    if $p && %$p;
#  $order='id';
  return $self->SUPER::List(\@p,$order);
}


sub client {
  my $self = shift;
  return openbill::Client::client($self->Data('client_id'));
}

sub DataFull {
  my ($self,$key) = @_;
  $self->Load() unless $self->isLoaded();
  $self->{data}->{description}||=$self->{data}->{type} ? 'Услуги связи' : 'Подключение';
  $self->{data}->{description}='Реализация' if $self->{data}->{type}>1;
  $self->{data}->{manager}||=manager($self->{data}->{manager_id})->DataFull();
  $self->{data}->{client}||=$self->client()->string();
  $self->{data}->{method}||=table('payment_method')->Load($self->Data('payment_method_id'));
  return $key ? $self->{data}->{$key} : $self->{data};
}


sub Delete {
  die 'not implemented';
}

1;
