package openbill::Server::Client;
use strict;
use dpl::System;
use dpl::Error;
use locale;
use Data::Dumper;
use dpl::Log;
use dpl::Db::Filter;
use dpl::Db::Table;
use dpl::Db::Database;
use openbill::Server::BaseDb;
use openbill::Client;
use openbill::Utils;
use openbill::Tariff;
use openbill::Period;
use openbill::Payment;
use Data::Serializer;
use dpl::Context;
use Exporter;
use vars qw(@ISA);
@ISA = qw(Exporter
          openbill::Server::BaseDb);

openbill::Server::Base::addSOAPObject(client=>'openbill::Server::Client');

sub PrepareParams {
  my ($p) = @_;
  my @p;
  my @bind;
  if (exists $p->{street_id}) {
    $p->{'street.street_id'}=$p->{street_id};  delete $p->{street_id};
  }
  if (exists $p->{street}) {
    push @p,"street.name like ?";
#    $p->{street}=~s/\*/\%/g;
    push @bind,'%'.lc($p->{street}).'%';
    delete $p->{street};
  }
  if (exists $p->{is_firm}) {
    $p->{'client.is_firm'}=$p->{is_firm};  delete $p->{is_firm};
  }
  if (exists $p->{building}) {
    $p->{'building.number'}=$p->{building};  delete $p->{building};
  }
  if (exists $p->{dealer_id}) {
    $p->{delaer_id}=$p->{dealer_id};  delete $p->{delaer_id};
  }
  if (exists $p->{room}) {
    $p->{'address.room'}=$p->{room};  delete $p->{room};
  }
  if (exists $p->{name}) {
    $p->{'client.name'}=$p->{name};  delete $p->{name};
  }
  if (exists $p->{address_id}) {
    $p->{'address.address_id'}=$p->{address_id};  delete $p->{address_id};
  }
  if (exists $p->{building_id}) {
    $p->{'building.building_id'}=$p->{building_id};  delete $p->{building_id};
  }
  if (exists $p->{like}) {
    my $like = "%$p->{like}%";
    delete $p->{like};
    my @f=qw(client.name client.firmname client.nick client.email client.telefon client.comment client.inn);
    push @p,{or=>[map {"$_ like ?"} @f]};
    push @bind,map {lc($like)} @f;
  }
  if (exists $p->{is_balance_positive}) {
    if ($p->{is_balance_positive}) {
      push @p,"balance>0";
    } else {
      push @p,"balance<=0";
    }
    delete $p->{is_balance_positive};
  }
  if (exists $p->{reg_date_from} || exists $p->{reg_date_to}) {
    fatal("Надо указывать или reg_date или reg_date_from с reg_date_to")
      if exists $p->{reg_date};
    my @a;
    if (exists $p->{reg_date_from}) {
      push @a,"client.reg_date>=?";
      push @bind,filter('date')->ToSQL($p->{reg_date_from});
      delete $p->{reg_date_from};
    }
    if (exists $p->{reg_date_to}) {
      push @a,"client.reg_date<=?";
      push @bind,filter('date')->ToSQL($p->{reg_date_to});
      delete $p->{reg_date_to};
    }
    push @p,{and=>\@a};
  }
  if (exists $p->{reg_date}) {
    push @p,"client.reg_date=?";
    push @bind,filter('date')->ToSQL($p->{reg_date});
    delete $p->{reg_date};
  }
  if (%$p) {
    foreach (keys %$p) {

      if ($p->{$_}=~/\*/) {
        $p->{$_}=~s/\*/\%/g;
        push @p,"$_ like ?";
        push @bind, lc($p->{$_});
        delete $p->{$_};
      } else {
        push @p,"$_=?";
        push @bind, $p->{$_};
      }
    }
  }

  return \@p,@bind;
}

sub METHOD_list_activations {
  my ($class,$client_id) = @_;
  my $client = client($client_id) || return undef;
  return {client=>$client->DataFull(),
          activations=>$client->GetActivations()};
}

