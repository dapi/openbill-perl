package openbill::DataType::Date;
use strict;
use openbill::DataType::DateObject;
use Exporter;
use vars qw(@ISA
            @EXPORT);

@ISA=qw(Exporter openbill::DataType::DateObject);

sub ToSOAP {
  my $self = shift;
  return $self->TimeFormat('%Y-%m-%d');
}

sub string {
  my $self = shift;
  return $self->TimeFormat('%e %B %Y');
}

sub AsScalar {
  my $self = shift;
  return $self->TimeFormat('%Y-%m-%d');
}


1;
