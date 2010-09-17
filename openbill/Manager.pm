package openbill::Manager;
use strict;
use openbill::Base;
use openbill::MGroup;
use dpl::Db::Table;
use Error qw(:try);
use Exporter;
use vars qw(@ISA
            @EXPORT);

@ISA=qw(Exporter
        openbill::Base);

@EXPORT=qw(manager);

sub manager {
  return openbill::Manager->instance('manager',@_);
}

sub string {
  my $self = shift;
  my $str = "'".$self->Data('login').", '".$self->Data('name')."', (",$self->manager_group()->Data('name'),") '".$self->Data('comment')."'";
  $str.=" - администратор." if $self->IsAdmin();
  return $str;
}

sub manager_group {
  my $self = shift;
  return mgroup($self->Data('mgroup_id'));
}

sub HasAccess {
  my $self = shift;
  return $self->manager_group()->HasAccess(@_);
}

sub IsAdmin {
  my $self = shift;
  return $self->manager_group()->Data('is_admin');
}

sub DataFull {
  my $self = shift;
  my $data=$self->Data(@_);
  $data->{mgroup}=$self->manager_group()->Data('name');
  return $data;
}

sub GetName {
  my $self = shift;
  return $self->Data('name');
}

sub Create  {
  my ($self,$data) = @_;
  $self->checkParams($data,'login','name');
  return $self->SUPER::Create($data);
}

sub Login {
  my ($self,$login,$password) = @_;
  return undef unless
    $self->{table}->Load({login=>"$login",
                          is_active=>1,
                          password=>"$password"});
  $self->SetData($self->{table}->get());
  $self->SetID($self->Data($self->{idname}));
  return $self;
}

1;
