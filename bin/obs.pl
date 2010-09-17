#!/usr/bin/perl
#use lib qw(/home/danil/projects/openbill/
#           /home/danil/projects/dpl/);
use Pod::Usage;
use SOAP::Lite;
use Getopt::Long;
use dpl::System;
use dpl::Context;
use dpl::Log;

use openbill::Shell;
use openbill::Shell::Period;
use openbill::Shell::Street;
use openbill::Shell::Payment;
use openbill::Shell::Client;
use openbill::Shell::Collector;
use openbill::Shell::IPTraff;
use openbill::Shell::Building;
use openbill::Shell::Host;
use openbill::Shell::Address;
use openbill::Shell::Manager;
use openbill::Shell::MGroup;
use openbill::Shell::Router;
use openbill::Shell::Janitor;
use openbill::Shell::Tariff;
use openbill::Shell::EMail;
use strict;

my $login = '';
my $password = '';
#use openbill::Server;
my $show_bytes ='m';

$ENV{OPENBILL_ROOT}||='/usr/local/openbill/';
my $config = $ENV{OPENBILL_CONFIG} || "$ENV{OPENBILL_ROOT}etc/system.xml";

my $proxy = 'http://billing.oriopay.ru:1031/';

my $help;
my $options = GetOptions("login=s"=>\$login,
                         "password=s"=>\$password,
                         "server=s"=>\$proxy,
                         "config=s"=>\$config,
                         "help|?"=>\$help,
                         "e=s"=>\$openbill::Shell::suppress_print,
                         "bytes=s"=>\$show_bytes,
                        ) || pod2usage(2);
pod2usage(1) if $help;


#shift @ARGV && 0) if $ARGV[0] eq '-b';

dpl::System::Define('openbill shell');
dpl::Context::Init('openbill shell');

setting('show_bytes',lc($show_bytes));

my $shell = openbill::Shell->new(); #SSL_=>1
$shell->init();
$login=$ENV{LOGIN} || $ENV{USER} unless $login;# && $password;
$password=$shell->AskPassword($login)
  if $login && !$password;

$shell->Connect($proxy,$login,$password);

my $res=1;
if (@ARGV) {
  $res=!$shell->ExecuteLine(join(' ',@ARGV));
} else {
  $res=!$shell->Run();
}
$res=0 unless $res;
print "Exit with result: $res\n";
exit($res);


__END__

=head1 NAME

  obs.pl - Using OpenBill Shell

=head1 SYNOPSIS

  obs.pl [options] [obs commands ...]

 Options:
  -h, -?, -help            brief help message
  -l, --login              login
  -p, --password           password
  -s, --server             URI to SOAP server
                           Examples: http://openbill.ru:1030/
  -c, --config             config file
  -b, --bytes              Bytes output format.
                           b - bytes, m - Mb (default).
  -e                       Suppress debug print

=cut
