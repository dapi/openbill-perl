package openbill::Shell::Manager;
use strict;
use openbill::Shell;
use openbill::Shell::Base;
use openbill::Utils;
use dpl::Context;
use Data::Dumper;
use dpl::System;
use Exporter;
use vars qw(@ISA @EXPORT);
@ISA=qw(Exporter openbill::Shell::Base);

registerCommands('openbill::Shell::Manager',
                 {
                  show_manager=>{},
                  list_managers=>{},
                  finance_report=>{},
                  create_manager=>{},
                  modify_manager=>{},
                  change_password=>{},
                 });


sub questmanager {
  my ($self,$p) = @_;
  return $self->{shell}->
    Question('manager',[{key=>'name',name=>'Имя',obligated=>1},
                        {key=>'login',name=>'Login',obligated=>1},
                        {key=>'password',name=>'Пароль',obligated=>1},
                        {
                         key=>'mgroup_id',name=>'Группа',obligated=>1,
                         start=>sub {
                           my ($h,$p,$default) = @_;
                           my $list = $self->soap('mgroup','list');
                           my @s;
#                           die join(',',%$default);
                           foreach (@$list) {
                             push @s,{key=>$_->{id},name=>$_->{name}};
                           }
                           $p->{set}=\@s;
                           return 2;
                         },

                         #                         post=>sub {
                         #                           my $p = shift;
                         #                           $p->{method}=$self->soap('payment','getMethod',$p->{payment_method_id});
                         #return $p->{payment_method_id};
                         #                         }
                         },
                         {key=>'comment',name=>'Коментарий'}],
                        $p);
}

sub CMD_finance_report {
  my ($self,$params)=@_;
  $params=$self->strToHash($params);
  if ($params->{date}) {
    $params->{date}=ParseDate($params->{date}) || fatal("Неверная дата");
  } else {
    $params->{date}=ParseDate('yesterday');
  }

  print "\nORIONET.\n\nОтчёт за ".$params->{date}->TimeFormat("%A %e %B'%y")."\n\n\n";

  my $p = $self->soap('payment',
                      'ext_list',{date_from=>$params->{date},
                                  date_to=>$params->{date}});

  # Посмотрим кто сколько заплатил

  my %cp;
  foreach (@{$p->{list}}) {
    $cp{$_->{client_id}}={list=>[]}
      unless exists $cp{$_->{client_id}};
    push @{$cp{$_->{client_id}}->{list}},$_;
    $cp{$_->{client_id}}->{$_->{type}}+=$_->{summa};
  }

  my $res = $self->soap('client',
                        'ext_find',{reg_date=>$params->{date}});

  my $table = Text::FormatTable->new('r | r | r | r | r');
  $table->rule('-');
  $table->head('ID', 'Клиент', 'Адрес', 'Абонплата', 'Подключение');
  $table->rule('-');
  my $firms=0;
#  print Dumper($res);
  foreach (@{$res->{list}}) {
    #    die Dumper($_);
    $table->row($_->{client_id},$_->{client},$_->{address},FormatMoney($cp{$_->{client_id}}->{1}), $cp{$_->{client_id}}->{0} ? FormatMoney($cp{$_->{client_id}}->{0}) : 'НЕТ ОПЛАТЫ');
    $firms++ if $_->{is_firm};
  }
  $table->rule('-');
  $table->row("$res->{max} чел",$firms ? "из них $firms юр.лиц" : 'юр.лиц нет','','','');
  $table->rule('-');
  $self->showTable($table);

  print "\n\n";

  my %a;
  my $table = Text::FormatTable->new('r | r r r r | r');

  $table->rule('-');
  $table->head('Метод', 'Абонплата', 'Подключение', 'Реализация', 'Прочее', 'Всего');
  $table->rule('-');
  foreach my $m (sort keys %{$p->{ms}}) {
    $table->row($p->{methods}->{$m}->{name},
                FormatMoney($p->{ms}->{$m}->{1}),
                FormatMoney($p->{ms}->{$m}->{0}),
                FormatMoney($p->{ms}->{$m}->{2}),
                FormatMoney($p->{ms}->{$m}->{3}),
                FormatMoney($p->{ms}->{$m}->{all}),
               );
    foreach (qw(all 0 1 2 3 )) {
      $a{$_}+=$p->{ms}->{$m}->{$_};
    }
  }
  $table->rule('-');
  $table->row('Итого',
                FormatMoney($a{1}),
                FormatMoney($a{0}),
                FormatMoney($a{2}),
                FormatMoney($a{3}),
                FormatMoney($a{all}),
               );
  $table->rule('-');
#  $table->rule('=');
  $self->showTable($table);


  return 1;
}



sub CMD_show_manager {
  my $self = shift;
  my $data = $self->soap('manager','get',@_);
  unless ($data) {
    print "Нет такого менеджера.";
    return 1;
  }
  my $table = Text::FormatTable->new('r | l ');
  $table->rule('=');
  $table->row('ID',$data->{manager_id});
  $table->row('Имя',$data->{name});
  $table->row('login',$data->{login});
  $table->row('Группа',$data->{mgroup});
  $table->row('Коментарий',$data->{comment})
    if $data->{comment};
  $self->showTable($table);
  return 0;
}

sub CMD_change_password {
  my $self = shift;
  my $id = shift;
  my $data = $self->soap('manager','get',$id);
  unless ($data) {
    print "Нет такого менеджера.";
    return 1;
  }
  print "Изменение пароля для менеджера: $data->{name}\n";
  my $r = $self->{shell}->
    Question('manager',[{key=>'password',name=>'Пароль',obligated=>1},
                       ],
            );
  my $res = $self->soap('manager','changePassword',$id,$r->{password});
}

sub CMD_list_managers {
  my $self = shift;
  my $list = $self->soap('manager','list',@_);
  $self->ListManagers($list);
}

sub ListManagers {
  my ($self,$list) = @_;
  print "Список менеджеров (".(scalar @$list)."):\n";
  my $table = Text::FormatTable->new('r| l l l l');
  $table->rule('=');
  $table->head('ID', 'Имя', 'login', 'Группа', 'Коментарий');
  $table->rule('-');
  foreach my $d (@$list) {
    my $id = $d->{manager_id}+0;
    $id="0$id" if $id<10;
    $table->row($id, $d->{name}, $d->{login}, $d->{mgroup}, $d->{comment});
  }
  $table->rule('=');
  $self->showTable($table);
}

sub CMD_create_manager {
  my ($self,$p) = @_;
  print "Создание нового менеджера:\n";
  $p=$self->questmanager($p) || return undef;
  $p->{is_active}=1;
  if (my $id = $self->soap('manager','create',$p)) {
    print "Создан менеджер #$id\n";
    return 1;
  } else {
    print "Менеджер не создан\n";
    return 0;
  }
}


sub CMD_modify_manager {
  my ($self,$id,$p) = @_;
  my $p  = $self->strToHash($p);
  my $data = $self->soap('manager','get',$id);
  unless ($data) {
    print "Нет такого менеджера\n";
    return 1;
  }
  print "Изменение: ";
  foreach (keys %$data) {
    $data->{$_}=$p->{$_}
      if exists $p->{$_};
  }
  $p=$self->questmanager($data) || return undef;
  if ($self->soap('manager','modify',$id,$p)) {
    print "OK\n";
    return 0;
  } else {
    print "Ошибка\n";
    return 1;
  }
}

1;
