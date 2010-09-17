package openbill::Shell::Payment;
use strict;
use openbill::Shell;
use openbill::Utils;
use dpl::Context;
use dpl::System;
use dpl::Db::Table;
use Text::FormatTable;
use Number::Format qw(:subs);
use Data::Dumper;
use openbill::Shell::Base;
use Exporter;
use vars qw(@ISA
            @EXPORT);
@ISA=qw(Exporter
        openbill::Shell::Base);


registerCommands('openbill::Shell::Payment',
                 {
                  list_payments=>{},
                  delete_payment=>{},
                  modify_payment=>{},
                  show_payment=>{},
                  make_payment=>{},
                  make_oriopay_payment=>{},
                 });

sub questpayment {
  my ($self,$p,$is_modify) = @_;
#  die join(',',%$p);
  my @a=(
         {key=>'client_id',name=>'Абонент',obligated=>1,
          post=>sub {
            my $params=shift;
            my $c = $self->soap('client','find',$params->{client_id});

            if (ref($c)) {
              #                             $params->{client}=$c;
              print "Выбран клиент: '$c->{client}'\n";
              return $params->{client_id}=$c->{client_id};
            } elsif ($c) {
              print "Таких абонентов более одного - $c.\n";
            } else {
              print "Такой клиент не найден.\n";
            }
            return undef;
          }},
         {key=>'type',name=>'Вид платежа',obligated=>1,
          pre=>sub {
#            return $_[2] if defined $_[2];
            my $p = shift;
            return $_[1] ? 1 : 2 if defined $_[1];
            return 1;
#            return $self->soap('client','hasPaymentsOfType',$p->{client_id},0)
#            ? 1 : 2
          },
          set=>[{key=>1,name=>'абонплата'},
                {key=>0,name=>'подключение'},
                {key=>-1,name=>'абонплата при подключении'},
                {key=>2,name=>'реализация'},
                {key=>3,name=>'прочее'}],
         },
         {
          key=>'payment_method_id',name=>'Способ платежа',obligated=>1,
          start=>sub {
            my ($h,$p,$default) = @_;
            my $list = $self->soap('payment','methods');
            my @s;
            foreach (@$list) {
              push @s,{key=>$_->{id},name=>$_->{name}};
            }
            $p->{set}=\@s;
          },
          post=>sub {
            my $p = shift;
            $p->{method}=$self->soap('payment','getMethod',$p->{payment_method_id});
            return $p->{payment_method_id};
          }
         },
         {key=>'summa_order',name=>'Сумма оплаты',obligated=>1,
          post=>sub {
            my $p = shift;
            return 1 if $p->{summa_order}>0;
            print "Сумма должна быть положительная\n";
            return undef;
          }
         });
  push @a,{key=>'summa',name=>'Сумма зачисления',obligated=>1,
           pre=>sub {
             my ($p,$pp,$d) = @_;
             my $s = round($p->{summa_order}*100/(100+$p->{method}->{tax}),2);
             print "Дисконт выбранного метода оплаты: $p->{method}->{tax}% ($s)\n";
             return $d;
           }}
    if $is_modify;
  push @a,({key=>'date',name=>'Дата',obligated=>1,
           type=>'date',
            pre=>sub { return $p->{date} || today()->TimeFormat('%Y-%m-%d')}
           },
           {key=>'comment',name=>'Коментарий'});
  push @a,{key=>'modify_comment',name=>'Причина изменения',obligated=>1}
    if $is_modify;
  return $self->{shell}->
    Question('payment',\@a,$p);
}

