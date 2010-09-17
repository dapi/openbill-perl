package openbill::DataType::DateObject;
use strict;
use Date::Handler;
use Date::Handler::Delta;
use Date::Parse;
use Date::Language;
use Exporter;
use vars qw(@ISA
            @EXPORT);

@ISA=qw(Exporter Date::Handler);

sub FromSOAP {
  my ($self,$value) = @_;
  return undef unless $value;
  my $time = str2time($value) || fatal("Не могу распознать дату из SOAP: $value");
#  print STDERR "FromSOAP: $value,$time\n";
  return $self->new({
                     date=>$time, # TODO locale ииз конфига, time_zone из параметров переданных сервером или
                     time_zone=>'Europe/Moscow'
                    });
}

sub ToSOAP {
  die 'ToSoap is not realized';
}

1;
