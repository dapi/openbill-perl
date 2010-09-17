package openbill::Shell::Client;
use strict;
use openbill::Shell;
use openbill::Utils;
use dpl::Context;
use dpl::System;
use dpl::Error;
use Number::Format qw(:subs);
#use Date::Parse;
#use Date::Format;
#use Date::Language;
#use Date::Handler;
use dpl::Log;
use Data::Dumper;
use openbill::Shell::Base;
use Email::Valid;
use Exporter;
use vars qw(@ISA
            @EXPORT);
@ISA=qw(Exporter
        openbill::Shell::Base);

registerCommands('openbill::Shell::Client',
                 {
                  tsb=>{},
                  show_client=>{},
                  redo_balance=>{},
                  redo_balances=>{},
                  do_alert=>{},
                  list_clients=>{},
                  list_invoices=>{},
                  list_charges=>{},
                  create_client=>{},
                  modify_client=>{},
                  modify_charge=>{},
                  recharge_client=>{},
                  #                  list_accounts=>{},
                  list_activations=>{},
                  list_balances=>{},
                  restore_balance=>{},
                  change_tariff=>{},
                  show_account=>{},
                  check_balance=>{},
                  activate_client=>{},
                  deactivate_client=>{},
                  show_check_act=>{},
                  send_mail=>{},
                  set_night_speed=>{},
                  set_daytime=>{},
                 });




sub fields {
  my ($self,$data) = @_;
  my @list = (
              {
               name=>'name',title=>'Имя'},
              {
               name=>'nick',title=>'Псевдоним'},
              {name=>'reg_date',title=>'Регистрация',
               value=>$data->{reg_date}->TimeFormat('%e %B %Y')},
              {name=>'manager',title=>'Зарегистрировавший менеджер'},
              {
               name=>'telefon',title=>'Телефон'},
              {
               name=>'email',title=>'Емайл'},
              {
               name=>'address',title=>'Адрес'},
              {
               name=>'can_deactivate',title=>'Можно выключать',
               value=>$data->{can_deactivate} ? 'да' : 'НЕТ'},
              {name=>'is_active',title=>'Доступ',value=>$data->{is_active} ? 'есть' : 'НЕТ'},
              {name=>'firmname',title=>'Фирма'},
              {name=>'inn',title=>'ИНН'},
              {name=>'bill_delivery',title=>'Доставка счёта'},
              {name=>'payment_method',title=>'Обычный способ оплаты'},
              {name=>'minimal_balance',title=>'Минимальный баланс'},
              {name=>'balance',title=>'Баланс',value=>FormatMoney($data->{balance},$data->{currency})},
#              {name=>'start_balance',title=>'Баланс на начало'},
              {name=>'do_alert',title=>'Оповещение включено'},
              {name=>'balance_to_alert',title=>'Баланс для оповещение'},
              {name=>'alert_email',title=>'Email для оповещение'},

              {name=>'lastwork_time',title=>'Последний трафик'},
              {name=>'night_speed',title=>'Ночная скорость'},

              {name=>'period_month',title=>'Текущий период'},
              {name=>'period_traffic_mb',title=>'Трафик в периоде (Mb)'},
              {name=>'period_limited',title=>'Достигнут пороговый тарфик'},
	      {name=>'is_good_month_str',title=>'Статус программы лояльности'},
	      {name=>'good_month_cnt',title=>'Месяцев программы лояльности'},
	      {name=>'bonus_speed',title=>'Бонусы скорости, Kbps'},

              {name=>'order_connection_summ',title=>'Стоимость подключения'},
              {name=>'real_connection_summ',title=>'Оплачено за подключение'},

              {name=>'payed_to_date',title=>'Оплачено по'},
              {name=>'comment',title=>'Коментарий'},
             );
  foreach (@list) {
    unless (exists $_->{value}) {
      $_->{value}=$_->{name} eq 'manager' ? $data->{$_->{name}}->{name} : $data->{$_->{name}};
    }
  }

  return \@list;
}

sub format_account {
  my $cid = shift;
#  return $cid+0;
  while (length($cid)<6) {
    $cid="0$cid";
  }
  return "$cid";
}

sub reformat_account {
  my $cid = shift;
  $cid=~s/._\-//g;
  return $cid+0;
}

