package openbill::Client;
use Template;
use Data::Dumper;
use Template::Filters;
use strict;
use Error qw(:try);
use dpl::Db::Filter;
use dpl::Db::Table;
use dpl::Db::Database;
use dpl::Log;
use dpl::Error;
use dpl::Config;
use openbill::Manager;
use dpl::Context;
use dpl::System;
use dpl::XML;
use Number::Format qw(:subs);
use openbill::Locker;
use openbill::Tariff;
use openbill::IPTraff;
use openbill::Period;
use openbill::Payment;
use openbill::Host;
use openbill::Base;
use openbill::Address;
use openbill::Utils;
use openbill::System;
use openbill::Sendmail;
use Data::Dumper;
use Exporter;
use vars qw(@ISA
            @EXPORT
	    %LOYAL_PROGRAMME_ERRCODES
	    );

use lib qw(/home/danil/projects/oriopay.client/lib/);
use oriopay::Client;

@ISA=qw(Exporter
        openbill::Base);

@EXPORT=qw(client);

%LOYAL_PROGRAMME_ERRCODES=(
      "100"=>"да (установлено вручную)",
      "1"=>"да",
      "-3"=>"нет (лимитированный тариф)",
      "-4"=>"нет (несвоевременная оплата)",
      "-6"=>"нет (превышение порогового трафика)",
      "-7"=>"нет (юр. лицо)",
      "-8"=>"нет (тарифные опции 300/200)",
      "-9"=>"нет (отрицательный баланс/отключение)",
      "-10"=>"нет (отрицательный баланс)",
      "-100"=>"нет (установлено вручную)"
    );

sub DataFull {
  my ($self,$key) = @_;
  $self->Load() unless $self->isLoaded();
  $self->makeFull();
  return $key ? $self->{data}->{$key} : $self->{data};
}

sub makeFull {
  my $self = shift;
  unless (exists $self->{data}->{bill_delivery}) {
    my $id=$self->{data}->{bill_delivery_id};
    $self->{data}->{bill_delivery}=table('bill_delivery')->Load($id)->{name}
      if $id;
  }
  $self->{data}->{host_speed}=$self->{host_speed};
  $self->{data}->{address}||=$self->GetAddress()->string();
  $self->{data}->{street}||=$self->GetAddress()->{street};
  $self->{data}->{building}||=$self->GetAddress()->building()->Data('number');
  $self->{data}->{room}||=$self->GetAddress()->{room};
  $self->{data}->{contact_email}||=$self->GetContactEmail();
  $self->{data}->{contact_name}||=$self->Data('name');
  $self->{data}->{emails}||=$self->GetEmails();
  $self->{data}->{client}||=$self->string();
  $self->{data}->{currency}||=$self->GetCurrency();
  $self->{data}->{is_good_month_str}||=$self->IsGoodMonthStr();
  $self->{data}->{bonus_speed}||=$self->LoyaltyBonus();
  $self->{data}->{manager}=$self->{data}->{manager_id} ? manager($self->{data}->{manager_id})->DataFull() : 'НЕИЗВЕСТНО';
  $self->{data}->{dealer}||=table('dealer')->Load($self->Data('dealer_id'))
    if $self->Data('dealer_id');
  $self->{data}->{payment_method}||=table('payment_method')->Load($self->Data('payment_method_id'))->{name}
    if $self->Data('payment_method_id');
  # $self->{data}->{bill_delivery}||=table('bill_delivery')->Load($self->Data('bill_delivery_id'))
#    if $self->Data('bill_delivery_id');

}


sub FreshHosts {
  my $self = shift;
  my $hosts = $self->GetHosts();
  foreach my $h (@$hosts) {
    my $hid = $h->ID();
#    print "host: $hid\n";
    $h->Modify({am_time=>undef});
  }

}

sub Modify {
  my ($self,$data) = @_;
  if (exists $data->{payment_method_id} && !$data->{payment_method_id}) {
    fatal("payment_method_id is no set for client $self->{id}");
  }
  if (exists $data->{deactivation_type} && !$data->{is_active}) {
    my $l = table('activation_log')->List({client_id=>$self->{id}});
    if (@$l) {
      my $a = pop @$l;
      table('activation_log')->Modify({type=>$data->{deactivation_type}},
                                      {client_id=>$a->{client_id},
                                       manager_id=>context('manager')->ID(),
                                       is_active=>$a->{is_active},
                                       date=>$a->{date}})
        unless $a->{is_active};
    }
  }
  return $self->SUPER::Modify($data);
}

sub GetContactEmail {
  my $self = shift;
  my $e = $self->GetEmails();
  return undef unless @$e;
  return $e->[0];
}

sub DoAlert {
  my $self = shift;
#  die $self->ID();
  my $balance = $self->Data('balance');
  if ($balance<=$self->Data('balance_to_alert')) {
    print STDERR "Оповещаю клиента ".$self->string()." что его баланс мал ($balance,".$self->Data('balance_to_alert').")\n";
    $self->SendMail('balance_alert',20);
    $self->Modify({balance_alerted_time=>today()});
    db()->Commit();
    return 1;
  } else {
    return 0;
  }

}

