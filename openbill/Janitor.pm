package openbill::Janitor;
use strict;
use openbill::Utils;
use openbill::Base;
use openbill::Router;

use dpl::Log;
use dpl::Context;
use dpl::Db::Table;
use Date::Parse;
use Exporter;
use vars qw(@ISA
            %CHECKLINK_STATUS
            $CHECKLINK_COMMAND_LINE

            @EXPORT);

@ISA=qw(Exporter
        openbill::Base);

@EXPORT=qw(janitor);

%CHECKLINK_STATUS=(ARPING=>2);

$CHECKLINK_COMMAND_LINE=$SSH.' -i ${keysdir}${hostname} ${login}@${ip} "/usr/local/openbill/janitors/check_host.sh -n ${count} ${ips}"';


sub CheckLink {
  my ($self,$router,$count) = (shift,shift,shift);
  my $r = $router->Data();
  $count=3 unless $count<=0;
  my $status = RemoteExecute($CHECKLINK_COMMAND_LINE,\%CHECKLINK_STATUS,
                             {login=>$r->{login},
                              hostname=>$r->{hostname},
                              count=>$count,
                              ip=>$r->{real_ip},
                              ips=>join(' ',@_)},
                            );
  logger()->debug("checkhost",join(' ',@_),openbill::Server::Base::mydump($status));
  if ($status && !$status->{ERROR}) {
    logger()->debug("Проверяю связь на $r->{hostname}: OK");
    my %ips;
    foreach (ref($status->{ARPING}) ? @{$status->{ARPING}} : $status->{ARPING}) {
      my ($ip,$result,@d)=split(';',$_);
      $ips{$ip}={result=>$result,
                 mac=>$d[0],
                 time=>$d[1],
                 loss=>$d[2],
                 count=>$d[3]};
    }
    return \%ips;
  }
  logger()->debug("Ошибка проверки связи undef");
  return undef;
}

sub janitor {
  return openbill::Janitor->instance('janitor',@_);
}

sub string {
  my $self = shift;
  my $d = $self->Data();
  return "[$d->{id}] $d->{name} / $d->{module}";
}

sub DataFull {
  my ($self,$key) = @_;
  $self->Load() unless $self->isLoaded();

  unless (exists $self->{data}->{module_desc}) {
    my $module = $self->Data('module');
    $self->{data}->{module_desc} ||=openbill::System::GetModules('janitor')->{$module}->{desc};
  }

  return $key ? $self->{data}->{$key} : $self->{data};
}


sub Create  {
  my ($self,$data) = @_;
  $self->checkParams($data,'name','module');
  my $res=$self->SUPER::Create($data);
  return undef unless $res;
  my $module = $self->Data('module');
  return $module eq ref($self) ? $self :
    $self->changeClass(openbill::System::GetModules('janitor')->{$module}->{file},$module);
}


sub init {
  my ($self) = @_;
  return $self unless $self->isLoaded();
  my $module = $self->Data('module');
  return $self if !$module || $module eq ref($self);
  my $self = $self->changeClass(openbill::System::GetModules('janitor')->{$module}->{file},$module);
  return $self->init();
}

sub List {
  my ($self,$module) = @_;
  my @janitors;
  my $list = table('janitor')->List();
  foreach (@$list) {
    next if $module && $module ne $_->{module};
    push @janitors, janitor($_->{id},$_);
  }
  return \@janitors;
}


1;
