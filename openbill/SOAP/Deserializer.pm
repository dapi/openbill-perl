package openbill::SOAP::Deserializer;
use dpl::Context;
use strict;
use vars qw(@ISA);
use Text::Iconv;
use Data::Dumper;
use openbill::DataType::Date;
use openbill::DataType::DateTime;
use openbill::DataType::Time;
@ISA = qw(SOAP::Deserializer);

sub new {
  my $self = shift;
  $self = $self->SUPER::new(@_);
  $self->{_converter}=Text::Iconv->new("utf-8", "koi8-r");
  return $self;
}


sub deserialize {
  my $self = shift;
  my $som = $self->SUPER::deserialize(@_);
  setContext('som',$som);
  return $som;
}

sub decode_value {
  my ($self,$p) = (shift,shift);
  my $h =  $p->[1];
  my $k = 'xsi:type';

  return openbill::DataType::Date->FromSOAP($p->[3]) if $h->{$k} eq 'xsd:date';
  return openbill::DataType::DateTime->FromSOAP($p->[3]) if $h->{$k} eq 'xsd:dateTime';
  return openbill::DataType::Time->FromSOAP($p->[3]) if $h->{$k} eq 'xsd:time';
  my $value = $self->SUPER::decode_value($p,@_);
  return $self->{_converter}->convert($value) if $h->{$k} eq 'xsd:string';
  return $value+0 if $h->{$k} eq 'xsd:int' ||  $h->{$k} eq 'xsd:float' || $h->{$k} eq 'xsd:long';
   if (ref($value)=~/HASH/) {
     foreach (keys %$value) {
#       print STDERR "hash $_=$value->{$_}\n";
     }
   } elsif (ref($value)=~/ARRAY/) {
#     print STDERR "ARRAY $h->{$k}=$value\n";
     foreach (@$value) {
#       print STDERR "A ".Dumper($_)."\n";
     }
     return $value;
   } else {
#     print STDERR "decode $h->{$k}=$value\n";
   }

  return $value;
}

1;