sub GetEmails {
  my $self = shift;
#  return $self->Data('email');
  return [split(/[ ;,]+/,$self->Data('alert_email'))];
}

sub GetReallyAllEmails {
  my $self = shift;
#  return $self->Data('email');
  return [split(/[ ;,]+/,$self->Data('email'))];
}

sub GetPhones {
  my $self = shift;
  return [split(/[ ;,]+/,$self->Data('telefone'))];
}


sub GetName {
  my $self = shift;
  my $d = $self->Data();
  return $d->{is_firm} ? $d->{firmname} : $d->{name};
}

sub client {
  return openbill::Client->instance('client',@_);
}

sub GenerateNick {
  my ($self) = @_;
  my $res = db()->SelectAndFetchOne('select max(client_id) as max from client');
  return 'nonick' unless $res;
  $res->{max}++;
  return "nonick$res->{max}";
}

sub string {
  my $self =shift;
  my $d = $self->Data();
  return  "$d->{firmname} ($d->{name})" if $d->{is_firm};
  return $d->{firmname} ? "$d->{name} ($d->{firmname})" : $d->{name};
}

sub Create  {
  my ($self,$data) = @_;
  $self->checkParams($data,'name','address_id','telefon','payment_method_id');
  $self->checkParams($data,'firmname')
    if $data->{is_firm};
  $data->{nick}||=$self->GenerateNick();

  $data->{reg_date}=today() unless $data->{reg_date};
  $data->{new_contract_date}=$data->{reg_date};
  $data->{payed_to_date}=$data->{reg_date};
  $data->{balance_changed}=today() unless $data->{balance_changed};
  my $res = $self->SUPER::Create($data);
  return undef unless $res;
  notify('create_client',{client=>$self->DataFull()});
  notify('create_client_sms',{client=>$self->DataFull()});
  return $res;
}

sub Delete { fatal("Нельзя удалять клиентов"); }

sub GetRegDate {
  my $self = shift;
  my $d = $self->Data('reg_date');
  return $d ? $d->TimeFormat('%e %B %Y') : 'неуказано';
}

sub GetAddress {
  my $self = shift;
#  print STDERR "address ".$self->Data('address_id')."\n";
  return address($self->Data('address_id'));
}


sub GetActivations {
  my ($self) = @_;
  my %h=(client_id=>$self->ID());
  return table('activation_log')->List(\%h);
}

sub List {
  my ($self,$where,$order,$extra) = @_;
  if ($where) {
    $where->{is_removed}=0;
  } else {
    $where={is_removed=>0};
  }
  my $list = $self->{table}->List($where,$order,$extra);
  my @l;
  my $module = ref($self);
  foreach (@$list) {
    push @l, $module->instance($self->{name},
                               $_->{$self->{idname}},
                               $_);
  }
  return wantarray ? @l : \@l;
}


# Возвращает скорость растраты денежных средств в день

sub GetSpendSpeed {
  my $self=@_;
  return 30;
}

sub LastMessageDays {
  my ($self,$mt) = @_;
  $mt+=0;
  my $cid = $self->ID();
  my $res = db()->SelectAndFetchOne("select max(datetime) as datetime from message_log where client_id=$cid and message_type=$mt");
  my $date = filter('datetime')->FromSQL($res->{datetime});
  return 999999 unless $date;
  my $delta = today()-$date;
  my $days = round($delta->Seconds()/(24*60*60),0);
#  logger()->debug("Дата последнего письма (cid:$cid) типа [$mt] ".$date." сегодя ".today()." прошло дней $days");
  $days=0 if $days<0;
  return $days;
}

sub DaysToWork {
  my $self = shift;
  return round($self->GetBalance()/$self->GetSpendSpeed(),0);
}

sub CheckAct {
  my ($self,$from_date,$to_date) = @_;
  my $charges = $self->GetChargesLog($from_date);
  # TODO Не считаются оплаты если они произошли в периода без charge
  my $last_date=$from_date;
  my @motions;
  foreach my $c (reverse @$charges) {

    my $period = openbill::Period::period($c->{period_id});
    next if $from_date && $from_date>$period->Data('start');
    my $payments = $self->GetPaymentsLog($last_date,$period->Data('end'));
    my @p;
    foreach (@$payments) {
      push @p,$_ if $_->{type}==1 || $_->{type}==-1;
    }
    $last_date=$period->Data('end')+60*60*24;
    push @motions,{payments=>[reverse @p]};
    push @motions,{charge=>$c};
  }
  $last_date=$from_date if $from_date && $from_date>$last_date;
  my $payments = $self->GetPaymentsLog($last_date);
  push @motions, {payments=>$payments};
  return \@motions;
}

sub SetCredit {
  my ($self,$p) = @_;

}

