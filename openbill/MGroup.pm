package openbill::MGroup;
use strict;
use openbill::Base;
use dpl::Db::Table;
use Error qw(:try);
use Exporter;
use vars qw(@ISA
            @EXPORT);

@ISA=qw(Exporter
        openbill::Base);

@EXPORT=qw(mgroup);

sub mgroup {
  return openbill::MGroup->instance('mgroup',@_);
}

sub string {
  my $self = shift;
  my $str = $self->Data('name');
  return $str;
}

sub DataFull {
  my $self = shift;
  my $data = $self->Data(@_);
  $data->{methods}=
    table('mgroup_method')->List({mgroup_id=>$self->ID()});
  $data->{managers}=
    table('manager')->List({mgroup_id=>$self->ID()});
  return $data;
}

sub HasAccess {
  my ($self,$object,$method)=@_;
  return 'full' if $self->Data('is_admin');
  return 'full'; # TODO hack
  my $rec =
    table('mgroup_method')->Load({mgroup_id=>$self->ID(),
                                  object=>$object,
                                  method=>$method})
      || table('mgroup_method')->Load({mgroup_id=>$self->ID(),
                                       object=>$object,
                                       method=>undef});
  return undef unless $rec;
  return $rec->{params} ? $rec->{params} : 'full';
}

sub GetName {
  my $self = shift;
  return $self->Data('name');
}

sub Create  {
  my ($self,$data) = @_;
  $self->checkParams($data,'name');
  return $self->SUPER::Create($data);
}

1;
