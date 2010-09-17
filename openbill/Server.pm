package openbill::Server;
use strict;
use dpl::Error;
use dpl::Context;
use dpl::System;
use openbill::System;
use openbill::DataType::Date;
use openbill::DataType::Time;
use openbill::DataType::DateTime;
use openbill::Server::Base;
use openbill::Server::Period;
use openbill::Server::System;
use openbill::Server::Client;
use openbill::Server::Manager;
use openbill::Server::MGroup;
use openbill::Server::Street;
use openbill::Server::Address;
use openbill::Server::Building;
use openbill::Server::Collector;
use openbill::Server::Service;
use openbill::Server::IPTraff;
use openbill::Server::Payment;
use openbill::Server::Tariff;
use openbill::Server::Host;
use openbill::Server::Router;
use openbill::Server::Janitor;
use openbill::Server::EMail;

#use dpl::Db::Database;
use Digest::MD5;
use Exporter;
use vars qw(@ISA
            @EXPORT
            $VERSION);

@ISA=qw(Exporter);
@EXPORT=qw(getSOAPObjects);

( $VERSION ) = '$Revision: 1.6 $ ' =~ /\$Revision:\s+([^\s]+)/;

sub LocalExecute {
  my ($object,$method) = (shift,shift);
  fatal("Нет такого объекта $object") unless exists $openbill::Server::Base::SOAP_OBJECTS{$object};
  my $class = $openbill::Server::Base::SOAP_OBJECTS{$object};
  my $self =  bless {method=>$method,class=>$class,object=>$object}, $class;
  #  $self->CheckPermission($object,$method) || fatal("No access to `$method' in object $object for you");
  return $self->Execute($method,@_);
}

sub InitLocalConnection {
  my $is_terminal=1;
  $ENV{OPENBILL_ROOT}||='/usr/local/openbill/';
  my $config = $ENV{OPENBILL_CONFIG} || "$ENV{OPENBILL_ROOT}etc/system.xml";
  openbill::System::Init($is_terminal);

}

sub getSOAPObjects {
  return \%openbill::Server::Base::SOAP_OBJECTS;
}



1;