sub CMD_tsb {
  my $self = shift;
  my ($command,@params) = $self->strToArr(@_);

  if ($command eq 'PING') {
    print "PONG\n";

  } elsif ($command eq 'REQ_INF') {
    my ($cid,$password)=@params;
    $cid = reformat_account($cid);
    my $c = $self->soap('client','get',$cid);
    if (!$c || ($c->{status_id} == 4)) {
      print "ERROR no such client\n";
      return;
    } elsif (!ref($c) && $c>1) {
      print "ERROR such clients are more than one\n";
      return;
    }
    print "USER\n";
    #Добавить группу к пользователю  (GROUP ид_группы имя_группы)
    #    print "ADDGROUP 0 Орио Групп\n";
    print "ADDGROUP 1 Орио Групп\n";
    #Формируем счет
    #Организация-получатель платежа
    print "NAMEORG ООО \"Орио Групп\"\n";
    #Наименование платежа
    #    print "NAMESCHET Услуги Интернет\n";
    #Лицевой счет плательщика
    #Код счета
#    print "NUMSCHET 123456789\n";
    #БИК
    #    print "BIK 049706750\n";
    print "BIK 049706609\n"; # их
    #Реальный счет получателя платежа"
    print "SCHET 40702810675020134005\n";
    #ИНН получаетя
    print "INN 2128056642\n";
    #Банк
    print "BANKNAME Чувашское отделение 8613 СБ РФ\n"; # (ОАО) в г.Чебоксары
    #Корсчет
    #    print "CORSCHET 30101810000000000750\n";
    print "CORSCHET 30101810300000000609\n"; # их
    #Комиссия
    #print "PERCENT 0\n";
    #Минимальная сума комиссии
    #    print "AMOUNTMIN 0.0"
    #Максимальная сумма комиссии
    #    print "AMOUNTMAX 0.0"
    #Признак платежа без комиссии
    #    print "DOGOVOR 0"
    my $s = format_account($c->{client_id});
    print "LSCHET $s\n";
    #Тип платежа (0 - задолженность, 1 - авансовый, и тд)
    if ($c->{balance}>0) {
      print "TYPEBILL 1\n";
    } else {
      print "TYPEBILL 0\n";
    }
    #ФИО плательщика
    print "FIO $c->{name}\n";
    #Его адрес
    print "STREET $c->{street}\n";
    print "HOUSE $c->{building}\n";
#    print "CORPUS $c->{address}->{room}\n"
    print "KVARTIRA $c->{room}\n"
      if length($c->{room})>0 && length($c->{room})<=5;
    #Период

#    print "PERIOD 01.1980\n";
    my $a = -int($c->{balance}-0.5)*100;
    #Оплаченная сума платежа
#    print "AMOUNT $a\n";
    #Выставленная биллингом сумма
    $a=0 if $a<0;
    print "AMOUNTOVER $a\n";
#    print "PERIOD 01.1980"
    #Оплаченная сума платежа
    print "AMOUNT 0\n";
    #Выставленная биллингом сумма
#    print "AMOUNTOVER 0\n";
    #Добавить сформированный BLL к пользователю и группе
    print "ADDBILL\n"
  } elsif ($command eq 'REQ_PAY') {
    my ($cid,$filial,$term,$doc,$payment,$tran,$date,$ltime)=@params;
    my $p={};
    $p->{client_id}=reformat_account($cid);

    my $c = $self->soap('client','get',$p->{client_id});
    if (!$c || ($c->{status_id} == 4)) {
      print "ERROR no such client\n";
      return;
    } elsif (!ref($c) && $c>1) {
      print "ERROR such clients are more than one\n";
      return;
    }

    $p->{payment_method_id}=13;
    $p->{type}=1;
    $p->{summa_order}=$payment/100;
    $p->{date}=today()->TimeFormat('%Y-%m-%d');
    $p->{client_ip}='127.0.0.1';
    $p->{comment}="cid:$cid,filial:$filial,term:$term,doc:$doc,payment:$payment,tran:$tran,date:$date,ltime:$ltime";
    $p->{secret_comment}=$p->{comment};
    my $rec =  $self->soap('client','makePayment',$p);
    if ($rec && $rec->{id} && $rec->{summa}) {
      print "OK\n";
      #      print "Зачислено ".FormatMoney($rec->{summa})." под номером #$rec->{id}\n";
      #      return 0;
    } else {
      print "ERROR no payment\n";
    }

  } else {
    print "ERROR Unknown command $command\n";
  }
}

sub CMD_set_night_speed {
  my $self = shift;
  my ($client,$speed) = $self->strToArr(@_);
  unless ($client) {
    print "Использование: set_night_speed [client_id] [speed]\n";
  }
  my $res = $self->soap('client','set_night_speed',$client,$speed);
  print "Сумма пересчета: $res\n";
  return 1;
}

sub CMD_set_daytime {
  my $self = shift;
  my ($daytime) = $self->strToArr(@_);
  if ($daytime) {
    my $res = $self->soap('client','set_daytime',$daytime);
  } else {
    print "Использование: set_daytime [day|night]\n";
  }

}


sub CMD_check_balance {
  my $self = shift;
  my ($client) = $self->strToArr(@_);
#  my $c = $self->GetClient($client) || return 1;
 # return 1 unless ref($c);
#  my $table = $self->ShowClient($c);
  my $res = $self->soap('client','check_balance',$client);
  if ($res==-1) {
    print "Абонент уже отключен\n";
  } elsif ($res==1) {
    print "Абонент отключен, так-как баланс меньше разрешённого\n";
  } elsif ($res==2) {
    print "У абонента баланс меньше допустимого, послано письмо, так-как отключать не разрешено\n";
  } elsif ($res==3) {
    print "У абонента возможно скоро кончатся средства, информирован письмом\n";
  } elsif ($res==0) {
    print "У абонента всё в порядке\n";
  } else {
    print "Неизвестный ответ: $res\n";
  }
}

sub CMD_do_alert {
  my $self = shift;
  my $res = $self->soap('client','do_alert',@_);
  if ($res) {
    print "Оповещено $res клиентов\n";
  } else {
    print "Оповещений не требуется";
  }
}

sub CMD_show_client {
  my $self = shift;
  my ($client,$date) = $self->strToArr(@_);
  my $c = $self->GetClient($client) || return 1;
  return 1 unless ref($c);
  my $table = $self->ShowClient($c);

  $date = $date ? ($date=~/\d\d\d\d-\d\d-\d\d/ ? ParseDate($date) : ParseMonth($date)) : ToDate(today());
  fatal("Неверно указана дата") unless $date;
  #  die "$date";
  # TODO Показать с какой даты активирован, какие у него хосты

  my $period = $self->soap('period','get');
  unless ($period) {
    $table->row('Период НЕДОСТУПЕН:',$date);
    next;
  }
  my $charge = $self->soap('client','getChargeRecord',$c->{client_id},$period->{id});
  $table->row('Сервис:','iptraff');
  if ($charge) {
    $table->row('Тариф:',"[$charge->{tariff_id}] $charge->{tariff}");
    $table->row("За период $charge->{period}: ",
                FormatMoney($charge->{summa},$charge->{currency})
                .' ( абон:'.FormatMoney($charge->{season_summa},$charge->{currency}).
                ' траф:'.FormatMoney($charge->{traffic_summa},$charge->{currency}).')');
    $table->row('Учтённый трафик:',FormatBytes($charge->{traffic}->{0}+$charge->{traffic}->{10}).", беспл: ".FormatBytes($charge->{traffic_free}));
  }
#     my $t = $self->soap('service','traffic',$s->{id},
#                         {client_id=>$c->{client_id},
#                          from=>$period->{start},
#                          to=>$period->{end}},['ip','class']);
#     if (keys %{$t->{traffic}}>1) {
#       foreach (keys %{$t->{traffic}}) {
#         unless ($_ eq 'all') {
#           my $host = $self->soap('host','get',$_);
#           $table->row("Хост $host->{hostname}/$host->{ip}:", FormatBytes($t->{traffic}->{$_}->{0}).' / '.FormatBytes($t->{traffic}->{$_}->{1}));
#         }
#       }
#     }
  my $balance = $self->soap('client','getBalance',$c->{client_id},$period->{start});
  $table->row('Баланс без текущего периода:',
              FormatMoney($balance));

  $table->rule('-');
  my $lb = $self->soap('client','getBalance',$c->{client_id},1);
  $table->row('ЖУРНАЛЬНЫЙ баланс:',FormatMoney($lb))
    if abs($lb-$c->{balance})>0.01;
  $self->showTable($table);

}

