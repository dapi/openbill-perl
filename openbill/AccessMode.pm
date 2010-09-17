package openbill::AccessMode;
use strict;
use openbill::Utils;
use openbill::Base;
use dpl::Context;
use dpl::Log;
use dpl::Error;
use dpl::Db::Filter;
use dpl::Db::Table;
use Error qw(:try);
use Exporter;
use vars qw(@ISA
            @EXPORT);

@ISA=qw(Exporter
        openbill::Base);

@EXPORT=qw(access_mode);

sub access_mode {
  return openbill::AccessMode->instance('access_mode',@_);
}

sub Create  {
  my ($self,$data) = @_;
  $self->checkParams($data,'name','type','rules');
  return $self->SUPER::Create($data);
}

1;
