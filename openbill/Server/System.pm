package openbill::Server::System;
use strict;
use dpl::Web::Session;
use dpl::System;
use dpl::Db::Table;
use dpl::Db::Database;
use dpl::Context;
use openbill::Manager;
use openbill::Server::Base;
use openbill::System;
use Exporter;
use vars qw(@ISA);
@ISA = qw(Exporter
          openbill::Server::Base);

openbill::Server::Base::addSOAPObject(system=>'openbill::Server::System');

sub METHOD_login {
  my ($self,$p)=@_;
  db()->Commit();
  setContext('manager',$self->{manager} =
             manager()->Login($p->{login},$p->{password})
             || $self->fatal("ACCESS DENIED"));
  return  {version=>$openbill::System::VERSION,
           access =>$self->getAccessedFunctions(),
           session=>$self->newSession($self->{manager}->ID(),$p->{soft},$p->{version}),
           system =>context('system_name'),
           manager=>$self->{manager}->DataFull(),
           soft=>'openbill'};
}

sub getAccessedFunctions {
  return {client=>[qw(list list_accounts get hosts
                      charges payments find send_mail getChargeRecord getBalance
                      history list_charges)],
          system=>[qw(modules)]
         }
}

sub METHOD_modules {
  my ($self,$p)=@_;
  return GetModules($p);
}

sub newSession {
  my ($self,$mid,$soft,$version) = @_;
  fatal("internal error 45")
    unless $self->{manager};
  my $session = dpl::Web::Session::generate();
  table('manager_session')->Create({manager_id=>$mid,
                                    session_id=>$session,
                                    soft=>$soft,
                                    version=>$version,
                                    last_time=>today(),
                                    create_time=>today()})
    || fatal("Error generating session: $session");
  return $session;
}



1;