sub GetClient {
  my ($self,$id) = @_;
  my $res = $self->soap('client','get',$id);
  fatal("Нет такого клиента") unless $res;
  fatal("Таких клиентов более одного - $res.") if !ref($res) && $res>1;
  return $res;
}

sub ShowClient {
  my ($self,$data) = @_;
  my $table = Text::FormatTable->new('r | l ');
  $table->rule('=');
  $table->row('ID',$data->{client_id});
  foreach (@{$self->fields($data)}) {
    $table->row($_->{title},$_->{value})
      if $_->{value} ne '';
  }
  $table->rule('=');
  #  $self->showTable($table);
  return $table;
}

sub ShowClientM {
  my ($self,$data) = @_;
  my $table = Text::FormatTable->new('r | l ');
  $table->rule('=');
  $table->row('ID',$data->{client_id});
  $table->row('Клиент',"$data->{name} / $data->{firmname}");
  $table->rule('=');
  return $table;
}

sub CMD_create_client {
  my ($self,$p) = @_;
  my $p  = $self->strToHash($p);
  print "Создание нового клиента:\n";
  # TODO Сделать чтобы клиент создавался автоматически если параметры указаны со строки
  $p=$self->questclient($p) || return undef;
  $p->{can_deactivate}=1;
  if ($p->{is_firm}) {
    $p->{balance_to_alert}=-2000;
    $p->{balance_to_off}=-3000;
    $p->{unpayed_days_to_off}=12+31;
    $p->{unpayed_days_to_alert}=9+31;
  } else {
    $p->{balance_to_alert}=100;
  }
  $p->{status_id}=0;
#  $p->{send_alert_days}=5;
#  $p->{alert_balance}=100;
  my $id = $self->soap('client','create',$p);
  unless ($id) {
    print "Ошибка создания клиента.";
    return 1;
  }
  print "Создан клиент #$id\n";
}

sub CMD_list_clients {
  my ($self,$params) = @_;
  $params  = $self->strToHash($params);
  $params->{reg_date} = ParseDate($params->{reg_date}) || fatal("Неверно указан reg_date")
    if $params->{reg_date};
  $params->{reg_date_from} = ParseDate($params->{reg_date_from}) || fatal("Неверно указан reg_date_from")
    if $params->{reg_date_from};
  $params->{reg_date_to} = ParseDate($params->{reg_date_to})  || fatal("Неверно указан reg_date_ti")
    if $params->{reg_date_to};
  my $balance_date = ParseDate($params->{balance_date})  || fatal("Неверно указан balance_date")
    if $params->{balance_date};

  delete $params->{balance_date};
  my $start = $params->{start}+0; delete $params->{start};
  my $limit = $params->{limit}+0; delete $params->{limit};

  my $res = $self->soap('client','list',$params,'',$start,$limit);
  my $count = @{$res->{list}};
  my $list = $res->{list};
  my $table = Text::FormatTable->new('r| l l r r r l l');
  $table->rule('=');
  $table->head('id', 'Псевдоним/Имя', 'A','Баланс','Выставленный','НДС', 'Адрес/Телефон', 'Комментарий');
  $table->rule('=');
  foreach my $d (@$list) {
    my $id = $d->{client_id};
#    print "$id";
    $id="0$id" if $id<10;

    my $f;
    my $u;
    my $e;
    if ($d->{firmname}) {
      $f="\n\n$d->{firmname}";
      $e="ИНН:$d->{inn}\n";
      my $u=" (юр.лицо)";
    }
    $d->{balance_ordered}=$self->soap('client','getBalance',$d->{client_id},$balance_date)
	   if $balance_date;
    $table->row($id, "$d->{nick}$u\n$d->{name}$f",
                $d->{is_active} ? '' : '* ',
                FormatMoney($d->{balance}),FormatMoney($d->{balance_ordered}),
                FormatMoney($d->{balance_ordered}*1.18),
                "$d->{telefon}\n$d->{email}\n$d->{street}, $d->{building}, $d->{room}",
                  "$e\nРегистрация: ".$d->{reg_date}->string());
    $table->rule();


#     if ($id>650) {
#       # Исправление суммы оплаты
#       my $s = $self->CP($id);
#       if ($s!=$d->{real_connection_summ}) {
#         print "$id: $s<>$d->{real_connection_summ}\n";
#         $self->soap('client','modify',$id,{real_connection_summ=>$s});
#       }
#     }

  }
  $self->showTable($table);
  $res->{start}++;
  print "Всего $res->{max} выводится $count начиная с $res->{start}";
}

sub CMD_list_balances {
  my ($self) = @_;
  my $res = $self->soap('client','list',{},'',0,999999);
  foreach my $d (@{$res->{list}}) {
    my $id = $d->{client_id};
#    my $b = $d->{is_firm} ? round($d->{balance}*1.18,2) : round($d->{balance},2);
    my $b = round($d->{balance},2);
    print "$id\t$b\n";
  }
}

sub CMD_redo_balances {
  my ($self) = @_;
  my $res = $self->soap('client','list',{},'',0,400);
  my $list = $res->{list};
#  my $table = Text::FormatTable->new('r| l l r r r l l');
  my $date = ParseDate('2006-01-01');
#  $table->rule('=');
#  $table->head('id', 'Псевдоним/Имя', 'A','Баланс','Выставленный','НДС', 'Адрес/Телефон', 'Комментарий');
#  $table->rule('=');
  foreach my $d (@$list) {
    $self->RedoClient($d);
  }

  # $self->showTable($table);
}

sub CMD_redo_balance {
  my ($self,$id) = @_;
  my $res = $self->soap('client','get',$id);
  $self->RedoClient($res);
  # $self->showTable($table);
}


