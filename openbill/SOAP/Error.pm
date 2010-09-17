package openbill::SOAP::Error;
use strict;
use Data::Dumper;
use Exporter;
use Error;
use dpl::Error;
use UNIVERSAL qw( isa ) ;
use vars qw(@ISA
            @EXPORT);
@ISA = qw(Exporter
          dpl::Error);

sub new {
  my ($self,$som)  = @_;
  local $Error::Depth = $Error::Depth + 1;
  return $self->SUPER::new(som=>$som);
}

sub stringify {
  my $self = shift;
  return $self->{som} unless ref($self->{som});
  my $d = $self->{som}->faultdetail();
  my $str;
  foreach (keys %$d) {
    if (ref($d->{$_})=~/Error/) {
      $str=$d->{$_}->stringify();
    } else {
      $str=Dumper($_,$d->{$_});
    }
  }
  #$self->{som}->faultactor();
  return $str ? $self->{som}->faultstring()." ($str)" :  $self->{som}->faultstring();
}

1;
