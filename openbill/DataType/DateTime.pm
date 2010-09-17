package openbill::DataType::DateTime;
use strict;
use openbill::DataType::DateObject;
use Exporter;
use vars qw(@ISA
            @EXPORT);

@ISA=qw(Exporter openbill::DataType::DateObject);

#http://www.w3schools.com/schema/schema_dtypes_date.asp

sub ToSOAP {
  my $self = shift;
  return $self->TimeFormat('%Y-%m-%dT%H:%M:%S');
}

sub string {
  my $self = shift;
  return $self->TimeFormat('%Y-%m-%d %H:%M:%S');
}

sub AsScalar {
  my $self = shift;
  return $self->TimeFormat('%Y-%m-%d %H:%M:%S');
}


1;