sub RedoClient {
  my ($self,$d) = @_;
  my $date = ParseDate('2006-01-01');
  my $old_balance = $d->{balance};
#  $self->soap('client','recharge',$d->{client_id});
  my $start_balance = $self->soap('client','getStartBalance',$d->{client_id},$d->{is_firm});
  my $balance_2006 = $self->soap('client','getBalance2006',$d->{client_id},$d->{is_firm});
  my $new_balance = $start_balance+$balance_2006;
  my $b = round($new_balance,2);
#  print "$d->{client_id}\t$b\n";
  $self->soap('client','modify',$d->{client_id},{start_balance=>$start_balance,
                                                 old_balance=>$old_balance,
                                                 balance=>$new_balance});
  my $diff = $d->{is_firm} ? $old_balance - $new_balance/1.18 :$old_balance-$new_balance;

  if ($diff>1 || $diff>1) {
    print "# $d->{client_id}\t(start:$start_balance)\t$new_balance<>$old_balance\n";
  }
  return 1;


}


# sub CMD_list_invoices {
#   my ($self,$params) = @_;
#   $params  = $self->strToHash($params);
#   $params->{date} = ParseMonth($params->{month}) || fatal("Неверно указан месяц");
#   delete $params->{month};
#   $params->{reg_date} = ParseDate($params->{reg_date}) || fatal("Неверно указан reg_date")
#     if $params->{reg_date};
#   $params->{reg_date_from} = ParseDate($params->{reg_date_from}) || fatal("Неверно указан reg_date_from")
#     if $params->{reg_date_from};
#   $params->{reg_date_to} = ParseDate($params->{reg_date_to})  || fatal("Неверно указан reg_date_ti")
#     if $params->{reg_date_to};
#
#   my $start = $params->{start}+0; delete $params->{start};
#   my $limit = $params->{limit}+0; delete $params->{limit};
#
#   my $res = $self->soap('client','list',$params,'',$start,$limit);
#   my $count = @{$res->{list}};
#   my $list = $res->{list};
#   my $table = Text::FormatTable->new('r | r | r r r | r ');
#   $table->rule('=');
#   $table->head('Абонент', 'Тип', 'Сервис', "Абонплата\nПредоплаченный", "Доп.трафик\nMb", "Итого");
#   $table->rule('=');
#   my $nalog = 1.18;             # TODO в конфиг
#   my $summa=0;
#   my $currency='р.';
#   my %services;
#   foreach my $client (@$list) {
#     #    print join(',',%{$client->{charges}})."\n";
#     my $was=0;
#     foreach my $sid (keys %{$client->{charges}}) {
#       my $charge = $client->{charges}->{$sid};
#       $services{$sid} = $self->soap('service','get',$sid)
#         unless exists $services{$sid};
#       if ($charge) {
#         my $t = $charge->{traffic_free};
#         $t=$charge->{traffic}->{0} if $charge->{traffic}->{0}<$t;
#         $t=$t ? FormatBytes($t) : '-';
#         my $td = $charge->{traffic}->{0}-$charge->{traffic_free};
#         $td=$td>0 ? FormatBytes($td) : '-';
#         $summa+=$charge->{summa};
#         $table->row("$client->{name}\n$client->{firmname}",
#                     $client->{is_firm} ? 'юр.лицо' : 'частник',
#                     $services{$sid}->{name},  $charge->{season_summa}+$charge->{traffic_free}>0 ?
#                     FormatMoney($charge->{season_summa},$currency)."\n$t" : '-',
#                     FormatMoney($charge->{traffic_summa},$currency)."\n$td",
#                     FormatMoney($charge->{summa},$currency));
#         $was=1;
#       }
#     }
#     $table->rule()
#       if $was;
#   }
#   $self->showTable($table);
#   $res->{start}++;
#   print "Всего $res->{max} выводится $count начиная с $res->{start}, сумма:".FormatMoney($summa);
# }



