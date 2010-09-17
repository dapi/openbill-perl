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
  my $time = str2time($value) || fatal("�� ���� ���������� ���� �� SOAP: $value");
#  print STDERR "FromSOAP: $value,$time\n";
  return $self->new({
                     date=>$time, # TODO locale ��� �������, time_zone �� ���������� ���������� �������� ���
                     time_zone=>'Europe/Moscow'
                    });
}

sub ToSOAP {
  die 'ToSoap is not realized';
}

1;
