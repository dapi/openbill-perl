package openbill::System;
use strict;
use openbill::Utils;
#use POSIX qw(locale_h);
#use openbill::Host;
#use openbill::Client;
use openbill::Base;
#use openbill::Street;
use dpl::Context;
use dpl::System;
use dpl::Log;
use dpl::Error;
use dpl::XML;
use dpl::Config;
use dpl::Db::Database;
use LockFile::Simple qw(lock trylock unlock);
use Exporter;
use vars qw(@ISA
            $VERSION
            @EXPORT);
@ISA=qw(Exporter);

@EXPORT=qw(GetModules);

$VERSION = 3;

# SOAP support since 1.9

sub Init {
  my ($is_terminal) = @_;
#  $SIG{'HUP'} = 'ignore'
#    if $is_terminal;
 # lockSemaphore()
  #  if exists $p->{-semaphore};
  #  my $today = new Date::Handler({date=>time});
  setting('terminal',$is_terminal);
  # Эти секунды прибавляются к текущему времени для проверки не выходят ли вставляемые
  # в статистике данные в будущее
  setting('today_plus',60*60*6);
  setting('interval',300); # Интервал для минутной статистики
  $ENV{OPENBILL_ROOT}||='/usr/local/openbill/';

#  $p->{-config} = $ENV{OPENBILL_CONFIG}
#    || "$ENV{OPENBILL_ROOT}etc/system.xml"
#      unless $p->{-config};
#  print STDERR "INIT OPENBILL SYSTEM\n";
  InitSystem();
  db()->Connect();
}

sub InitSystem {
  my $root = config()->root();
  #  die setting('subsystem');
  setContext('system_name',xmlDecode($root->findnodes('./system_name/node()')->pop()->data()));
  #  my $module = xmlText($root,'./logger/module') || fatal('Logger module is not defined');
  #  setting('logger_config',xmlText($root,'./logger/config') || fatal('Logger config is not defined'));
#  setlocale(LC_ALL,"ru_RU.KOI8-R");
  my %modules;
  foreach my $node ($root->findnodes('./modules/*')) {
    my $type = xmlDecode($node->nodeName());
    my $module = xmlText($node);
    $modules{$type}={} unless $modules{$type};
    my $file = $module;
    $file=~s/::/\//g;
    $file.=".pm";
    require $file;
    import $module;
    error("Такой модуль уже зарегистрирован: $type $module") if exists $modules{$type}->{$module};
    #    print STDERR "$module- $type\n";
    $modules{$type}->{$module}={file=>$file,
                                desc=>$module->moduleDesc()};
  }
  getSettings()->{modules}=\%modules;

  #   my $appender = Log::Log4perl::Appender->new(
  #                                               "Log::Dispatch::Email",
  #                                               subject => "Billing problem",
  #                                               to     => "danil@orionet.ru",
  #                                              );
  #   logger()->add_appender($appender);
}


sub GetModules {
  my $type = shift;
  my $s = getSettings()->{modules};
  return $type ? $s->{$type} : $s;
}

sub lockSemaphore {
  my $lockmgr = LockFile::Simple->make(-max => 3,
                                       -autoclean => 1,
                                       -delay => 1);

  unless ($lockmgr->lock()) {
    logger()->error('Another process is executing');
    exit;
  };
#  setContext('lock_manager',$lockmgr);
  #  $SIG{'INT'}  = \&SIGhandler;
  #  $SIG{'QUIT'}  = \&SIGhandler;
  #  $SIG{'TERM'}  = \&SIGhandler;
  #  $SIG{'__DIE__'}  = \&SIGhandler;
  #  setContext('LOCK_FILE',$LOCK_FILE);
  #  setContext('LOCK_MGR',$LOCKMGR);
}

#sub SIGhandler {
#  my($sig) = @_;
#  print "Caught a SIG$sig--shutting down ($@)\n";
#  MyExit();
#}


1;