sub METHOD_stats {
  my ($class,$dfrom,$dto) = @_;
  my @bind;
  push @bind,filter('date')->ToSQL($dfrom);
  push @bind,filter('date')->ToSQL($dto);

  my $db = db();

  $db->Connect();
  my $query = qq(SELECT * FROM client
                 WHERE client.is_removed=? and reg_date>=? and reg_date<=?);
  logger('sql')->debug("$query",join(',',@bind));
  my $sth = $db->{dbh}->prepare($query);
  my $rv  = $sth->execute(0,@bind);
  my ($orders,$payed,$clients,$firms);
  while (my $f = $db->Fetch($sth)) {
    $orders+=$f->{order_connection_summ};
    $payed+=$f->{real_connection_summ};
    $clients+=1;
    $firms+=1 if $f->{is_firm};
  }

  my $p=db()->SelectAndFetchOne("select count(*) as count from building where connected>=? and connected<=? and is_connected=1");
#   foreach (@$p) {
#     if ($p->{date_connect}) {
#       my $d = ParseDate($p->{date_connect});
#       db()->Query("update building set connected='$d' where id=$_->{id}");
#     }
#   }
#   db()->Commit();
  return {orders=>$orders,
          clients=>$clients,
          firms=>$firms,
          buildings=>ref($p)=~/HASH/ ? $p->{count} : 0,
          payed=>$payed};
}

sub METHOD_set_night_speed {
  my ($self,$id,$speed) = @_;
  my $client = client($id) || fatal("No such client $id");
  $speed+=0;
  $client->Modify({night_speed=>$speed});
  $client->FreshHosts();
  my $periods = period()->List(today()) || fatal("No periods to recharge");
  my $s;
  foreach my $p (@$periods) {

    $s+=$client->Recharge($p,undef,1);
  }
  return $a;

}

sub METHOD_set_daytime {
  my ($self,$daytime) = @_;
  my $night_mode=0;
  if ($daytime eq 'day') {
  } elsif ($daytime eq 'night') {
    $night_mode=1;
  } else {
    fatal("Unknown daytime '$daytime', must be 'day' or 'night'");
  }
  my $sth = db*->Query("update system_param set value=$night_mode where param='night_mode'");
  my $list = client()->List({and=>['night_speed>0']});
  foreach my $c (@$list) {
#    my $cid = $c->ID();
#    print STDERR "daytime (night_mode=$daytime) client: $cid\n";
    $c->FreshHosts();
  }
}

sub METHOD_statuses {
  my $class = shift;
  return table('client_status')->List();
}

sub METHOD_do_alert {
  my ($class,$id) = @_;
  if ($id) {
    client($id)->DoAlert();
  } else {
    my $query = qq(SELECT client.* FROM client
                   WHERE is_removed=? and do_alert=? and
                   balance<=balance_to_alert
                   and (balance_alerted_time is null OR now()-balance_alerted_time>=86400)
                  );
    logger('sql')->debug($query);
    my $db = db();
    my $sth = $db->{dbh}->prepare($query);
    my $rv  = $sth->execute(0,1);
    my $count = 0;
    while (my $f = $db->Fetch($sth)) {
      client($f->{client_id})->DoAlert();
      $count++;
    }
    return $count;
  }
}