sub CheckBalance {
  my ($self,$params) = @_;
  my $days = $self->Data('send_alert_days');
  return -1 unless $self->Data('is_active');
  return -2 unless $self->Data('can_deactivate');

  #Не деактивируем никого во время праздников
  #return -2;

  my $balance = $self->GetBalance();

  unless ($self->Data('new_balance_method')) {
    if ($balance<$self->Data('minimal_balance')) {
      $self->ChangeActivation(0,today(),'Отрицательный баланс',1);
      return 0;
    }
    return 1;
  }
  #
  my $credit = $self->Data('credit_timestamp');
  if ($credit) {
    if ($balance<($self->Data('credit_balance'))) {
      $self->ChangeActivation(0,today(),'Превышен лимит кредита ('.$self->Data('credit_summ').')',4);
      return 2;
    } elsif (today()>($credit+$self->Data('credit_days')*24*60*60)) {
      $self->ChangeActivation(0,today(),'Превышен период кредита ('.$self->Data('credit_days').') дн.',5);
      return 2;
    }
  } else {
    if ($balance<$self->Data('balance_to_off')) {
      $self->ChangeActivation(0,today(),'Баланс меньше разрешённого ('.$self->Data('balance_to_off').')',1);
      return 1;
    }
    if ($self->Data('is_firm')) {
      if (($self->Data('payed_to_date')+$self->Data('unpayed_days_to_off')*24*60*60)>today()) {
        $self->ChangeActivation(0,today(),'Нет оплаты более '.$self->Data('unpayed_days_to_off').' дн.',6);
        return 3;
      }
#       if (($self->Data('payed_to_date')+$self->Data('unpayed_days_to_alert')*24*60*60)>today() && !$self->Data('unpayed_days_alerted_time')) {
#         $self->SendMail('unpayed_days',2);
#         $self->Modify({unpayed_days_alerted_time=>today()});
#       }
    }
  }
#   if ($balance<$self->Data('balance_to_alert') && !$self->Data('balance_alerted_time')) {
#     $self->Modify({balance_alerted_time=>today()});
#     $self->SendMail('balance',2);
#     return 0;
#   }
}


# sub getActivationsLog {
#   my ($self,$period) = @_;
# #  my $sid = $period->GetService()->ID();
#   my $cid = $self->ID();
#   my $start = $period->Data('start');
#   my $sql_end = filter('date')->ToSQL($period->Data('end'));
#   #  and (service_id=$sid or service_id is null)
#   my $a = db()->
#     SelectAndFetchAll(qq(select * from activation_log
#                          where date<='$sql_end' and client_id=$cid
#                          order by date desc));
#   my $days=0;
#   my $max = $period->Days()-1;
#   my @c=map {undef} (0..$max);
#   foreach my $l (@$a) {
#     my $date = filter('date')->FromSQL($l->{date});
#     last if defined $c[0];
#     my $day = $date<$start ? 0 : $date->Day()-1;
#     foreach ($day..$max) {
#       next if defined $c[$_];
#       $c[$_]=$l->{is_active} ? 1 : 0;
#       $days++ if $l->{is_active};
#     }
#   }
#   return $days ? \@c : undef;
# }

sub SendMail {
  my ($self,$templ,$mt,$data,$options)=@_;
  # return "";
  fatal("Не указан шаблон") unless $templ;
  $options={} unless $options;
  $mt+=0;
  $data={} unless $data;
  #  if (exists $data->{days} && !$data->{date}) {
  #    $data->{date}=today()+$data->{days}*60*60*24;
  #    $data->{date}->SetLocale('ru_RU.KOI8-R');
  #    $data->{date}->TimeZone('Europe/Moscow'); # TODO time_zone веьде перевезти в конфиг#
  #
  # }

  my $e;
  if ( $options->{use_main_email} != 0 ) {
  	print STDERR "Посылаю письмо на все адреса клиента\n";
  	$e = $self->GetReallyAllEmails();
  }else {
  	print STDERR "Посылаю письмо на е-майл адреса для оповещений клиента\n";
 	$e = $self->GetEmails();
  }
  return logger()->error("No email to send for client ".$self->ID())
    unless $e && @$e;
  foreach my $email (@$e) {
    next if $email eq 'none' || !$email;
    $data->{client}=$self->Data() unless $data->{client};
    $data->{email}=$email;
    $data->{name}=$self->Data('name');
    logger()->info("Посылаю письмо для клиента $self->{data}->{id}, $templ, $mt");
    print STDERR "Посылаю письмо ($templ) для клиента ",$self->string(), " на адрес $email\n";
    sendmail($templ,$data,{message_type=>$mt});
  }
  return scalar @$e;
}


sub GetBalance {
  my ($self,$date) = @_;
  return $self->Data('balance');
  # TODO
  return $date ? $self->GetPayedSumm($date)-$self->GetChargedSumm($date)+$self->Data('start_balance') : $self->Data('balance');
}

sub RestoreBalance {
  my $self = shift;
  my $old_balance = $self->Data('balance');
  my $balance = $self->GetPayedSumm()-$self->GetChargedSumm()+$self->Data('start_balance');
  $self->Modify({balance=>$balance,
                 balance_changed=>today(),
                # payed_to_date=>$self->GetDatePayedTo()
                });
  my $diff = $old_balance-$balance;
  if (abs($diff)>0.01) {
    my $str = "Новый баланс cid:$self->{id} $old_balance  -> $balance ($diff)";
    logger()->warn($str);
  }
  return $diff;
}

