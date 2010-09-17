package openbill::Server::Service;
use strict;
use dpl::Error;
use dpl::Db::Database;
use dpl::Db::Filter;
use openbill::Server::BaseDb;
use openbill::Period;
use openbill::Utils;
use openbill::Client;
use Exporter;
use vars qw(@ISA);
@ISA = qw(Exporter
          openbill::Server::BaseDb);

openbill::Server::Base::addSOAPObject(service=>'openbill::Server::Service');

sub METHOD_ob_subscribe {
  my ($self,$service_name,$subscriber,$date) = @_;
  my $client = client()->Load($subscriber)
    || die "No such client $subscriber";
  my $db = db();
  my $s = $db->SuperSelectAndFetch('select * from subscribes where client_id=? and service_name=?',
                                   $client->ID(),
                                   $service_name);
  if ($s) {
    if ($s->{is_subscribed}) {
      print STDERR "$service_name: Client ($subscriber) is already subscribed ad $s->{subscribe_date}";
      return 3;
    } else {
      $db->Update('subscribes',
                  {subscribe_date=>$date,
                   is_subscribed=>1},
                  {client_id=>$s->{client_id}});
      return 2;
    }
  } else {
    $db->Insert('subscribes',
                {client_id=>$client->ID(),
                 service_name=>$service_name,
                 subscribe_date=>$date,
                });
    return 1;
  }
}

sub METHOD_ob_unsubscribe {
  my ($self,$service_name,$subscriber,$date) = @_;
  my $client = client()->Load($subscriber)
    || die "No such client $subscriber";
  my $db = db();
  my $s = $db->SuperSelectAndFetch('select * from subscribes where client_id=? and service_name=?',
                                   $client->ID(),
                                   $service_name);
  die "Client ($subscriber) is not subscribed"
    unless $s;
  if ($s->{is_subscribed}) {
    $db->Query('update subscribes set is_subscribed=0, unsubscribe_date=? where client_id=? and service_name=?',
               $date,
               $client->ID(),
               $service_name);
    return 1;
  } else {
    print STDERR "$service_name: Client ($subscriber) is already unsubscribed ad $s->{unsubscribe_date}\n";
    return 2;
  }
}

sub METHOD_ob_charges {
  my ($self,$service_name,$charges) = @_;
  my $db = db();
  my $p = period()->GetOpenList();
  my %periods;
  foreach (@$p) {
    $periods{$_->Data('start')}=$_;
  }
  my @success;
  my @errors;
  foreach my $charge (@$charges) {
    my $client = client()->Load($charge->{acs_account});
    unless ($client) {
      push @errors,{charge=>$charge,
                    error=>"No such client $charge->{acs_account}"};
      next;
    }
    my $client_id = $client->ID();
    my $s = $db->SuperSelectAndFetch('select * from subscribes where client_id=? and service_name=?',
                                     $client_id,
                                     $service_name);
    unless ($s) {
      push @errors,{charge=>$charge,
                    error=>"Client ($client_id) is not subscribed to service '$service_name'"};
      next;
    }

    my $service_charge=''; # TODO Dump всей charge

    my $period = $periods{$charge->{month}};
    my $period_id = $period->ID();
    my $res = $db->
      SuperSelectAndFetch("select * from subscriber_charge where period_id=? and client_id=? and service_name=?",
                          $period_id,$client_id,$service_name);
    my $is_closed = $charge->{closed_month} ? 1 : 0;
    if ($res) {
      if ($res->{is_closed}) {
        push @errors,{charge=>$charge,
                      error=>"Попытка внешнего съёма в закрытом периоде $charge->{month}, $client_id"};
        next;
      } else {
        $db->Query('update subscriber_charge set timestamp=now(), summa=?, service_charge=?, is_closed=? where id=?',
                   $charge->{summa},
                   $service_charge,
                   $is_closed,
                   $res->{id});
      }
    } else {
      $db->Insert('subscriber_charge',
                  {client_id=>$client_id,
                   period_id=>$period_id,
                   service_name=>$service_name,
                   is_closed=>$is_closed,
                   summa=>$charge->{summa},
                   service_charge=>$service_charge,
                  });
    }
    $client->MakeCharge($period,{});
    push @success,$charge;
  }
  return {success=>\@success,
          errors=>\@errors};
}

1;