sub METHOD_list {
  my ($class,$where,$order,$start,$limit)=@_;
  $start+=0;
  $limit=$limit+0 || 20;
#  die join(',',%$where);
  my $date;
  $where={} unless $where;
  foreach (keys %$where) {
    delete $where->{$_} if $where->{$_} eq "" && !ref($where);
  }
  if (exists $where->{date}) {
    $date = $where->{date};
    delete $where->{date};
  }
  my $db = db();

  my ($p,@bind) = PrepareParams($where);
  my $w = $db->prepareData($p,'and',\@bind,1);

  $w=" and ($w)"
    if $w;

  my $q=qq(select count(client_id) as max
           from client
           left join address on address.address_id=client.address_id
           left join building on address.building_id=building.building_id
           left join street on building.street_id=street.street_id
           WHERE client.is_removed=? $w);
  $db->Connect();
  logger('sql')->debug("$q",join(',',@bind));
  my $sth = $db->{dbh}->prepare($q);
  my $rv  = $sth->execute(0,@bind);
  my $max = $db->Fetch($sth)->{max};
  fatal("Запрещённые символы в параметре сортировки. Можно только a-z и ,") if $order=~/[^a-z ,]/;
  my $o = $order ? "order by $order" : '';
  my $query = qq(SELECT client.*,
                 address.room as room, address.comment as address_comment, address.building_id as building_id,
                 building.number as building, building.street_id as street_id, bill_delivery.name as bill_delivery,
                 street.name as street, dealer.name as dealer
                 FROM client
                 left join bill_delivery on bill_delivery.id=client.bill_delivery_id
                 left join dealer on dealer.id=client.dealer_id
                 left join address on address.address_id=client.address_id
                 left join building on address.building_id=building.building_id
                 left join street on building.street_id=street.street_id
                 WHERE client.is_removed=? $w $o limit $start,$limit);
  #  $query="$query $extra" if $extra;
  logger('sql')->debug($query,' -values are- ',@bind);
  my $sth = $db->{dbh}->prepare($query);
  my $rv  = $sth->execute(0,@bind);
  my (@list, $services, %periods);
  my $period = $date ? period()->LoadByDate($date) : undef;
  while (my $f = $db->Fetch($sth)) {
    foreach (qw(reg_date activation_time activation_done balance_changed)) {
      $f->{$_} = filter('date')->FromSQL($f->{$_});
    }
    my $c = client($f->{client_id});
#    $f->{balance_ordered}=$c->GetBalance(1);
    if ($date) {
      $f->{charges}={};
      $f->{charges}->{1}=$c->GetChargeRecord($period)
        if $period;
    }
    push @list,$f;
  }
  return {start=>$start,
          limit=>$limit,
          max=>$max,
          list=>\@list};
  #  $p->{date}||=today();
#  my @a;
#  foreach my $c (@$list) {
#    my $d = $c->DataFull();
#    $d->{charges}={};
#    push @a, $d;
#  }
#  return [\@a,[map {$_->DataFull()} @$services]];
}

sub METHOD_get {
  my ($class,$id) = @_;
  my $client = openbill::Client::client();
  $client->Load($id) || return undef;
  my $data = $client->LoadFull();
  my $tariff = $client->FindCurrentTariff(today());
  if ($tariff) {
    $data->{tariff}=tariff($tariff)->DataFull();
  }
#   my @l=$client->GetTariffesLog($service);
#   foreach (@l) {
#     $_->{tariff}=tariff($_->{tariff_id})->DataFull();
#   }
  #  $data->{tariffes_log}=\@l;
  #  die join(',',%$data);
  return $data;
}

sub METHOD_ext_get_fake {
  my ($class,$id) = @_;
  my $db = db();
  $db->Connect();
  my $query =
    qq(SELECT client.*,
       address.room as room, address.comment as address_comment,
       building.number as building, building.street_id as street_id,
       street.name as street FROM client
       left join address on address.address_id=client.address_id
       left join building on address.building_id=building.building_id
       left join street on building.street_id=street.street_id
       WHERE client.client_id=?);

  my $sth = $db->{dbh}->prepare($query);
  my $rv  = $sth->execute($id);
  my $f = $db->FetchOne($sth);
  return undef unless $f;
  foreach (qw(reg_date activation_time activation_done balance_changed)) {
    $f->{$_} = filter('date')->FromSQL($f->{$_});
  }
  if ($f->{is_firm}) {
    $f->{client} =  "$f->{firmname} ($f->{name})";
  } else {
    $f->{client} =  $f->{firmname} ? "$f->{name} ($f->{firmname})" : $f->{name};
  }
  $f->{address}="$f->{street}, $f->{building}, $f->{room}";
  $f->{address}.=" ($f->{address_comment})"
    if $f->{address_comment};
  return $f;
}

sub METHOD_recharge {
  my ($class,$id) = @_;
  my $client = client($id) || fatal("No such client $id");
  my $periods = period()->List(today()) || fatal("No periods to recharge");
  my $c='no one';
  foreach my $p (@$periods) {
    $client->Recharge($p,undef,1);
    $c++;
  }
  return $c;
}

sub METHOD_modify_limited {
  my ($class,$id,$data) = @_;
  my $client = client($id);
  $data = $class->LimitFieldsClient($data);
  return $client->Modify($data);
}

sub METHOD_check_link {
  my ($class,$id) = @_;
  my $client = openbill::Client::client($id) || return undef;
  return $client->CheckLink();
}


sub METHOD_check_balance {
  my ($class,$id) = @_;
  my $client = openbill::Client::client($id) || return undef;
  return $client->CheckBalance();
}