sub GetDatePayedTo {
  my ($self,$balance) = @_;
  die 'not implemented';
  my $balance = $self->GetPayedSumm()-$self->GetChargedSumm();
  my $charges = $self->GetChargesList();
  return today() if $balance>0;
  while (@$charges) {
    my $c = shift @$charges;
    #    print STDERR "balance: $balance + $c->{summa}\n";
    $balance+=$c->{summa};
    if ($balance>0) {
      my $period = openbill::Period::period($c->{period_id});
      my $per_day = $c->{summa}/$period->Days();
      my $date=$c->{month}-24*60*60;
      if ($per_day>0) {
        do {
          return $date if $balance-$per_day<0;
          $date=$date+24*60*60;
          $balance-=$per_day;
        } while ($balance>0);
      }
      return $date;
      last;
    }
  }
  return $self->Data("payed_to_date");
}

sub MakePayment {
  my ($self,$p) = @_;
#  fatal("Неверный тип (type) платежа, должно быть 0 или 1")
#    if $p->{type}!=1 && $p->{type}!=0;
  my $method = table('payment_method')->Load($p->{payment_method_id}) ||
    fatal("payment_method ($p->{payment_method_id}) is not found");
  my $payment;
  # ORIOPAY
  if ($p->{payment_method_id}==10) {
    # Берем номинал карты
    $payment =
      payment()->PreCreate({client_id=>$self->ID(),
                            manager_id=>$p->{manager_id} || context('manager')->ID(), # TODO менеджер подставляется для web-интерфейса on
                            secret_comment=>"ORIOPAY:$p->{card}",
                            type=>$p->{type},
                            payment_method_id=>$p->{payment_method_id},
                            date=>today()});

    my $node  = dpl::Config::config()->root()->findnodes('./oriopay/shop_key')->pop();

    my $shop_key = xmlText($node);
    oriopay::Client::InitSOAP('http://soap.oriopay.ru/shop/',
                              'http://localhost:1033/',
                              $shop_key);

    print STDERR Dumper($p);
    my $res = oriopay::Client::ActivateCard($p->{code},
                                            0,
                                            $self->ID(),$p->{client_ip},
                                            $payment->ID(),"type:$p->{type}");

    if ($res && $res->{status} eq 'ok') {
      $p->{summa} = $p->{summa_order} = $res->{order_summa};
      $payment->Modify({balance=>$self->Data('balance'),
                        summa=>$p->{summa},
                        summa_order=>$p->{summa_order},
                        comment=>"$p->{comment}",
                        timestamp=>today()});
    } elsif ($res && $res->{status} eq 'repeat') {
      die "not implemented oriopay statys repeat";
    } else {
      table('payment')->Delete($payment->ID());
      return $res;
    }

  } else {

    $p->{summa} = round($p->{summa_order}*100/(100+$method->{tax}),2)
      unless $p->{summa};
    #  die $p->{manager_id};
    $payment = payment()->Create({client_id=>$self->ID(),
                                  balance=>$self->Data('balance'),
                                  manager_id=>$p->{manager_id} || context('manager')->ID(), # TODO менеджер подставляется для web-интерфейса on
                                  summa=>$p->{summa},
                                  summa_order=>$p->{summa_order},
                                  comment=>"$p->{comment}",
                                  timestamp=>today(),
                                  secret_comment=>"$p->{secret_comment}",
                                  type=>$p->{type},
                                  payment_method_id=>$p->{payment_method_id},
                                  date=>$p->{date}});

  }
  my $ci = $self->ID();

  my $new_balance;
  my %h;

  # абонплата
  if ($p->{type}==1 || $p->{type}==-1) {
    $new_balance=$self->Data('balance')+$p->{summa_order};
    %h=(balance=>$new_balance,
        balance_changed=>today());
    $h{last_positive_balance_time}=today()
      if $new_balance>0;
    #  $h{payed_to_date}=$self->GetDatePayedTo($new_balance);


    # подключение
  } elsif (!$p->{type}) {
    $h{real_connection_summ}=$self->Data('real_connection_summ')+$p->{summa};
  }

  my $b = round($self->Data('balance'),2);
  logger('payment')->info("Payment $payment->{id}. client:$ci manager:$p->{manager_id} summa:$p->{summa}, order:$p->{summa_order} type:$p->{type} method:$p->{payment_method_id}. Balance before: $b");
  $h{balance_alerted_time}=undef;
  $h{unpayed_days_alerted_time}=undef;
  $self->Modify(\%h)
    if $p->{type}<=1;
  db()->Commit();
  notify('make_payment',
         {payment=>$payment->DataFull(),
          manager=>context('manager')->DataFull(),
          client=>$self->DataFull()},
         8);
  if (($p->{type}==1 || $p->{type}==1) && $new_balance>0 && !$self->Data('is_active') && $self->Data('deactivation_type')==1) {
    $self->ChangeActivation(1,today(),'Автоматическое включение при оплате');
  }
  my $data = $payment->DataFull();
  $data->{description}=$data->{type} ? 'Услуги связи' : 'Подключение';
  $data->{description}='Прочее' if $data->{type}>1;
  $data->{client}=$self->string();
  #  $data->{balance}=$new_balance;
  $data->{status}='ok';
  return $data;
}

