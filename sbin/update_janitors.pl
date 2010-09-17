#!/usr/bin/perl
#use lib qw(/home/danil/projects/openbill/
#           /home/danil/projects/dpl/);
use Pod::Usage;
use Getopt::Long;
use dpl::System;
use dpl::Context;
use dpl::Log;
use dpl::Db::Database;
use openbill::Locker;
use openbill::Janitor;
use openbill::Router;
use openbill::Server;
use strict;
use POSIX ":sys_wait_h";

$ENV{OPENBILL_ROOT}||='/usr/local/openbill/';
my $config = $ENV{OPENBILL_CONFIG} || "$ENV{OPENBILL_ROOT}etc/system.xml";

my $help;
my $router;
my $force;
my $verbose;
my $timeout=60;
my $options = GetOptions("verbose|v"=>\$verbose,
                         "config=s"=>\$config,
                         "force"=>\$force,
                         "timeout|t=i"=>$timeout,
                         "router=s"=>\$router,
                         "help|?"=>\$help,
                        ) || pod2usage(2);
pod2usage(1) if $help;


$|=1;
dpl::System::Define('openbill',$config);
dpl::Context::Init('openbill');
openbill::Server::InitLocalConnection(1);
$SIG{CHLD}="IGNORE";
print "Жду освобождения базы.. ";
print "ok\n";
print "Обновляю привратников (жду по $timeout сек.):\n";
my $list = openbill::Router::router()->List({use_janitor=>1});
my @pids;
#print "'$router'";
foreach my $r (@$list) {
  next if $router && ($router ne $r->Data('hostname'));

  my $jid = $r->Data('default_janitor_id');
  unless ($jid) {
    print STDERR $r->Data('hostname').' '."Обновление отклоненно, не прописан привратник!\n";
    next;
  }
  # TODO Create создаёт соответсвующие access_mode
  # TODO ругаться если force надо роутером который запрещён

#  $jid=5 if $jid=4;
  my $janitor = janitor()->Load($jid);
  my $hosts = $janitor->IsNeedToUpdate($r);
  if ($hosts) {
    my $pid = UpdateJanitor($janitor,$r,"$hosts hosts");
    push @pids, {pid=>$pid,
                 router=>$r};
  } elsif ($force) {
    my $pid = UpdateJanitor($janitor,$r,'forced');
    push @pids, {pid=>$pid,
                 router=>$r};
  } else {
    print $r->Data('hostname').' '."clear\n"
      if $verbose;
  }
}

my $kid;
my $has_childs;
if (@pids) {
  print "\n";
  sleep 5;
  do {
    print "Ожидаю окончания выполнения всех процессов (",scalar @pids,"): ";
    sleep 5;
    my @p;
    foreach (@pids) {
      $kid = waitpid($_->{pid}, WNOHANG);
      if ($kid>=0) {
        print $_->{router}->Data('hostname'), " ";
        push @p,$_;
      }
    }
    print "\n";
    @pids=@p;
  } while (@pids);

} else {
  print "нечего обновлять\n";
}

#waitpid(-1);
print "Выход\n";


sub UpdateJanitor {
  my ($janitor,$router,$hosts) = @_;
  local $SIG{ALRM} = sub { die "! Обновление затянулось (более $timeout сек.), прерываем..\n"; };
  my $f = fork();
  db()->Disconnect();
  db()->Connect();
  return $f if $f;
  db()->SuperSelectAndFetch("select * from router where router_id=? for update",
                            $router->ID());
  print $router->Data('hostname').' '."update ($hosts)\n";
  $janitor->UpdateHostsAccess($router);
  db()->Commit();
  exit(0);
}

__END__

=head1 NAME

  update_janitors.pl

=head1 SYNOPSIS

  update_janitors.pl [options]

 Options:
  -h, -?, -help            brief help message
  -c, --config             config
  -v, --verbose            verbose
  -r, --router             limit to router
  -f, --force              force update
  -t, --timeout            timeout of update


=cut
