#!/usr/bin/perl
use lib qw(/home/danil/projects/openbill/
           /home/danil/projects/dpl/);
use strict;
use Pod::Usage;
#use SOAP::Lite;
use Getopt::Long;
use openbill::SOAP::Server;
use openbill::SOAP::Serializer;
use openbill::SOAP::Deserializer;
use dpl::Context;
use dpl::Db::Database;
use openbill::System;
use dpl::Context;
use openbill::Server;

$ENV{OPENBILL_ROOT}||='/usr/local/openbill/';
my $config;# = $ENV{OPENBILL_CONFIG};
my $port = 1030;
my $server = '127.0.0.1';
my $help;
my $options = GetOptions(
                         "port=s"=>\$port,
                         "config=s"=>\$config,
                         "server=s"=>\$server,
                         "help|?"=>\$help,
                        ) || pod2usage(2);
pod2usage(1) if $help || !$config;


dpl::System::Define('openbill',$config);
dpl::Context::Init('openbill');

openbill::System::Init({-terminal=>1});

print "Openbill v$openbill::System::VERSION, server v$openbill::Server::VERSION\n";
#db()->Connect();
 # don't want to die on 'Broken pipe' or Ctrl-C

#$SIG{PIPE} = $SIG{INT} = 'IGNORE';
$SIG{PIPE} = $SIG{HUP} = 'IGNORE';
$SIG{CHLD}='IGNORE';

#print "Start daemon to port $port\n";
#*openbill::SOAP::Deserializer::old_deserialize = \&SOAP::Deserializer::deserialize;
#*SOAP::Deserializer::deserialize  = \&openbill::SOAP::Deserializer::deserialize;

$SOAP::Constants::DO_NOT_USE_CHARSET = 1;

my $daemon = openbill::SOAP::Server
  -> new (LocalAddr => $server, LocalPort => $port, Listen => 5, Reuse => 1) #, SSL_=>1
#  -> new (LocalAddr => '127.0.0.1', LocalPort => $port, Listen => 5, Reuse => 1) #, SSL_=>1
  -> serializer(openbill::SOAP::Serializer->new())
  -> deserializer(openbill::SOAP::Deserializer->new())
  -> dispatch_with(getSOAPObjects());
print "Contact to SOAP server at ", join(':', $daemon->sockhost, $daemon->sockport), "\n";
$daemon->handle;


__END__

=head1 NAME

  obs_soap_server.pl - OpenBill SOAP Server

=head1 SYNOPSIS

  obs_soap_server.pl [options]

 Options:
  -h, -?, -help            brief help message
  -s, --server             ip address to listen
  -p, --port               port number to listen
  -c, --config             config file


=cut
