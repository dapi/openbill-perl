package openbill::Error;
use strict;
use Exporter;
use dpl::Error;
use vars qw(@ISA
            @EXPORT
            $FATAL_ERROR);
@ISA = qw(Exporter
          dpl::Error);

sub new {
    my $self  = shift;
    local $Error::Depth = $Error::Depth + 2;
    return @_==1 ? $self->SUPER::new(-text=>"$_[0]") : $self->SUPER::new(@_);
}

1;