sub questpayment_oriopay {
  my ($self,$p) = @_;
  my @a=(
         {key=>'client_id',name=>'Абонент',obligated=>1,
          post=>sub {
            my $params=shift;
            my $c = $self->soap('client','find',$params->{client_id});

            if (ref($c)) {
              #                             $params->{client}=$c;
              print "Выбран клиент: '$c->{client}'\n";
              return $params->{client_id}=$c->{client_id};
            } elsif ($c) {
              print "Таких абонентов более одного - $c.\n";
            } else {
              print "Такой клиент не найден.\n";
            }
            return undef;
          }},
         {key=>'code',name=>'Секретный код',obligated=>1,
         });
  return $self->{shell}->
    Question('payment',\@a,$p);
}



sub CMD_make_payment {
  my ($self,$p) = @_;
  $p=$self->questpayment({client_id=>$p}) || return undef;
#  delete $p->{client};
  # TODO Оплата безналом
  delete $p->{method};
  if (my $rec =  $self->soap('client','makePayment',$p)) {
    print "Зачислено ".FormatMoney($rec->{summa})." под номером #$rec->{id}\n";
    return 0;
  } else {
    print "Оплата не зафиксирована.";
    return 1;
  }
}

sub CMD_make_oriopay_payment {
  my ($self,$p) = @_;
  $p  = $self->strToHash($p);
  unless ($p->{client_id} && $p->{code}) {
    $p=$self->questpayment_oriopay($p) || return undef;
  }

#  delete $p->{client};
  # TODO Оплата безналом
  delete $p->{method};
  $p->{payment_method_id}=10;
  $p->{type}=1;
  $p->{client_ip}='127.0.0.1';
  my $rec =  $self->soap('client','makePayment',$p);
  if ($rec && $rec->{id} && $rec->{summa}) {
    print "Зачислено ".FormatMoney($rec->{summa})." под номером #$rec->{id}\n";
    return 0;
  } else {
    print "Оплата не зафиксирована.";
    print Dumper($rec);
    return 1;
  }
}


sub CMD_list_payments {
  my ($self,$p) = @_;
  $p  = $self->strToHash($p);
  my $res;
  my $show_client;
  my $table;
  my $cc;
#  if ($p->{client_id}) {
#    my $client = $self->soap('client','find',$p->{client_id}) ||
#      fatal("Такой клиент не найден");
#    $res = $self->soap('client','payments',$client->{client_id});
#    print "Список платежей (".(scalar @$list).") клиента '$client->{client}'\n";
#    $table = Text::FormatTable->new('r| l | l | r | r | r | l | l ');
#    $table->head('id', 'Дата', 'Форма', 'Manager' ,'Платёж', 'Зачислено', 'Баланс после', 'За что', 'N Счёта, Комментарий');
#  } else {
  $cc=1;
  my $start = $p->{start}+0; delete $p->{start};
  my $limit = $p->{limit}+0; delete $p->{limit};

  $res = $self->soap('payment','list',$p,'',$start,$limit);

#  }
  my $count = @{$res->{list}};
  my $list = $res->{list};
  print "Список платежей (".(scalar @$list)."):\n";
  $table = Text::FormatTable->new('r| l | l | r | r | r | r | l | l | l ');
  $table->head('id', 'Дата', 'Форма', 'Manager'  ,'Платёж', 'Зачислено', 'Баланс до', 'Клиент', 'За что' , 'N Счёта, Комментарий');
  $show_client=1;
  $table->rule('=');
  my $summa;
  my $summa_order;
  foreach my $d (@$list) {
    my $id = $d->{id};
    $id="0$id" if $id<10;
    if ($d->{type}==1 || $d->{type}==-11 || $cc) {
      $summa+=$d->{summa};
      $summa_order+=$d->{summa_order};
    }
    my @a = ($id, $d->{date}->TimeFormat('%Y-%m-%d'),
             $d->{method},
             $d->{manager},
             FormatMoney($d->{summa_order}),FormatMoney($d->{summa}),defined $d->{balance} ? FormatMoney($d->{balance}) : '???');
    push @a,$d->{client};
    if ($d->{type}==1) {
      push @a,'абонплата';
    } elsif ($d->{type}==-1) {
      push @a,'абонплата при подключении';
    } elsif (!$d->{type}) {
      push @a,'подключение';
    } elsif ($d->{type}==2) {
      push @a,'реализация';
    } else {
      push @a,'прочее';
    }

    push @a,"$d->{invoice_id} $d->{comment}";
    $table->row(@a);
  }
  $table->rule('=');
  $self->showTable($table);
  $res->{start}++;
  print "Итого платежей $res->{max}, выводится $count начиная с $res->{start}\n\n";

  $table = Text::FormatTable->new('r| l | l | r | r | r ');
  $table->head('id', 'Метод', 'Такса', 'Сумма' ,'Сумма зачислений','Платажей');
  $table->rule('=');
  my $pm = $res->{payment_methods};
  foreach my $k (sort keys %$pm) {
    $table->row($k,$pm->{$k}->{name},"$pm->{$k}->{tax}%",
                FormatMoney($pm->{$k}->{summa_order}),FormatMoney($pm->{$k}->{summa}),
                $pm->{$k}->{count})
      if $pm->{$k}->{count};
  }
  $table->rule('=');
  $self->showTable($table);
  print "По абонплате: ".FormatMoney($summa_order)." зачислено как ".FormatMoney($summa)."\n";
}