sub METHOD_check_act {
  my ($class,$id,$from_month,$to_month) = @_;
  my $client = openbill::Client::client($id) || return undef;
  return {client=>$client->DataFull(),
          motions=>$client->CheckAct($from_month,$to_month)};
}

sub METHOD_hosts {
  my ($self,$id,$date)  = @_;
  my $client = client($id);
  my $period = period()->LoadByDate($date || today()) || fatal("Нет такого периода");
  my @h;
  foreach my $h (@{$client->GetHosts($period)}) {
    push @h, $h->DataFull();
  }
  return \@h;
}

sub METHOD_payments {
  my ($self,$id)  = @_;
  my @a;
  foreach (@{client($id)->GetPaymentsLog()}) {
    push @a,$_->Data();
  }
  return \@a;
}

sub METHOD_create {
  my ($self,$data) = @_;
  $data->{manager_id}=context('manager')->ID();
  my $res = client()->Create($data) || return undef;
  return $res->ID();
}

# Поля разрешенные исправлять самому клиента
sub LimitFieldsClient {
  my ($self,$fields) = @_;
  my %new;
  foreach (qw (balance_to_alert alert_email do_alert)) {
    $new{$_}=$fields->{$_}
      if exists $fields->{$_};
    delete $fields->{$_};
  }
  fatal("Не могу изменять эти поля: ".join(',',keys %$fields)) if %$fields;
  return \%new;
}


sub LimitFields {
  my ($self,$fields) = @_;
  my %new;
  foreach (qw (address_id name nick firmname inn is_firm telefon
               balance old_balance
               payment_method_id bill_delivery_id
               unpayed_days_to_off balance_to_alert unpayed_days_to_alert balance_to_off
               alert_email do_alert
               order_connection_summ status_id connection_credit has_connection_credit
               deactivation_type statuses
               email reg_date new_contract_date
               months
               can_deactivate start_balance minimal_balance comment
	       is_good_month good_month_cnt
              )) {
    #real_connection_summ
    $new{$_}=$fields->{$_}
      if exists $fields->{$_};
    delete $fields->{$_};
  }
  fatal("Не могу изменять эти поля: ".join(',',keys %$fields)) if %$fields;
  return \%new;
}

sub METHOD_modify {
  my ($self,$id,$data) = @_;
  my $client = client($id);
  $data = $self->LimitFields($data);
#  die Dumper($data);
  my $res = $client->Modify($data);
  $client->RestoreBalance() if exists $data->{start_balance};
  return $res;
}

sub METHOD_delete {
  my ($self,$id) = @_;
  return client($id)->Delete();
}

sub METHOD_makePayment {
  my ($self,$data) = @_;
  my $client = client();
  $client->Load($data->{client_id}) || fatal("No such client $data->{client_id}");
  delete $data->{client_id};
  return $client->MakePayment($data);
}

sub METHOD_find {
  my ($self,$client) = @_;
  my $c = client()->Find($client);
  return ref($c) ? $c->DataFull() : $c;
}

sub METHOD_send_mail {
  my ($self,$client,$templ,$data,$options) = @_;
  my $mt=$options->{message_type}?$options->{message_type}:{2};
  if ($client eq 'all') {
    my $from_client_id=$options->{from_client_id}?$options->{from_client_id}:{1};
    print STDERR "Рассылка всем абонентам письма по шаблону $templ начиная с клиента #$from_client_id\n";
    my @c = client()->List();
    foreach my $c (@c) {
      if ( $c->Data('client_id') >= $from_client_id) {
      	print "Рассылаю письмо по шаблону $templ клиенту ", $c->string(), "\n";
      	$c->SendMail($templ,$data,$mt,$options);
      }
    }
    return scalar @c;
  } else {
    my $c = client()->Find($client) || fatal("Нет такого клиента");
    print "Рассылаю $templ клиенту", $c->string(), "\n";
    fatal("Таких клиентов больше одного: $c") unless ref($c);
    return $c->SendMail($templ,$data,$mt,$options);
  }
}


sub METHOD_activate {
  my ($self,$client,$date,$comment,$force_if_closed) = @_;
  my $c = client()->Find($client) || fatal("Нет такого клиента");
  fatal("Таких клиентов больше одного: $c") unless ref($c);
  return $c->ChangeActivation(1,$date,$comment,0,$force_if_closed);
}

