package openbill::SOAP::Serializer;
use vars qw(@ISA);
use Data::Dumper;
use openbill::DataType::Date;
use openbill::DataType::DateTime;
use openbill::DataType::Time;
use Text::Iconv;
@ISA = qw(SOAP::Serializer);


sub new {
  my $self = shift;
  $self = $self->SUPER::new(@_);
  $self->{_typelookup}->{base64} = [50, sub {1}, 'as_base64'];
  $self->{_typelookup}->{string} = [40, sub {1}, 'as_string'];
#  $self->{_typelookup}->{datetime} = [2, sub {UNIVERSAL::isa($_[0],'openbill::DateType::DateTime')}, 'as_dateTime2'];
#  $self->{_typelookup}->{time} = [3, sub {UNIVERSAL::isa($_[0],'openbill::DateType::Time')}, 'as_time2'];
  $self->{_converter}=Text::Iconv->new("koi8-r", "utf-8");
  #  $self->{_encoding}='koi8-r';
  $self->{_encoding}='UTF-8';
  return $self;
}

sub maptypetouri {
  my($self, $type, $simple) = @_;
  return 'xsd:date' if $type eq 'openbill__DataType__Date';
  return 'xsd:dateTime' if $type eq 'openbill__DataType__DateTime';
  return 'xsd:time' if $type eq 'openbill__DataType__Time';
  return $self->SUPER::maptypetouri($type,$simple);
}

sub encode_hash {
  my($self, $object, $name, $type, $attr) = @_;
  my $o = $object;
  my $a = $self->SUPER::encode_hash($object, $name, $type, $attr);
  my $k = 'xsi:type';
  return [$a->[0],$a->[1],$o->ToSOAP(),$a->[3]]
    if $a->[1]->{$k} eq 'xsd:date' || $a->[1]->{$k} eq 'xsd:time' || $a->[1]->{$k} eq 'xsd:dateTime';
  return $a;
}

sub as_string {
  my $self = shift;
  my($value, $name, $type, $attr) = @_;
  die "String value expected instead of @{[ref $value]} reference\n" if ref $value;
  $value=$self->{_converter}->convert($value);# if $h->{'xsi:type'} eq 'xsd:string';
#  print STDERR "value: $value\n";
  return [$name, {'xsi:type' => 'xsd:string', %$attr},
          SOAP::Utils::encode_data($value)];
}

1;
