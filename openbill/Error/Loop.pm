package openbill::Error::Loop;
use strict;
use Exporter;
use openbill::Error;
use vars qw(@ISA
            @EXPORT
            $FATAL_ERROR);
@ISA = qw(Exporter
          openbill::Error);

sub new {
    my $self  = shift;
    local $Error::Depth = $Error::Depth + 2;
    return @_==1 ? $self->SUPER::new(-text=>"$_[0]") : $self->SUPER::new(@_);
}

1;