sub METHOD_deactivate {
  my ($self,$client,$date,$comment,$type,$force_if_closed) = @_;
  my $c = client()->Find($client) || fatal("Нет такого клиента");
  fatal("Таких клиентов больше одного: $c") unless ref($c);
  return $c->ChangeActivation(0,$date,$comment,$type,$force_if_closed);
}

sub METHOD_hasPaymentsOfType {
  my ($self,$id,$type)=@_;
  my $list = payment()->List({client_id=>$id,
                              type=>$type});
  return $list && @$list,
}

sub METHOD_getChargeRecord {
  my ($self,$cid,$pid)=@_;
  my $period;
  if ($pid) {
    $period = period($pid)  || fatal("Нет такого периода");
  } else {
    $period = period()->LoadByDate(today()) || fatal("Нет такого периода");
  }
  my $client = client($cid) || fatal("Нет такого клиента");
  my $charge = $client->GetChargeRecord($period) || return undef;
  $charge->{tariff}=tariff($charge->{tariff_id})->string();
  $charge->{period}=$period->string();
  $charge->{currency}=$client->GetCurrency();
  return $charge;
}

sub METHOD_modifyChargeRecord {
  my ($self,$cid,$pid,$data,$force)=@_;
  my $period = period($pid)  || fatal("Нет такого периода");
  my $client = client($cid) || fatal("Нет такого клиента");
  my $res = $client->ModifyChargeRecord($period,$data);
  $client->RestoreBalance();
  return $res;
#  $charge->{tariff}=tariff($charge->{tariff_id})->string();
#  $charge->{period}=$period->string();
#  $charge->{currency}=$client->GetCurrency();
#  return $charge;
}


sub METHOD_getBalance {
  my ($self,$cid,$date) = @_;
  return client($cid)->GetBalance($date);
}

sub METHOD_getBalance2006 {
  my ($self,$cid,$is_firm) = @_;
  my $p=db()->SelectAndFetchOne("select sum(summa) as summa from payment where client_id=$cid and type=1 and date>='2006-01-01'");
  my $c=db()->SelectAndFetchOne("select sum(summa) as summa from charge where client_id=$cid and period_id>=39");
  my $summa = filter('numeric')->FromSQL($p->{summa})-filter('numeric')->FromSQL($c->{summa});
  $summa=$summa*1.18
    if $is_firm;
  return $summa;
}


sub METHOD_getStartBalance {
  my ($self,$cid,$is_firm) = @_;
  my $p=db()->SelectAndFetchOne("select sum(summa) as summa from payment where client_id=$cid and type=1 and date<'2006-01-01'");
  my $c=db()->SelectAndFetchOne("select sum(summa) as summa from charge where client_id=$cid and period_id<39");
  my $summa = filter('numeric')->FromSQL($p->{summa})-filter('numeric')->FromSQL($c->{summa});
  $summa=$summa*1.18
    if $is_firm;
  return $summa;
}


sub METHOD_restore_balance {
  my ($self,$client) = @_;
  if ($client) {
    return client($client)->Load()->RestoreBalance();
  } else {
    my $list = client()->List();
    foreach my $c (@$list) {
      $c->RestoreBalance();
    }
  }
}

sub METHOD_change_tariff {
  my ($self,$p) = @_;
  $p->{date}=ParseMonth('today') unless $p->{date};
  $p->{date}=ParseMonth($p->{date}) || fatal("Не указан date");
  my $c = client()->Load($p->{client_id}) || fatal("Нет такого клиента");
  fatal("Таких клиентов больше одного: $c") unless ref($c);
  my $t = tariff()->Find($p->{tariff_id}) || fatal('Нет такого тарифа');
  fatal("Таких тарифов больше одного: $t") unless ref($t);
  return $c->ChangeTariff(context('manager'),$t,$p->{date},$p->{comment},$p->{force});

}

sub METHOD_future_tariff {
  my ($self, $cid) = @_;
  my $date = filter('date')->ToSQL(today());
  my $o = db()->
    SelectAndFetchOne(qq(select * from tariff_log
                         where client_id=$cid and service_id=1
                         and from_ym<='$date' order by from_ym desc limit 1));

  $date = filter('date')->ToSQL(today()->NextMonth());
  my $a = db()->
    SelectAndFetchOne(qq(select * from tariff_log
                         where client_id=$cid and service_id=1
                         and from_ym>='$date' order by from_ym desc limit 1));
  my $t = $a || $o;
  return $t ? tariff($t->{tariff_id})->DataFull() : undef;
}