sub GetChargedSumm_fake {
  my ($self,$date) = @_;
  my $cid = $self->ID();
  if (UNIVERSAL::isa($date,'openbill::DataType::Date')) {
    $date = filter('date')->ToSQL($date);
    my $t=db()->SelectAndFetchOne(qq(select sum(summa) as summa
                                     from charge, period
                                     where period.id=charge.period_id
                                     and client_id=$cid and end<'$date'));
    return filter('numeric')->FromSQL($t->{summa});
  } elsif ($date==1) {
    my $t=db()->SelectAndFetchOne("select sum(summa) as summa from charge where client_id=$cid and summa_order is not null");
    return filter('numeric')->FromSQL($t->{summa});
  } else {
    my $t=db()->SelectAndFetchOne("select sum(summa) as summa from charge where client_id=$cid");
    return filter('numeric')->FromSQL($t->{summa});
  }
}

sub GetChargedSumm {
  my ($self,$date) = @_;
  my $cid = $self->ID();
  die 'unknown parameter' if $date;
  # TODO FIX ORIONET BUG for release
  my $t=db()->SelectAndFetchOne("select sum(summa_order) as summa from charge where client_id=$cid and period_id>=39");
  return filter('numeric')->FromSQL($t->{summa});
}


# Возвращает коэффициент использования месяца (0..1)


sub GetPayedSumm_fake {
  my ($self,$date) = @_;
  my $cid = $self->ID();
  if (UNIVERSAL::isa($date,'openbill::DataType::Date')) {
    $date=filter('date')->ToSQL($date);
    my $t = db()->SelectAndFetchOne(qq(select sum(summa) as summa
                                       from payment where client_id=$cid and
                                       type=1 and date<'$date'));
    return filter('numeric')->FromSQL($t->{summa});
  } elsif ($date==1) {
    my $t=db()->SelectAndFetchOne("select sum(summa) as summa from charge where client_id=$cid and summa_order is not null");
    return filter('numeric')->FromSQL($t->{summa});
  } elsif (ref($date)=~/period/i) {
    my $start=filter('date')->ToSQL($date->Data('start'));
    my $end=filter('date')->ToSQL($date->Data('end'));
    my $t = db()->SelectAndFetchOne(qq(select sum(summa) as summa
                                       from payment where client_id=$cid and
                                       type=1 and date<='$end' and date>='$start'));
    return filter('numeric')->FromSQL($t->{summa});
  } elsif (!$date) {
    my $t=db()->SelectAndFetchOne("select sum(summa) as summa from payment where client_id=$cid and (type=1 or type=-1)");
    return filter('numeric')->FromSQL($t->{summa});
  } elsif ($date) {
    $date = filter('date')->ToSQL($date);
    my $t=db()->SelectAndFetchOne("select sum(summa) as summa from payment where client_id=$cid and (type=1 or type=-1) and date<='$date'");
    return filter('numeric')->FromSQL($t->{summa});
  } else {
    fatal("internal error ($date)");
  }
}

sub GetPayedSumm {
  my ($self,$date) = @_;
  my $cid = $self->ID();
  die "unknown parameter $date" if $date;
  my $t=db()->SelectAndFetchOne("select sum(summa_order) as summa from payment where client_id=$cid and (type=1 or type=-1) and date>='2006-01-01'");
  return filter('numeric')->FromSQL($t->{summa});
}


sub GetCurrency { return 'р.'; }

sub GetChargesList {
  my ($self,$sid) = @_;
  my $cid = $self->ID();
  my $ws  = "and service_id=$sid" if $sid;
  my $list = db()->
    SelectAndFetchAll(qq(select * from charge, period where charge.period_id=period.id
                         and charge.client_id=$cid $ws order by period.start desc));
  my @l;
  foreach (@$list) {
    my $period = openbill::Period::period($_->{period_id});
    my $h = iptraff()->chargetable()->
      FromSQL($_);
    $h->{month} = $period->Data('start');
    push @l, $h;
  }
  return \@l;
}

sub GetChargeRecord {
  my ($self,$period) = @_;
  my $res = iptraff()->chargetable()->
    Load({period_id=>$period->ID(),
          client_id=>$self->ID()});
  return $res && %$res ? $res  : undef;
}

sub ModifyChargeRecord {
  my ($self,$period,$data) = @_;
  my $table = iptraff()->chargetable();

  return $table->Modify($data,{period_id=>$period->ID(),
                               client_id=>$self->ID()})
    if $self->GetChargeRecord($period);
  $data->{period_id}=$period->ID();
  $data->{client_id}=$self->ID();
  return $table->Create($data);
}


