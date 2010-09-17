package openbill::Server::IPTraff;
use strict;
use dpl::Error;
use dpl::Db::Database;
use dpl::Db::Filter;
use openbill::Server::BaseDb;
use openbill::Period;
use openbill::IPTraff;
use openbill::Utils;
use openbill::Collector::LogShot;
use Exporter;
use vars qw(@ISA);
@ISA = qw(Exporter
          openbill::Server::BaseDb);

openbill::Server::Base::addSOAPObject(iptraff=>'openbill::Server::IPTraff');


sub METHOD_get_virus_log {
  my ($self,$date) = @_;
  return db()->
    SuperSelectAndFetchAll('select inet_ntoa(ip) as ip, port, sum(bytes) as bytes, sum(records) as records, sum(packets) as packets  from viruslog where date=? group by ip, port order by bytes',
                           filter('date')->ToSQL($date));
}

sub METHOD_list_log_shots {
  my ($class,$p)=@_;
  return openbill::Collector::LogShot->List($p);
}

sub METHOD_get_log_shot {
  my ($class,$p) = @_;
  my $l = openbill::Collector::LogShot::logshot($p);
  return $l->Data();
}

sub METHOD_traffic {
  my ($self,$id,$where,$group) = (shift,shift,shift,shift);
  $where={} unless $where;
  if (exists $where->{period}) {
    my $period = period()->LoadByDate($where->{period}) || fatal("Нет такого периода");
    $where->{from_date} = $period->Data('start');
    $where->{to_date} = $period->Data('start');
    delete $where->{period};
  }
  foreach (qw(date from_date to_date)) {
    if (exists $where->{$_} && !ref($where->{$_})) {
      $where->{$_}=ParseDate($where->{$_}) || fatal("Неверная дата ($where->{$_})");
    }
  }
  return iptraff()->GetTraffic($where,$group);
}

sub METHOD_updateTraffic {
  my ($self,$max) = @_;
  iptraff()->UpdateTraffic($max);
  return 1;
}

sub METHOD_deleteTraffic {
  my ($self,$p) = @_;
  return iptraff()->DeleteTraffic($p);
}


sub METHOD_checkDatabase {
  my ($self) = @_;
  return iptraff()->CheckDatabase();
}

sub METHOD_checkTraffic {
  my ($self,$p) = @_;
  return iptraff()->CheckTraffic($p);
}




1;