sub questclient {
  my ($self,$p) = @_;
  return $self->{shell}->
    Question('client',[
                       {
                        key=>'name',name=>'ФИО',obligated=>1},
                       {key=>'street',name=>'Улица',obligated=>1,
                        post=>sub {
                          my $params=shift;
                          my $id = $self->soap('street','find',$params->{street})
                            || return undef;
                          delete $params->{street};
                          $params->{street_id}=$id;
                        }},
                       {key=>'building',name=>'Дом',obligated=>1,post=>sub {
                          my $params=shift;
                          my $id = $self->soap('building','find',
                                               $params->{street_id},
                                               $params->{building})|| return undef;
                          delete $params->{building};
                          delete $params->{street_id};
                          $params->{building_id}=$id;
                        }},
                       {key=>'room',name=>'Квартира/Офис',obligated=>1,post=>sub {
                          my $params=shift;
                          my $id =
                            $self->soap('address','find_or_create',
                                        $params->{building_id},
                                        $params->{room}) || return undef;
                          delete $params->{room};
                          delete $params->{building_id};
                          $params->{address_id}=$id;
                        }},
                       {
                        key=>'telefon',name=>'Телефоны',obligated=>1},
                       {key=>'email',name=>'Емайлы (none если нет)',obligated=>1,
                        post=>sub {
                          my $params=shift;
                          return 1 if $params->{email} eq 'none';
                          my @e = split(/[ ;,]+/,$params->{email});
                          foreach (@e) {
                            return undef unless Email::Valid->address($_);
                          }
                          return 1;
                        }},
                       {
                        key=>'is_firm',name=>'Юр.Лицо',obligated=>1,type=>'boolean',
                        pre=>sub {
                           return $_[2] ? 'да' : 'нет';
                        }},
                       {
                        key=>'firmname',name=>'Фирма',pre=>sub {
                          my ($h,$p,$d) = @_;
                          $p->{obligated}=$h->{is_firm};
                          return $d if $d;
                          return $h->{firmname} unless $d==undef;
                          return $h->{is_firm} ? 'ООО ' : '';
                        }
                       },
                       {
                        key=>'inn',name=>"ИНН",request=>sub { $_[0]->{is_firm} }},
                       {
                        key=>'nick',obligated=>1,name=>'Псевдоним'},
                       {
                        key=>'bill_delivery_id',obligated=>0,name=>'Способ счёта'},
                       {
                        key=>'payment_method_id',obligated=>0,name=>'Обычный способ оплаты',
                        pre=>sub {
                          my ($h,$p,$d) = @_;
                          return $h->{payment_method_id} if exists $h->{payment_method_id};
                          return $h->{is_firm} ? 1 : 2;
                        }},
                       {
                        key=>'reg_date',name=>'Дата регистрации',obligated=>1,
                        type=>'date',
                        pre=>sub { $_[2] || today()->TimeFormat('%Y-%m-%d')}
                       },
                       {
                        key=>'new_contract_date',name=>'Дата перезаключения нового контракта',
                        type=>'date',
#                        pre=>sub { $_[2] || today()->TimeFormat('%Y-%m-%d')}
                       },

                       {
                        key=>'months',name=>'Минимальный срок обслуживания на тарифе (мес.)',
                        obligated=>1,
                        pre=>sub { 1; }
                       },

                       {key=>'minimal_balance',
                        obligated=>1,
                        name=>'Минимально допустимый баланс на счёте',
                        pre=>sub {$_[2] || 0;}},

#                         {key=>'start_balance',
#                          obligated=>1,
#                          name=>'Баланс на начало',
#                          pre=>sub {$_[2] || 0;}},

                       {key=>'do_alert',type=>'boolean',obligated=>0,
                        name=>'Делать предупреждения',
                        pre=>sub {
                          return $_[2] ? 'да' : 'нет';
                        }},

                       {key=>'balance_to_alert',
                        obligated=>0,
                        name=>'Баланс для предупреждения',
                        pre=>sub {$_[2] || 0;}},

                       {key=>'alert_email',
                        obligated=>0,
                        name=>'Email для рассылки предупреждений',
                        pre=>sub {
                          my ($h,$p,$d) = @_;
#                          $p->{obligated}=$h->{is_firm};
                          return $d if $d;
                          return $h->{email};
                          #                          return $h->{is_firm} ? 'ООО ' : '';
                        },
                        post=>sub {
                          my $params=shift;
                          return 1 if $params->{alert_email} eq 'none';
                          return Email::Valid->address($params->{alert_email});
                        }},

                       {key=>'order_connection_summ',obligated=>0,
                        name=>'Стоимость подключения',
                       },


                       {key=>'has_connection_credit',type=>'boolean',obligated=>0,
                        name=>'Подключение в кредит',
                        pre=>sub {
                          return $_[2] ? 'да' : 'нет';
                        }},

#                        {key=>'balance_to_off',
#                         obligated=>0,
#                         name=>'Баланс для отключения',
#                         pre=>sub {$_[2] || 0;}},
#
#                        {key=>'unpayed_days_to_off',
#                         obligated=>0,
#                         name=>'Дней без оплаты для отключения',
#                         pre=>sub {$_[2] || 0;}},
#
#                        {key=>'unpayed_days_to_alert',
#                         obligated=>0,
#                         name=>'Дней без оплаты для предупреждения ',
#                         pre=>sub {$_[2] || 0;}},
#
                       {key=>'is_good_month',
                        obligated=>1,
                        name=>'Статус программы лояльности (-100/0/100)',
                        pre=>sub {$_[2] || 0;}},
                       {key=>'good_month_cnt',
                        obligated=>1,
                        name=>'Кол-во месяцев программы лояльности',
                        pre=>sub {$_[2] || 0;}},

                       {key=>'comment',name=>'Коментарий'}
                      ],$p);
}

sub questcharge {
  my ($self,$p) = @_;
  return $self->{shell}->
    Question('client',[
                       {key=>'tariff_id',name=>'Тариф',obligated=>1},
                       {key=>'t0',name=>'Дневной интернет траффик (байт)',obligated=>1},
                       {key=>'t10',name=>'Ночной интернет траффик (байт)',obligated=>1},
                       {key=>'traffic_free',name=>'Из него бесплатный трафик (байт)',obligated=>1},
                       {key=>'season_summa',name=>'Абонплата',obligated=>1},
                       {key=>'season_order',name=>'Абонплата с НДС',obligated=>1},
                       {key=>'traffic_summa',name=>'Сумма за трафик',obligated=>1},
                       {key=>'traffic_order',name=>'Сумма за трафик с НДС',obligated=>1},

                       {key=>'summa',name=>'Сумма за месяц',obligated=>1,
                        pre=>sub {
                          my ($h,$p,$d) = @_;
                          return $h->{traffic_summa}+$h->{season_summa};
                        }},
                       {key=>'summa_order',name=>'Сумма счёта',obligated=>1},
                       ],$p);
}


sub CMD_modify_client {
  my ($self,$p) = @_;
  my $p  = $self->strToHash($p,'client');
  my $id = $p->{client}; delete $p->{client};
  my $data = $self->soap('client','get',$id);
  unless ($data) {
    print "Нет такого клиента\n";
    return 1;
  }
  my $table = $self->ShowClientM($data);
  print "Изменения клиента:\n";
  $self->showTable($table);
  my $new=%$p ? $p : $self->questclient($data) || return undef;
  if ($self->soap('client','modify',$id,$new)) {
    print "OK\n";
    return 0;
  } else {
    print "Ошибка\n";
    return 1;
  }
}

sub CMD_modify_charge {
  my ($self,$p) = @_;
  my $p  = $self->strToHash($p);
  fatal("Не указан client_id") unless $p->{client_id};
  fatal("Не указан month (YYYY-MM)") unless $p->{month};
  my $data = $self->soap('client','get',$p->{client_id});
  unless ($data) {
    print "Нет такого клиента\n";
    return 1;
  }
  my $period = $self->soap('period','get',ParseMonth($p->{month}) || fatal("Неверно указан месяц $p->{month}"));
  unless ($period) {
    print "Период НЕДОСТУПЕН: $p->{month}\n";
    exit;
  }
  my $charge = $self->soap('client','getChargeRecord',$p->{client_id},$period->{id});
  my $table = $self->ShowClientM($data);
  print "Изменения charge ($p->{month}) для клиента:\n";
  $self->showTable($table);
  unless ($charge) {
    print "Нет такой charge\n";
#    return;
  }
  $charge->{t0}=$charge->{traffic}->{0};
  $charge->{t10}=$charge->{traffic}->{10};
  my $new=$self->questcharge($charge) || return undef;
  $new->{traffic}->{0}=$new->{t0};
  $new->{traffic}->{10}=$new->{t10};
  delete $new->{t0};
  delete $new->{t10};
  my $charge = $self->soap('client','modifyChargeRecord',$p->{client_id},$period->{id},$new);
  return "Результат: $charge\n";
#  if ($self->soap('client','modify',$id,$new)) {
#    print "OK\n";
#    return 0;
#  } else {
#    print "Ошибка\n";
#    return 1;
#  }
}