sub Recharge {
  my ($self,$period,$tariff,$find_activation,$force_if_closed) = @_;
  fatal("Изменения касаются закрытого периода $period")
    unless $period->IsOpen() || $force_if_closed;
  my $cr = $self->GetChargeRecord($period);
  my $summa;
  my $table = iptraff()->chargetable();
  #  print "cid:".$self->ID()."\n";
  if ($cr) {
#    my $activation = $find_activation ? $period->FindClientsActivation($self) : $cr->{act_log};
    $tariff = tariff($cr->{tariff_id}) unless $tariff;
    my $new_cr = $tariff->NewCharge($period,$cr->{traffic},$self);
    #    die "$new_cr";
    if ($new_cr) {
      $new_cr->{client_id}=$self->ID();
      $table->Modify($new_cr,
                     {period_id=>$period->ID(),
                      client_id=>$self->ID()});
      $summa=$new_cr->{summa_order}-$cr->{summa_order};
      $summa=0 if abs($summa)<0.0000000001;
      logger()->info("С клиента cid:$self->{id} переснято $summa руб");
    } else {
      $table->Delete({period_id=>$period->ID(),
                      client_id=>$self->ID()});
      logger()->warn("С клиента cid:$self->{id} удаляю charge-запись, он не включен и нет трафика");
    }
  } else {
#    my $activation = $period->FindClientsActivation($self);
    $tariff ||= $period->FindClientsTariff($self);
    my $traffic = iptraff()->GetClientsTraffic($period,$self);
    my $new_cr = $tariff->NewCharge($period,$traffic,$self) ||  return  undef;
    if ($new_cr) {
      $new_cr->{client_id}=$self->ID();
      $table->Create($new_cr);
      $summa=$new_cr->{summa_order};
      logger()->info("С клиента cid:$self->{id} снято $summa руб");
    } else {
      logger()->info("С клиента cid:$self->{id} ничего не снято");
    }
  }
  $summa=0 if abs($summa)<0.0000000001;
  if ($summa) {
    $summa=-$summa;
    my $sql_summa  = filter('numeric')->ToSQL($summa);
    $sql_summa="+$sql_summa" if $summa>0;
    db()->Query("update client set balance_changed=now(), balance=balance$sql_summa where client_id=".$self->ID());
    #    die 2;
  }
  $self->CheckBalance();
#  $self->Modify({payed_to_date=>$self->GetDatePayedTo()});
  return $summa;
}

sub LoadFull {
  my ($self,$id) = @_;
  $id=$self->ID()
    unless defined $id;
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
                 where client_id=?);
  my @bind=($id);
  my $db = db();
  logger('sql')->debug($query,' -values are- ',@bind);
  my $sth = $db->{dbh}->prepare($query);
  my $rv  = $sth->execute(@bind);
  my $f = $db->Fetch($sth);
  my $t = table('client');
  $f=$t->FromSQL($f);
  $self->SetData($f);
  $self->SetID($self->Data($self->{idname}));
#  $self->makeFull();
#  $f->{client}||=$self->string();
#  $f->{address}||=$self->string();
#  $f->{currency}||=$self->GetCurrency();

  return $self->DataFull();
}

sub MakeCharge {
  my ($self,$period,$traffic,$is_new_record) = @_;
  my $lock = Locker('client','write',$self->ID());
  # die $service->chargetable();
  my $table = iptraff()->chargetable();
  my $summa;
  if ($is_new_record) {
    my $tariff = $period->FindClientsTariff($self);
#    my $activations = $period->FindClientsActivation($self);
#    my $days = $period->FindDays($activations);
    my $new_cr = $tariff->NewCharge($period,$traffic,$self) || return undef;
    $new_cr->{client_id}=$self->ID();
    $table->Create($new_cr);
    $summa=$new_cr->{summa_order};
  } else {
    my $cr = $self->GetChargeRecord($period);
    if ($cr) {
      my $new_cr = tariff($cr->{tariff_id})->Charge($period,$traffic,$cr,$self);
      $summa=$new_cr->{summa_order}-$cr->{summa_order};
      $summa=0 if abs($summa)<0.000001; # TODO в конфиг это значение
      logger->error("Снимается отрицательная сумма ($cr->{summa_order}-$new_cr->{summa_order}=$summa) с клиента cid:".$self->ID())
        if $summa<0;
      $table->Modify($new_cr,
                     {period_id=>$period->ID(),
                      client_id=>$self->ID()});
    } else {
      my $tariff = $period->FindClientsTariff($self);
#      my $activations = $period->FindClientsActivation($self);
      my $new_cr = $tariff->NewCharge($period,$traffic,$self) || return undef;
      $new_cr->{client_id}=$self->ID();
      $table->Create($new_cr);
      $summa=$new_cr->{summa_order};
    }
  }
  if ($is_new_record==2) {
    $self->RestoreBalance();
  } else {
    my $q;
    # Это сумма списания. то есть сумма на куоторую уменьшается баланс.
    # Если сумма 100, значит из баланса нужно вычесть 100. balance=balance-100
    # А если сумма -100 значит к балансу прибавть. balance=balance+100;
    # Поэтому мы её для удобства перепорачиваем.
    $summa=-$summa;
    my $sql_summa  = filter('numeric')->ToSQL($summa);
    if ($summa<0) {
      $q="update client set balance_changed=now(), balance=balance$sql_summa where client_id=".$self->ID();
    } elsif ($summa>0) {
      $q="update client set balance_changed=now(), balance=balance+$sql_summa where client_id=".$self->ID();
    }
    if ($summa){ db()->Query($q); }
#    print STDERR "q: $q\n";
 #   logger()->error("q: $q");
  }
  logger()->info("С клиента cid:$self->{id} снято $summa руб");
  $self->CheckBalance();
  return $summa;
}