sub METHOD_make_invoice {
  my ($self,$id) = (shift,shift);
  my $client = client($id);
  my $invoice = $client->MakeInvoice(@_);
}

sub METHOD_payments {
  my ($class,$cid,$p)=@_;
  return client($cid)->GetPaymentsLog();
}

sub METHOD_charges {
  my ($self,$cid,$p) = @_;
  $p={} unless $p;
  return client($cid)->GetChargesLog()
    if $cid;

  if (exists $p->{month}) {
    my $clients = client()->List();
    my $period = period()->LoadByDate($p->{month})
      || die "No such period $p->{month}";
    my $temp = tariff()->List();
    my %tariff;
    foreach (@$temp) {
      $tariff{$_->ID()}=$_->DataFull();
    }
    my @client_fields = qw(name firmname is_firm reg_date balance is_active deactivation_type activation_time is_removed status_id real_connection_summ inn payment_method_id is_good_month good_month_cnt);
    my $f = join(',',map {"client.$_ as client_$_"} @client_fields);
    my $db = db();
    my $sth = $db->Query(qq(select charge.*, $f,
address.room as address_room, address.building_id as address_building_id, building.number as address_building, building.street_id as address_street_id, street.name as address_street
from charge
left join client on client.client_id=charge.client_id
left join address on address.address_id=client.address_id
left join building on address.building_id=building.building_id
left join street on building.street_id=street.street_id
where period_id=? order by client_id),
                         $period->ID());
    
    my $s = Data::Serializer->new(portable=>0,serializer=>'Data::Dumper',compress=>0);
    my @charges;
    while (my $c = $db->Fetch($sth)) {
      next if $c->{client_is_removed};
      if (exists $p->{is_firm}) {
        next if $p->{is_firm}!=$c->{client_is_firm};
      }
#      die join(',', keys %$c);
      if (exists $p->{payment_method_id}) {
        print STDERR "У клиента $c->{client_id} не установлен payment_method_id\n"
          unless $c->{client_payment_method_id};
        next unless $p->{payment_method_id}==$c->{client_payment_method_id};
      }

      my @k = grep {!/client_id/ && s/^client_//} keys %$c;
      $c->{client}={};
      foreach (@k) {
        $c->{client}->{$_}=$c->{"client_$_"};
        delete $c->{"client_$_"};
      }
      $c->{address}={};
      @k = grep {s/address_//} keys %$c;
      foreach (@k) {
        $c->{address}->{$_}=$c->{"address_$_"};
        delete $c->{"address_$_"};
      }
      $c->{traffic}=$s->deserialize($c->{traffic});
      $c->{tariff}=$tariff{$c->{tariff_id}};
      push @charges,$c;
    }
    return \@charges;
  } else {
    die 'not implemented';
  }
}


sub METHOD_ext_find {
  my ($self,$where,$start,$limit) = @_;

  $where={} unless $where;  foreach (keys %$where) { delete $where->{$_} if $where->{$_} eq "";  }

  my (@p,@bind);
  if (exists $where->{like}) {
    if ($where->{like}=~/^\#(\d+)$/) {
      push @p,'client_id=?';
      push @bind,$1;
    } else {
      foreach (split(/\s+/,$where->{like})) {
        my ($p,@b) = PrepareParams_ext($_);
        push @p,$p;
        push @bind,@b;
      }
    }
    delete $where->{like};
  }
  my $db=db();

#   if (exists $where->{date}) {
#     $date = $where->{date};
#     delete $where->{date};
#   }
  if (exists $where->{balance_comp} || $where->{balance_to_comp}) {

    if ($where->{balance_comp}==1) {
      push @p,"balance>=?";
      push @bind,filter('numeric')->FromSQL($where->{balance_to_comp});
    } elsif ($where->{balance_comp}==-1) {
      push @p,"balance<=?";
      push @bind,filter('numeric')->FromSQL($where->{balance_to_comp});
    }
    delete $where->{balance_comp};
    delete $where->{balance_to_comp};
  }

  if (exists $where->{credit} || exists $where->{credit_status}) {
    $where->{credit}=-$where->{credit}
      if $where->{credit}>0;
    if ($where->{credit_status} eq 'more') {
      push @p,"minimal_balance<?";
      push @bind,filter('numeric')->FromSQL($where->{credit});
    } elsif ($where->{credit_status} eq 'no') {
      push @p,"minimal_balance>=0";
    }
  }
  delete $where->{credit_status};
  delete $where->{credit};
  # Оплачено полностью
  if ($where->{connection_payment}==1) {
    push @p,'order_connection_summ<=real_connection_summ';

    # Не оплачено полностью
  } elsif ($where->{connection_payment}==2) {
    push @p,'order_connection_summ>real_connection_summ';
    # Более, чем
  } elsif ($where->{connection_payment}==3) {
    push @p,'real_connection_summ>?';
    $where->{connection_payment_summ}+=0;
    push @bind,$where->{connection_payment_summ};

    # Менее, чем
  } elsif ($where->{connection_payment}==4) {
    push @p,'real_connection_summ<?';
    $where->{connection_payment_summ}+=0;
    push @bind,$where->{connection_payment_summ};

    # Имеет непогашенный кредит
  } elsif ($where->{connection_payment}==5) {
    push @p,'order_connection_summ>real_connection_summ and has_connection_credit=1';
  }

  delete $where->{connection_payment};
  delete $where->{connection_payment_summ};

  if ($where->{activation_from} && exists $where->{is_active}) {
    push @p,'activation_time>=?';
    push @bind,$where->{activation_from};
  }
  delete $where->{activation_from};

  if (keys %$where) {
    my ($pp,@b) = PrepareParams($where);
    push @p,@$pp;
    push @bind,@b;
  }

  $start=0 unless $start;
  $limit=99999 if $limit eq 'all';
  $limit=20 unless $limit;
  my $w = @p ? $db->prepareData(\@p,'and',\@bind,1) : '';
  $w=" and $w" if $w;
  my $q=qq(select count(client_id) as max from client
           left join address on address.address_id=client.address_id
           left join building on address.building_id=building.building_id
           left join street on building.street_id=street.street_id
           WHERE client.is_removed=0);
  $db->Connect();

  $q.=" $w" if $w;
  logger('sql')->debug($q,' -values are- ',@bind);
  my $sth = $db->{dbh}->prepare($q);
  my $rv  = $sth->execute(@bind);
  my $max = $db->Fetch($sth)->{max};
  my $query =
    qq(SELECT client.*,
       address.room as room, address.comment as address_comment,
       building.number as building, building.street_id as street_id,
       street.name as street FROM client
       left join address on address.address_id=client.address_id
       left join building on address.building_id=building.building_id
       left join street on building.street_id=street.street_id
       WHERE client.is_removed=0 $w limit $start,$limit);
  #  $query="$query $extra" if $extra;

  my $sth = $db->{dbh}->prepare($query);
  my $rv  = $sth->execute(@bind);
  my @list;
  while (my $f = $db->Fetch($sth)) {
    foreach (qw(activation_time activation_done balance_changed)) {
      $f->{$_} = filter('datetime')->FromSQL($f->{$_});
    }
    $f->{reg_date} = filter('date')->FromSQL($f->{reg_date});
    if ($f->{is_firm}) {
      $f->{client} =  "$f->{firmname} ($f->{name})";
    } else {
      $f->{client} =  $f->{firmname} ? "$f->{name} ($f->{firmname})" : $f->{name};
    }
    $f->{address}="$f->{street}, $f->{building}";
    $f->{address}.=", кв. $f->{room}"
      if $f->{room};
    $f->{address}.=" ($f->{address_comment})"
      if $f->{address_comment};
    push @list,$f;
  }
  return {start=>$start,
          limit=>$limit,
          max=>$max,
          list=>\@list};
}


sub PrepareParams_ext {
  my $like = lc(shift);
  my @bind;
  #  $like =~s/\*/%/g;;
  $like="%$like%"
    unless $like=~/^\d+$/;
  my @f=qw(building.number address.room client.name client.firmname client.nick client.email street.name client.telefon client.comment client.inn);
  my @p = map {"$_ like ?"} @f;
  push @bind, map {$like} @f;
#  push @p, map {"$_=?"} @f;
#  push @bind, map {$like} @f;
#}
  return {or=>\@p},@bind;
}


1;
