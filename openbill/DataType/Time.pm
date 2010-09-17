package openbill::DataType::Time;
use strict;
use openbill::DataType::DateObject;
use Exporter;
use vars qw(@ISA
            @EXPORT);

@ISA=qw(Exporter openbill::DataType::DateObject);

sub ToSOAP {
  my $self = shift;
  return $self->TimeFormat('%H:%M:%S');
}

sub string {
  my $self = shift;
  return $self->TimeFormat('%H:%M:%S');
}

sub AsScalar {
  my $self = shift;
  return $self->TimeFormat('%H:%M:%S');
}



1;