sub ChangeTariff {
  my ($self,$manager,$tariff,$date,$comment,$force_if_closed) = @_;
  my $tid = $self->FindCurrentTariff($date);
  if ($tid==$tariff->ID()) {
    print STDERR "Такой тариф уже установлен\n";
    return undef;
  }
  $tariff->CheckContext($self);
  print STEDRR "change tariff 1\n";
  my $old = tariff($tid);
  my $cid = $self->ID();
  my $lock = Locker('period','write');
  ($date)=PeriodFromDate($date);
  my $date_sql = filter('date')->ToSQL($date);
  db()->Query("delete from tariff_log where client_id=$cid and from_ym>='$date_sql'");
  table('tariff_log')->Create({tariff_id=>$tariff->ID(),
                               manager_id=>$manager->ID(),
                               client_id=>$self->ID(),
                               comment=>"$comment",
                               from_ym=>$date,
                               donetime=>today()});
  print STEDRR "change tariff 2\n";
  my $periods = openbill::Period::period()->List($date);
  if (@$periods) {
    print STEDRR "change tariff 3\n";
    foreach my $p (@$periods) {
      $self->Recharge($p,$tariff,0,$force_if_closed);
    }
  }
  notify('change_tariff',{old=>$tid ? $old->Data() : undef,
                          from_date=>$date,
                          manager=>$manager->DataFull(),
                          new=>$tariff->Data(),
                          client=>$self->DataFull()},5);
  print STEDRR "change tariff 4\n";
  $self->CheckBalance();
  return 1;
}

sub GetCurrentTariff {
  my ($self) = @_;
  my $tariff = $self->FindCurrentTariff(today());
  if ($tariff) {
    return openbill::Tariff::tariff($tariff)
      || logger()->error("Немогу загрузить тариф $tariff");
  } else {
    logger()->error("Нет тарифа для хоста ".$self->ID());
  }
  return undef;
}

sub ChangeActivation {
  my ($self,$is_active,$date,$comment,$type,$force_if_closed) = @_;
  my $cid = $self->ID();
  $date=today() unless $date;
  fatal("Клиенту уже установлена такая активация")
    if $self->Data('is_active')==$is_active;
  my $date_sql = filter('date')->ToSQL($date);
  # TODO А что делать с запрограммированными отключениями?
  db()->Query("delete from activation_log where client_id=$cid and date>='$date_sql'");
  table('activation_log')->Create({client_id=>$self->ID(), is_active=>$is_active,
                                   manager_id=>context('manager')->ID(),
                                   date=>$date, done_time=>today(),
                                   comment=>$comment});
  my %h=(is_active=>$is_active,activation_time=>$date,activation_done=>undef);
  $h{deactivation_type}=$type+0
    unless $is_active;
  $self->Modify(\%h);
  iptraff()->UpdateActivation($self,$is_active,$date,$comment);
  my $periods = openbill::Period::period()->List($date);
  if (@$periods) {
    foreach my $p (@$periods) {
      $self->Recharge($p,undef,1,$force_if_closed);
    }
  }
  if ($is_active) {
    notify("activate_client",{type=>$type,
                              client=>$self->DataFull(),
                              date=>$date,
                              comment=>$comment},4);
    # TODO
    # Зачем проверять баланс если его специально включили?
    #    $self->CheckBalance();
  } else {
    notify("deactivate_client",{type=>$type,
                                client=>$self->DataFull(),
                                date=>$date,
                                comment=>$comment},1);
  }
  return 1;

}

sub FindCurrentTariff {
  my ($self,$date) = @_;
  my $cid = $self->ID();
  my $date = filter('date')->ToSQL($date);
  my $a = db()->
    SelectAndFetchOne(qq(select * from tariff_log
                         where client_id=$cid
                         and from_ym<='$date' order by from_ym desc limit 1));
  return $a && %$a ? $a->{tariff_id} : undef;
}


sub GetTariffesLog {
  my ($self) = @_;
  my %w=();
  $w{client_id}=$self->ID();
  my $list = table('tariff_log')->List(\%w);;
  foreach (@$list) {
    $_->{manager}=manager($_->{manager_id})->DataFull();
  }
  return @$list;
}