sub CMD_delete_payment {
  my $self = shift;
  if ($self->soap('payment','delete',@_)) {
    print "Платёж удален\n";
    return 0;
  } else {
    print "Платёж не удалён\n";
    return 1;
  }
}

sub CMD_modify_payment {
  my ($self,$id,$p) = @_;
  my $p  = $self->strToHash($p);
  my $data = $self->soap('payment','get',$id);
  unless ($data) {
    print "Нет такого платежа\n";
    return 1;
  }
  print "Изменение: ";
  foreach (keys %$data) {
    $data->{$_}=$p->{$_}
      if exists $p->{$_};
  }
  #  $data->{client}=$date->{client_id};
  $p=$self->questpayment($data,1) || return undef;
  if ($self->soap('payment','modify',$id,$p)) {
    print "OK\n";
    return 0;
  } else {
    print "Ошибка\n";
    return 1;
  }
}

sub CMD_show_payment {
  my ($self,$id,$p) = @_;
  my $p  = $self->strToHash($p);
  my $data = $self->soap('payment','get',$id);
  unless ($data) {
    print "Нет такого платежа\n";
    return 1;
  }
  my $table = Text::FormatTable->new('r | l');
  $table->head('Поле', 'Значение');
  $table->rule('-');
  $table->row('ID',$data->{id});
  $table->row('Дата зачисления',$data->{timestamp});
  $table->row('Зачислил',"$data->{manager}->{name}");
  $table->rule('-');
  $table->row('Клиент',"[$data->{client_id}] $data->{client}");

  $table->row('Дата платежа',$data->{date});
  $table->row('Сумма платежа',FormatMoney($data->{summa_order}));
  $table->row('Сумма зачисления',FormatMoney($data->{summa}));
  $table->row('Способ зачисления',$data->{method}->{name});
  $table->row('Вид платежа',$data->{description});
  $table->row('Баланс до платежа',FormatMoney($data->{balance}));
  $table->row('Коментарий',$data->{comment})
    if $data->{comment};

  $table->rule('=');
  $self->showTable($table);

  if (@{$data->{log}}) {
    print "\nЖурнал изменений платежа:\n";
    foreach my $l (@{$data->{log}}) {
      print "------------------------------------\n";
      print "Платёж изменил менеджер: #$l->{manager_id}\n";
      print "Время изменения: $l->{timestamp}\n";
      print "Причина: $l->{modify_comment}\n";
      print "Изменены данные:\n";
      foreach (qw(client_id summa summa_order payment_method_id type date comment)) {
        my $old = $l->{$_};
        my $new = $l->{"new_$_"};
        print "\t$_: $old -> $new\n"
          if $old ne $new;
      }
    }
  }

}


1;
