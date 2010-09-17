package openbill::Invoice;
use strict;
use openbill::Util;
use openbill::Config;
use openbill::Host;
use openbill::Base;
use Exporter;
use vars qw(@ISA
            @EXPORT);

@ISA=qw(Exporter
        openbill::Base);

@EXPORT=qw(invoice);


sub Create {
  my $self = shift;
}

sub Load {
  my ($self,$cid,$month) = @_;
}

# type - 0 подключение
#      - 1 абонплата
#      - 2 трафик
#      - 10.. пользовательские

sub AddItem {
  my ($self,$price,$quantity,$type,$title) = @_;
}

sub GetSumma {
  my $self = shift;
}

sub GetItems {
  my $self = shift;
}

sub GetWrittenSumma {
  my $self = shift;
}

1;