sub GetPaymentsLog {
  my ($self,$date_from,$date_to) = @_;
  my $w = {client_id=>$self->ID()};
  if ($date_from || $date_to) {
    my @a;
    push @a,"date>='".filter('date')->ToSQL($date_from)."'"
      if $date_from;
    push @a,"date<='".filter('date')->ToSQL($date_to)."'"
      if $date_to;
    $w->{and}=\@a;
  }
  my $list = openbill::Payment::payment()->List($w);
  my @p;
  foreach (@$list) {
    my $h = $_->DataFull();
    $h->{method}=table('payment_method')->Load($_->Data('payment_method_id'));
    push @p, $h;
  }
  return \@p;
}

sub GetChargesLog {
  my ($self,$from_date) = @_;
  my $charges = $self->GetChargesList();
  my %t;

  foreach my $charge (@$charges) {
    my $p = openbill::Period::period($charge->{period_id});
    next if $from_date && $from_date>$p->Data('end');
    $charge->{month}=$p->GetMonth();
    $charge->{month_days}=$p->Days();
    $charge->{date}=$p->Data('end');
    $charge->{is_closed}=$p->Data('is_closed');
    $charge->{service}='iptraff';
    $t{$charge->{tariff_id}}=
      tariff($charge->{tariff_id})->DataFull()
        unless $t{$charge->{tariff_id}};
    $charge->{tariff}=$t{$charge->{tariff_id}};
    $charge->{summa}=round($charge->{summa},2);
    $charge->{summa_order}=round($charge->{summa_order},2);
    $charge->{is_good_month_str}=$self->IsGoodMonthStr($p);
    #    $charge->{balance_on_start}=$c->GetBalance($p->Data('start'));
    #    $charge->{payed_summ}=$c->GetPayedSumm($p);
  }
  return $charges;

}

sub MakeInvoice {
  my ($self,$date,$num,$summa,$comment);
  return table('invoice')->
    Create({client_id=>$self->ID(),
            date=>$date,
            num=>$num,
            comment=>$comment,
            summa=>$summa});
}


#Программа лояльности
sub IsGoodMonth {
   my ($cr, $client0, $period0, $tariff0) = @_;

   my $period = $period0 || openbill::Period::period($cr->{period_id}) || fatal("period not defined");
   my $tariff = $tariff0 || openbill::Tariff::tariff($cr->{tariff_id}) || fatal("tariff not defined");
   my $client = $client0 || openbill::Client::client($cr->{client_id}) || fatal("client not defined");

   #Установленные вручную статусы
   #XXX: не факт что работают
   if ($period->IsOpen()) {
      return $client->Data('is_good_month')
	 if (($client->Data('is_good_month') == -100)
	    || ($client->Data('is_good_month') == 100));
   }

   #XXX2: Проверки по $cr->{total_days} нифига не работают:
   # если клиент пополнил баланс в середине месяца, оплата все равно берется за весь месяц
   # и total_days устанавливается на весь месяц.
   #XXX: Не проверяем первый месяц клиента. Он всегда не полный, а баланс
   #там обычно положительный.
   return -4 if ( ($period->Days() > $cr->{total_days})
	 && ( ! $period->IsDateInPeriod($client->Data('reg_date'))));
   return -7 if ($client->Data('is_firm'));	#Только для физ лиц
   return -3 if ($tariff->Data('is_unlim') == 0 );	#Только на безлимитах
   return -6 if ($cr->{traffic}->{inet} > $cr->{traffic}->{free} );

   #TODO: В идеале бонусы на время отключения по заявлению должны сохраняться.
   if ($period->IsOpen()) {
      return -9 if ($client->Data('is_active') == 0);
      return -10 if ($client->Data('balance') < $client->Data('minimal_balance'));
      #Только для клиентов без включенных опций 300-200
      return -8 if ( openbill::Tariff::GetOtherServicesSumm($period, $client) > 0);
      return 1;
   }

   return 1;
}

sub LoyaltyBonus {
   my $self = shift;
   my $spd;
   #my $nodes = dpl::Config::config()->root()->findnodes('./loyalty_programme/');
   #my $per_month = $node->getAttribute("speed_bonus_kbps") || fatal "speed bonus not defined";
   #my $max = $node->getAttribute("speed_bonus_max") || fatal "max speed bonus not defined";
   my $per_month=16;
   my $max=128;

   $spd = $self->Data('good_month_cnt') * $per_month;
   $spd = $max if $spd > $max;
   $spd = 0 if $spd < 0;

   return $spd;
}

sub IsGoodMonthStr {
    my ($self, $period) = @_;
    my $code;
    if ( $period ) {
      return "открытый период: ".$LOYAL_PROGRAMME_ERRCODES{$self->Data('is_good_month')}
	 if $period->IsOpen();
      my $cr = $self->GetChargeRecord($period) || fatal('no charge record found');
      $code=$cr->{is_good_month};
    }else {
      $code=$self->Data('is_good_month');
    }
    return $LOYAL_PROGRAMME_ERRCODES{$code};
}

1;