# sub CMD_list_accounts {
#   my ($self,$p) = @_;
#   $p  = $self->strToHash($p);
#   my $start = $p->{start}+0; delete $p->{start};
#   my $limit = $p->{limit}+0; delete $p->{limit};
#   my $nalog=$p->{nalog};
#   my $show_log=$p->{show_log};
#   delete $p->{nalog};
#   delete $p->{show_log};
#   if ($nalog) {
#     print "\nНалог: $nalog\n";
#   } else {
#     $nalog=1;
#   }
#   my $res = $self->soap('client','list',$p,'',$start,$limit);
#   my $count = @{$res->{list}};
#
#   print "Счета клиентов ($count):\n";
#   my $date = ToDate(PeriodFromDate(today()));
#   foreach my $c (@{$res->{list}}) {
#     my $balance = $self->soap('client','getBalance',$c->{client_id},$date);
#     print "\n***\nКлиент:\t$c->{name},$c->{firmname}\n";
#     print "Баланс:\t".FormatMoney($c->{balance}).", на текущий период: ".FormatMoney($balance->{balance},$balance->{currency})."\n";
#     if ($show_log) {
#
#       my $charges = $self->soap('client','charges',$c->{client_id});
#       my $payments = $self->soap('client','payments',$c->{client_id});
#
#       my $table = Text::FormatTable->new(' r r r l | r l l ');
#       $table->rule('=');
#       $table->head('Дата оплаты', 'Сумма', 'Зачислено', 'Вид оплаты', 'Служба', 'Месяц', 'Сумма');
#       $table->rule('-');
#       my @c = reverse @$charges;
#       my @p = reverse @$payments;
#       my ($summa,$summa_p,$summa_po);
#       while (@c || @p) {
#         my $c = shift @c;
#         my $p = shift @p;
#         my @a;
#         if ($p) {
#           $summa_p+=$p->{summa};
#           $summa_po+=$p->{summa_order};
#           push @a, $p->{date}->TimeFormat('%Y-%m-%d');
#           push @a, FormatMoney($p->{summa_order});
#           push @a, FormatMoney($p->{summa});
#           push @a, ($p->{type} ? 'абонплата' : 'подключение').','.($p->{form} eq 'order' ?  'перечисл' : 'налич');
#         } else {
#           push @a,('-','','','');
#         }
#         if ($c) {
#           my $s=$c->{summa}*$nalog;
#           $summa+=$s;
#           push @a, $c->{service};
#           push @a, $c->{month};
#           push @a, FormatMoney($s);
#         } else {
#           push @a, ('-','','');
#         }
#         $table->row(@a);
#       }
#       $table->rule('-');
#       $table->row('Всего оплаты',FormatMoney($summa_po),FormatMoney($summa_p),'',
#                   'Всего оказано','',FormatMoney($summa));
#       $table->rule('=');
#       $self->showTable($table);
#     }
#   }
# }
#
# sub CMD_list_accounts_old {
#   my ($self,$p) = @_;
#   $p=$self->strToHash($p);
#   my %p;
#   $p{is_firm}=$p->{is_firm} ?  1 : 0 if exists $p->{is_firm};
#   $p{date} = ParseDate("$p->{month}-01")  || fatal("Неверно указан месяц")
#     if $p->{month};
#   my ($list,$services) = @{$self->soap('client','list',\%p)};
#   print "Счета клиентов (".(scalar @$list)."):\n";
#   my $table = Text::FormatTable->new('l l | r '.join('',map {' | l '} @$services));
#
#   $table->head('ID','Псевдоним/Имя','Баланс',map {$_->{name}} @$services);
#   $table->rule('=');
#   my $balance=0;
#   my %charged;
#   my %traff;
#   foreach my $client (@$list) {
#     my $id = $client->{client_id};
#     $id="0$id" if $id<10;
#     $balance+=$client->{balance};
#     my @a=("[$id]","$client->{client}\nт. $client->{telefon}",
#            FormatMoney($client->{balance},$client->{currency}));
#
#     foreach my $s (@{$services}) {
#       $client->{charges}={} unless $client->{charges};
#       my $c = $client->{charges}->{$s->{id}};
#       $traff{$s->{id}}={} unless exists $traff{$s->{id}};
#       my $t  = $traff{$s->{id}};
#       if ($c) {
#         $charged{$s->{id}}+=$c->{summa};
#         $charged{all}+=$c->{summa};
#         push @a,FormatMoney($c->{summa},$client->{currency})."\n".FormatBytes($c->{traffic}->{0})."/".FormatBytes($c->{traffic}->{1});
#         $t->{0}+=$c->{traffic}->{0};   $t->{1}+=$c->{traffic}->{1};
#       } else {
#         push @a,'-';
#       }
#     }
#     $table->row(@a);
#   }
#   $table->rule();
#   $table->row('*',FormatMoney($balance,'р.'), FormatMoney($charged{all},'р.'),
#               map {FormatMoney($charged{$_->{id}},'р.')."\n".
#                      FormatBytes($traff{$_->{id}}->{0}).'/'.FormatBytes($traff{$_->{id}}->{1})}
#               @$services
#              );
#   $self->showTable($table);
# }

sub CMD_restore_balance {
  my ($self,$client) = @_;
  print "Пересчёт клиентского баланса: ";
  my $res = $self->soap('client','restore_balance',$client);
  if (defined  $res) {
    print abs($res)>0.01 ? "получена разница в $res рублей" : "Разницы нет";
  } else {
    print "Ошибка";
  }
  print "\n";
}


