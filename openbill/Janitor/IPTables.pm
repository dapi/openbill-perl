package openbill::Janitor::IPTables;
use strict;
use openbill::Tariff;
use Data::Dumper;
use Data::Serializer;
use openbill::Utils;
use openbill::Host;
use openbill::Router;
use openbill::Janitor;
use openbill::AccessMode;
use openbill::Client;
use dpl::Context;
use dpl::System;
use dpl::Log;
use dpl::Db::Filter;
use dpl::Db::Table;
use dpl::Db::Database;
use Exporter;
use vars qw(@ISA
            %JANITOR_STATUS
            $COMMAND_LINE

            @EXPORT);

%JANITOR_STATUS=(RECEIVE=>2,INFO=>2,WARNING=>2,ERROR=>2,DONE=>1);

sub moduleDesc { 'Привратник по iptables' }

$COMMAND_LINE="$SSH -i \${keysdir}\${hostname} \${login}\@\${ip} \${root}bin/sethosts.pl";

@ISA=qw(Exporter
        openbill::Janitor);

sub IsNeedToUpdate {
  my ($self,$router) = @_;
  my $id = $self->ID();
  my $rid = $router->ID();
  my $a = db()->SelectAndFetchOne("select count(ip) as count from host where janitor_id=$id and router_id=$rid and bits=0 and am_time is null");
  return $a->{count} || $router->Data('need_whole_update');
}

sub _wholeUpdate {1}

sub UpdateHostsAccess {
  my ($self,$router,$restore) = @_;
  my $hosts_new =
    SuperSelectAndFetchAll(qq(select * from host
                              where router_id=?
                              and bits=0 and am_time is null
                              and janitor_id=?),
                           $router->ID(),
                           $self->ID());
  my @hi;

  my $n =
  $restore=1
    if $self->_wholeUpdate() ||
      $router->Data('need_whole_update');

  db()->Query('update router set need_whole_update=0 where router_id=?',
              $router->ID())
    if $router->Data('need_whole_update');

  print STDERR "UpdateHostsAccess ($self, $self->{id}): ($router, ",$router->ID(),"), update whole hosts list: $restore\n";
  my $time = today();
  my @h = (@$hosts_new);
  # Обновить всех
  if ($restore) {
    my $hosts_old =
    SuperSelectAndFetchAll(qq(select * from host
                              where router_id=?
                              and bits=0 and am_time is not null
                              and janitor_id=?),
                           $router->ID(),
                           $self->ID());
    push @h, (@$hosts_old);

  }
  my $is_night_mode = SuperSelectAndFetch("select * from system_param where param='night_mode'")->{value};
  my $co = @h;
  print "Обновляю $co хостов\n";
  foreach my $h (@h) {
    next unless $h->{is_active};
    my $host = host()->Load($h->{host_id});
    my $am = $host->GetAccessMode() || next;
    my $mac = lc($host->Data('mac'));
    unless ($host->Data('is_vpn')) {
      next if $mac eq 'none' || $mac eq '';
      $mac=~s/\s+//g;
      unless (CheckMac($mac)) {
        logger()->error("Неверный mac-адрес ($mac), host_id=".$host->ID());
        print STDERR "Неверный mac-адрес ($mac), host_id=".$host->ID()."\n";
        next;
      }
    }
    my $timestamp = $host->Data('am_time');
    $timestamp = $time unless $timestamp;
    my $client = $host->Data('client_id') ? client($host->Data('client_id')) : undef;
    unless ($client) {
      logger()->error("Нет клиента для хоста ".$host->ID());
      next;
    }
    if ($client) {
      my $tariff = $client->GetCurrentTariff();
      $tariff = $tariff->Data()
        if $tariff;
      push @hi,{ip=>$host->IP(),  host_id=>$host->ID(),
                client=>$client->Data(),
                night_speed=>$client->Data('night_speed'),
		bonus_speed=>$client->LoyaltyBonus() || 0,
                client_id=>$host->Data('client_id'),
		comment=>$host->Data('comment'),
                tariff=>$tariff,
                mac=>$mac,
                current_speed=>$host->Data('current_speed'),
                am_time=>$host->Data('am_time'),
                is_limited=>$host->Data('is_limited'),
                #                is_night_mode=>$host->Data('is_night_mode'),
                is_night_mode=>$is_night_mode,
                hostname=>lc($host->Data('hostname')),
                password=>$host->Data('password'),
                timestamp=>$timestamp->TimeFormat('%d-%M-%y/%T'),
                access_type=>$am->Data('type'),
                access_name=>$am->Data('name'),
                access_rules=>$am->Data('rules')};
    }
#    print $host->IP().' - '.$host->Data('hostname').' - '.$am->Data('name')."\n"
#      unless $host->Data('am_time');
  }
#  print STDERR "Remote update ($self, $self->{id}) $router $router->{id}\n";
  if ($self->remoteUpdate($router,\@hi,$restore)) {
    $time = filter('datetime')->ToSQL($time);
    foreach (@$hosts_new) {
      db()->Query("update host set am_time=? where host_id=?",$time,$_->{host_id});
    }
    db()->Commit();
    return 1;
  } else {
    db()->Commit();
    return 0;
  }
}

sub remoteUpdate {
  my ($self,$router,$hosts) = @_;
  #  print STDERR "base remoteUpdate: $router $router->{id}\n";
  my $r = $router->Data();
  unless (@$hosts) {
    print "Странно, нечего обновлять для роутера $r->{hostname}..\n";
    return undef;
  }

#  print "Обновляю привратника на $r->{hostname}: ";
  my %sconf = (portable=>0,
               serializer=>'Data::Dumper',
               compress=>0); #TODO в конфиг
  my $s = Data::Serializer->new(%sconf);
  my $status = RemoteExecute($COMMAND_LINE,\%JANITOR_STATUS,
                             {login=>$r->{login},
                              hostname=>$r->{hostname},
                              ip=>$r->{real_ip}},
                             $s->serialize({hosts=>$hosts}));
  print Dumper($status);
  if ($status && $status->{DONE} eq 'OK') {
    print "OK\n";
    return 1;
  }
  print "Ошибка обновления привратника $r->{hostname}: $status->{DONE}!\n";
  return undef;
}

1;