sub CMD_recharge_client {
  my $self = shift;
  my ($client,$date) = $self->strToArr(@_);
  my $res = $self->soap('client','recharge',$client);
  print "Пересчитано периодов: $res\n";
}


sub CMD_send_mail {
  my ($self,$p) = @_;
  my $options;
  $p  = $self->strToHash($p);
  fatal("Не указан клиент")  unless $p->{client_id};
  fatal("Не указан шаблон")  unless $p->{template};
  $options->{use_main_email}=$p->{use_main_email};
  $options->{from_client_id}=$p->{from_client_id};
  my $res = $self->soap('client','send_mail',$p->{client_id},$p->{template}, 0, $options);
}


sub CMD_change_tariff {
  my ($self,$p) = @_;
  $p  = $self->strToHash($p);
#  $p->{date} = $p->{month} ? ParseMonth($p->{month}) :  ToDate(today());
 # fatal("Неверно указан месяц") unless $p->{date};
  fatal("Не указан тариф") unless $p->{tariff_id};
  fatal("Не указан клинет") unless $p->{client_id};
  print "Смена тарифа: ";
  $p->{date}=$p->{month} if $p->{month};
  $p->{no_check}=1;
  my $res = $self->soap('client','change_tariff',$p);
  print $res ? "OK\n" : "Ошибка, может такой тариф уже установлен\n";
  return !$res;
}

sub CMD_show_history {
  my ($self,$p) = @_;
  my ($client) = $self->strToArr($p);
  my $res = $self->soap('client','history',$client);
  unless ($res) {
    print "Нет такого клиента\n";
  }
  foreach (@$res) {
  }
}



sub CMD_activate_client {
  my ($self,$p) = @_;
  my ($client,$date,$comment) = $self->strToArr($p);
  my $date  = $date ? ParseDate($date) : ToDate(today());
  print "Включение клиента: ";
  my $res = $self->soap('client','activate',$client,$date,$comment);
  print $res ? "OK\n" : "Ошибка\n";
  return !$res;
}

sub CMD_deactivate_client {
  my ($self,$p) = @_;
  my ($client,$date,$type,$comment) = $self->strToArr($p);
  my $date  = $date ? ParseDate($date) : ToDate(today());
  print "Выключение клиента: ";
  my $res = $self->soap('client','deactivate',$client,$date,$comment,$type);
  print $res ? "OK\n" : "Ошибка\n";
  return !$res;
}

sub CMD_show_account {
  my $self = shift;
  # TODO Показать с какой даты активирован, какие у него хосты
  my $res = $self->soap('client','account',@_);

  print "Нет такого клиента." unless $res;
  fatal("Таких клиентов более одного - $res.") if !ref($res) && $res>1;
  return 1 unless ref($res);
  my $table = $self->ShowClient($res->{client});
  print "Клиентские данные:\n";
  $self->showTable($table);
  foreach my $service (@{$res->{services}}) {
    $table = Text::FormatTable->new('r | l | l | l ');
    $table->rule('=');
    $table->head('Месяц', 'Тариф', 'Дата установки', 'Коментарий');
    $table->rule('-');
    print "\nЖурнал установки тарифов для '$service->{service}':\n";
    foreach (@{$service->{tariffes}}) {
      $table->row(DateToMonth($_->{from_ym}),$_->{tariff}, $_->{changetime}->TimeFormat('%x %T'), $_->{comment});
    }
    $table->rule('-');
    $self->showTable($table);
  }
  my $table = Text::FormatTable->new('l | r | '.join(' | ',map {"r"} @{$res->{services}}));
  $table->rule('=');
  $table->head('Клиент', 'Наработка', @{$res->{services}});
  $table->rule('-');
  $self->showTable($table);
  return 0;
}

sub CMD_show_check_act {
  my $self = shift;
  # TODO Ввести параметр year=
  my $res = $self->soap('client','check_act',@_);

  print "Нет такого клиента." unless $res;
  fatal("Таких клиентов более одного - $res.") if !ref($res) && $res>1;
  return 1 unless ref($res);
  my $table = $self->ShowClientM($res->{client},1);
  print "Клиентские данные:\n";
  $self->showTable($table);
  print "Акт сверки:\n";
  my $table = Text::FormatTable->new(' r | r | r | r | l ');
  $table->rule('=');
  $table->head('Дата', 'Дебет/Наработка', 'Кредит/Оплата', 'Баланс', 'Описание');
  $table->rule('-');
  my $balance;
  my ($summa_charges,$summa_payments);
  foreach my $m (@{$res->{motions}}) {
    if ($m->{payments}) {
      foreach my $p (@{$m->{payments}}) {
        my $n = $p->{method}->{name};
        $n="$n (подкл)" unless $p->{type};
        $n="$n #".$p->{id};
        $summa_payments+=$p->{summa_order}
          if $p->{type};
        $table->row($p->{date},'',
                    FormatMoney($p->{summa_order}),FormatMoney($summa_payments-$summa_charges),$n);
      }

    } else {

      my $date = $m->{charge}->{date};
      $date="* $date" unless $m->{charge}->{is_closed};
      $table->row($date,FormatMoney($m->{charge}->{summa_order}),'',
                  FormatMoney($summa_payments-$summa_charges),
                  "$m->{charge}->{service}, $m->{charge}->{tariff}");
      $summa_charges+=$m->{charge}->{summa_order};
    }
  }
  $table->rule('-');
  $table->row('ИТОГО (абонплата):',FormatMoney($summa_charges),FormatMoney($summa_payments),
              FormatMoney($summa_payments-$summa_charges),'',);
  $self->showTable($table);
  return 0;
}

sub CP {
  my $self = shift;
  my $cid = shift;
  my $p = $self->soap('client','payments',$cid);
  my $s = 0;
  foreach (@$p) {
    $s+=$_->{summa_order} if $_->{type}==0;
  }
  return $s;
}

sub CMD_list_activations {
  my $self = shift;
  my $res = $self->soap('client','list_activations',$self->strToArr(@_));
  unless ($res) {
    print "нет такого клиента\n";
    return;
  }
  my $table = $self->ShowClientM($res->{client});
  print "Клиентские данные:\n";
  $self->showTable($table);

  $table = Text::FormatTable->new('r | l | l | l ');
  $table->rule('=');
  $table->head('Дата', 'Действие', 'Выполнено', 'Коментарий');
  $table->rule('-');
  my $a = {0=>'Вручную',1=>'Отрицательный баланс',2=>'Нарушение договора',3=>'Вредоносные программы',4=>'Лимит кредита',5=>'Период кредита',6=>'Период оплаты',7=>'Нет оплаты. Снят с порта.'};
  foreach (@{$res->{activations}}) {
    $table->row($_->{date}->TimeFormat('%x'),
                $_->{is_active} ? 'Активирован' : "деактивирован: $a->{$_->{type}}",
                $_->{done_time},$_->{comment});
  }
  $table->rule('-');
  $self->showTable($table);
  return 0;
}

sub CMD_list_charges {
  my ($self,$p) = @_;

  # TODO Показать с какой даты активирован, какие у него хосты
  my %h;
  if ($p=~/^(\d+)$/) {
    $h{client_id}=$1;
  } else {
    %h=%{$self->strToHash($p)};
  }
  if ($h{month}) {
    $h{month} = ParseMonth($h{month}) || fatal("Неверно указан месяц")
  } elsif (!$h{client_id}) {
    $h{month} = today();
  }
  my $res = $self->soap('client','charges',$h{client_id},\%h);
  my $traffic_all=0;
  if ($h{month}) {
    if ($h{tab}) {

      my @fields = qw(client_id iptraff_summa iptraff_summa_order other_summa other_summa_order summa summa_order total_days act_log traffic_summa traffic_free season_summa tariff_id);
      my @client_fields = qw(name firmname is_firm reg_date balance is_active deactivation_type activation_time is_removed status_id real_connection_summ is_good_month good_month_cnt);
      my @tariff_fields = qw(name is_active is_unlim speed hosts_limit night_speed price);
      my @address_fields = qw(street_id building_id room building street);
      my @traffic_fields = qw(0 1 10);

      print join("\t",
                 @fields,
                 (map {"client.$_"} @client_fields),
                 (map {"tariff.$_"} @tariff_fields),
                 (map {"traffic.$_"} @traffic_fields),
                 (map {"address.$_"} @address_fields),
                )."\n";
      foreach my $charge (@$res) {
        my @a1 = map {"$charge->{$_}"} @fields;
        my @a2 = map {"$charge->{client}->{$_}"} @client_fields;
        my @a3 = map {"$charge->{tariff}->{$_}"} @tariff_fields;
        my @a4 = map {"$charge->{traffic}->{$_}"} @traffic_fields;
        my @a5 = map {"$charge->{address}->{$_}"} @address_fields;

        print join("\t",@a1,@a2,@a3,@a4,@a5);
        print "\n";
       }
    } else {
       my $table = Text::FormatTable->new('r | l | l | l | l | l | l | l | r');
       $table->rule('=');
       $table->head('Абонент', 'Служба, Тариф', "Абонплата (руб)", "За трафик (руб)",
                    "Трафик дневной/ночной/всего", 'За инет','Остальное', "Наработка", 'Счёт');
       $table->rule('-');
       print "\nЖурнал съёма:\n";
       my ($summa,$summa_order,$traffic_day,$traffic_night);
       foreach my $charge (@$res) {
         $traffic_day+=$charge->{traffic}->{0};
         $traffic_night+=$charge->{traffic}->{10};
         $summa+=$charge->{summa};
         $summa_order+=$charge->{summa_order};
         ShowCharge($table,"[$charge->{client_id}] $charge->{client}->{name}",$charge);
         $table->rule('-');
       }
       $table->row('ИТОГО счетов на ','','','',FormatBytes($traffic_day).'/'.FormatBytes($traffic_night).'/'.FormatBytes($traffic_day+$traffic_night),'','',FormatMoney($summa),FormatMoney($summa_order));#FormatBytes($traffic_all)
       $table->rule('=');
       $self->showTable($table);
     }
  } else {
    my $client = $self->soap('client','get',$h{client_id});
    my $table = $self->ShowClientM($client);
    print "Клиентские данные:\n";
    $self->showTable($table);
    my $summa = $self->ShowCharges($res);
    print "Итого оказано услуг на: ".FormatMoney($summa)."\n";
  }
  return 0;
}

sub ShowCharges {
  my ($self,$charges) = @_;
  my $table = Text::FormatTable->new('r | l | l | l | l | l | l | l | r');
  $table->rule('=');
  $table->head('Месяц', 'Тариф (рабочих дней)', "Абонплата (руб)",
               "За трафик (руб)",
               "Трафик всего\nДень/Ночь/Итого", 'За инет', 'Остальное', "Наработка", 'Счёт');
  $table->rule('-');
  print "\nЖурнал съёма:\n";
  my ($summa,$summa_order);
  foreach my $charge (reverse @$charges) {
    $summa+=$charge->{summa};
    $summa_order+=$charge->{summa_order};
    ShowCharge($table,$charge->{month},$charge);
  }
  $table->rule('=');
  $self->showTable($table);
  return ($summa,$summa_order);
}

sub ShowCharge {
  my ($table,$name,$charge)=@_;
  my $t = $charge->{traffic}->{0}+$charge->{traffic}->{10};
  my $t = $t-$charge->{traffic_free}>0 ? $t-$charge->{traffic_free} : 0;
  my $tariff = "#$charge->{tariff_id}:$charge->{tariff}->{name}";
  $table->row($name,
              "$tariff ($charge->{total_days}/$charge->{month_days})",
              FormatMoney($charge->{season_summa}).' ('.FormatBytes($charge->{traffic_free}).')',
              FormatMoney($charge->{traffic_summa}).' ('.FormatBytes($t).')',
              FormatBytes($charge->{traffic}->{0}).'/'.FormatBytes($charge->{traffic}->{10}).'/'.FormatBytes($charge->{traffic}->{0}+$charge->{traffic}->{10}),
              FormatMoney($charge->{iptraff_summa}),
              FormatMoney($charge->{other_summa}),
              FormatMoney($charge->{summa}),
              FormatMoney($charge->{summa_order})
             );
}


1;
