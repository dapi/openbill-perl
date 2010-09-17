package openbill::Shell::Router;
use strict;
use dpl::Error;
use openbill::Shell;
use openbill::Utils;
use dpl::Context;
use openbill::Shell::Base;
use Exporter;
use vars qw(@ISA
            @EXPORT);
@ISA=qw(Exporter
        openbill::Shell::Base);

registerCommands('openbill::Shell::Router',
                 {
                  _copy_hosts=>{},
                  _clean_hosts=>{},
                  show_router=>{},
                  list_routers=>{},
                  create_router=>{},
                  delete_router=>{},
                  modify_router=>{},
                  make_router_sshkey=>{},
                  list_router_ip=>{},
                  delete_router_ip=>{},
                  add_router_ip=>{},
                  check_loyal_hosts=>{},
                  whole_update_router=>{},
                 });


sub CMD_whole_update_router {
  my ($self,$p) = @_;
  my ($router_id)= $self->strToArr($p);
  if ($router_id) {
    my $r = $self->
      soap('router',
           'whole_update',$router_id);
    print "Ok\n";
  } else {
    print "whole_update_router [router_id|all]\nУстановка флага на полный апдейт базы хостов у привратников\n";
  }
}

sub CMD_check_loyal_hosts {
  my ($self,$p) = @_;
  my $p  = $self->strToHash($p);
  my $r =
    $self->soap('router',
                'check_loyal_hosts',$p);
  print "Обработано хостов $r->{hosts}\nХосты не прописанные в биллинге как клиентские:\n";
  if (@{$r->{list}}) {
    my  $table = Text::FormatTable->new('l | l | l | l');
    $table->head('router', 'host', 'client', "IP");
    $table->rule('=');
    foreach my $h (@{$r->{list}}) {
      $table->row($h->{router_id},$h->{host_id},$h->{client_id},inet_ntoa($h->{ip}));
    }
    $self->showTable($table);
  } else {
    print "Нет таких\n";
  }
  print "\nНеиспользуемые клиентские сети (удалить через delete_not_used=1):\n";
  if (@{$r->{notused}}) {
    my  $table = Text::FormatTable->new('l | l | l | l');
    $table->head('mask', 'router', 'type', 'comment');
    $table->rule('=');
    foreach my $h (@{$r->{notused}}) {
      my $b = 32-$h->{bits};
      $table->row(inet_ntoa($h->{mask}<<$h->{bits})."/$b",$h->{router_id},$h->{type},$h->{comment});
    }
    $self->showTable($table);
  } else {
    print "Нет таких\n";
  }

}


sub questrouter {
  my ($self,$p) = @_;
 # die join(',',%$p);
  my $janitors = $self->soap('janitor','list');
  fatal("Создайте сначала хотябы одного привратника") unless $janitors && @$janitors;
  return $self->{shell}->
    Question('router',[
                       {key=>'ip',name=>'IP',obligated=>1},
                       {key=>'real_ip',name=>'Реальный IP',obligated=>1},
                       {key=>'mac',name=>'MAC-Адрес',obligated=>1},
                       {key=>'hostname',name=>'Имя хоста',obligated=>1},
                       {key=>'shortname',name=>'Короткое имя хоста',obligated=>1},
                       {key=>'client_ip_min',name=>'Минимальный клиентский IP'},
                       {key=>'client_ip_max',name=>'Максимальный клиентский IP'},
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
                       {key=>'altitude',name=>'Высота',obligated=>0},
                       {key=>'login',name=>'login',obligated=>0},
                       {key=>'default_janitor_id',name=>'Привратник',obligated=>1,
                        post=>sub {
                          my $params=shift;
                          foreach my $j (@$janitors) {
                            return $params->{default_janitor_id}=$j->{id}
                              if $j->{id} == $params->{default_janitor_id}
                                || $j->{name} == $params->{default_janitor_id};
                          }
                          print  "Список доступных привратников:\n";
                          foreach my $j (@$janitors) {
                            print "$j->{name}\t$j->{comment}\n";
                          }
                        }},
                       {key=>'use_janitor',name=>'Использовать привратник',obligated=>1,type=>'boolean',pre=>sub {'да';}},
                       {key=>'is_active',name=>'Действующий роутер',obligated=>1,type=>'boolean',pre=>sub {'да';}},
                       {key=>'comment',name=>'Коментарий'}
                      ],$p);
}


sub CMD_add_router_ip {
  my ($self,$p) = @_;
  unless ($p) {
    print "Параметры: router=0|router_id type=local|client net=10.100.0.0/16 comment=\n";
    return 0;
  }
  my $p = $self->strToHash($p);
  if ($self->soap('router','add_ip',$p)) {
    print "Создано\n";
  } else {
    print "Ошибка создания\n";
  }
}

sub CMD_list_router_ip {
  my ($self,$p) = @_;
  unless ($p) {
    print "Параметры: type=local|client router_id=0|номер\n";
    return 0;
  }
  my $p = $self->strToHash($p);
  my $res = $self->soap('router','list_router_ip',$p);
  if ($res) {
    my $table = Text::FormatTable->new('r | l | l | l');
    $table->head('Роутер', 'Сеть', 'Тип', 'Комментарий');
    $table->rule('=');
    foreach my $h (@$res) {
      my $b = 32-$h->{bits};
      $table->row($h->{router_id},inet_ntoa($h->{mask}<<$h->{bits})."/$b",$h->{type},$h->{comment});
    }
    $self->showTable($table);
    print "OK\n";
  } else {
    print "Ошибка создания\n";
  }
}


sub CMD_delete_router_ip {
  my ($self,$p) = @_;
  unless ($p) {
    print "Параметры: router_id=? type=local|client net=10.100.0.0/16\n";
    return 0;
  }
  my $p = $self->strToHash($p);
  my $res = $self->soap('router','delete_ip',$p->{router_id},$p->{type},$p->{net});
  print "Удалено\n";
}


sub CMD_make {
  my ($self,$p) = @_;
  my $p  = $self->strToArr($p);
  if ($p->{router}) {
    my $r = router()->LoadBy('name',$p->{router});
    $r->MakeSshKey();
  } else {
    map {$_->MakeSshKey()} @{router()->List()};
  }
}

sub CMD_create {
  my ($self,$p) = @_;
  my $s = router();
  return print "Невозможно создать роутер. Возможно такой уже есть."
    unless defined $s->Create($p);
  print "Создан роутер #".$s->ID();
}

sub GetRouter {
  my ($self,$id) = @_;
  my $res = $self->soap('router','get',$id);
  fatal("Нет такого роутера") unless $res;
  fatal("Таких роутеров более одного - $res.") if !ref($res) && $res>1;
  return $res;
}

sub CMD_make_router_sshkey {
  my ($self,$id) = @_;
  return $self->soap('router','makeSshKey',$id);
}

sub CMD__copy_hosts {
  my ($self,$p) = @_;
  my ($src,$dst)= $self->strToArr($p);
  print "Копирую хосты с роутера ID:$src на ID:$dst:\n";
  my $list = $self->soap('router','copy_hosts',$src,$dst);
  foreach (@$list) {
    print "$_->{old}->{host} -> $_->{new}->{host}\n";
  }
  print "Готово\n";
}

sub CMD__clean_hosts {
  my ($self,$p) = @_;
  my $p = $self->strToHash($p);
  # Удаляет хосты не используемые в рамках указанных дат
  # исправляет имена хостов
  # Пример: _clean_hosts router_id=1 date_from=2005-12-01 date_to=2006-01-30

  $p->{from_date}=ParseDate($p->{from_date}) || fatal("Неверная дата from_date");
  $p->{to_date}=ParseDate($p->{to_date}) || fatal("Неверная дата to_date");
  print "Очищаю хосты с роутера ID:$p->{router_id} за период $p->{from_date} - $p->{to_date}:\n";
  my $res = $self->soap('router','clean_hosts',$p);
  print "Готово ($res)\n";
}



sub CMD_show_router {
  my $self = shift;
  my $r = $self->GetRouter(@_);
  my $table = Text::FormatTable->new('r | l');
  $table->rule('=');
  $table->row('ID',$r->{router_id});
  $table->row('IP',"$r->{ip} / $r->{real_ip} / $r->{mac}");
  $table->row('MAC',"$r->{mac}");
  $table->row('hostname',"$r->{hostname} / $r->{shortname}");
  $table->row('Клиентские IP',"от $r->{client_ip_min} - $r->{client_ip_max}, свободно $r->{free_ips}")
    if $r->{client_ip_min} || $r->{client_ip_max};
  $table->row('login',"$r->{login}")
    if $r->{login};
  $table->row('Активен',$r->{is_active} ? 'Да' : 'НЕТ');
  $table->row('Адрес',$r->{address});
  $table->row('Высота',"$r->{altitude} м.")
    if $r->{altitude};
  $table->row('Первый трафик',$r->{firstwork_time});
  $table->row('Нужен полный апдейт привратника',$r->{need_whole_update} ? 'Да' : 'нет');
  $table->row('Коментарий',$r->{comment})
    if $r->{comment};
  $table->rule('-');

  # TODO Сделать инфо по всем сервисам
  #my $period = period()->LoadByDate($service,today());
  #  my ($t,$g) = openbill::Service::IPTraff->GetTraffic({router_id=>$r->ID(),
  #                                                       from=>$period->Data('start'),
  #                                                       to=>$period->Data('end'),
  #                                                      },'class');
  #  $table->row('Трафик за месяц',FormatBytes($t->{0}).' / '.FormatBytes($t->{1}));
  #  ($t,$g) = openbill::Service::IPTraff->GetTraffic({router_id=>$r->ID(),
  #                                                    date=>today()},'class');
  #  $table->row('Трафик за сегодня ('.today()->string().')',FormatBytes($t->{0}).' / '.FormatBytes($t->{1}));
  $table->row('Последний трафик',$r->{lastwork_time});
  #  $table->rule('-');
  #
  #  $table->row('Локальные адреса',join(', ',inet_bmtoa(@{$r->GetIPs('local')})));
  #  $table->row('Клиентские адреса',join(', ',inet_bmtoa(@{$r->GetIPs('client')})));
  $self->showTable($table);
  return 0;
}

sub CMD_list_routers {
  my $self = shift;
  my $list = $self->soap('router','list');
  print "Список роутеров (".(scalar @$list)."):\n";
  my $table = Text::FormatTable->new('r| l l l l');
  $table->head('id', 'Хост', 'IP', 'Адрес', 'Комментарий');
  $table->rule('=');
  foreach my $d (@$list) {
    my $id = $d->{router_id};
    $id="0$id" if $id<10;
    my $alt;
    $alt="\nВысота: $d->{altitude} м." if $d->{altitude};
    $table->row($id, "$d->{hostname}\n$d->{shortname}",
                "$d->{ip}\n$d->{real_ip}\n$d->{mac}" ,
                "$d->{address}$alt",
                $d->{comment});
    $table->rule();
  }

  $self->showTable($table);
}

sub CMD_create_router {
  my ($self,$p) = @_;
  print "Создание нового роутера:\n";

  $p=$self->questrouter($p) || return undef;
  if (my $id = $self->soap('router','create',$p)) {
    print "Создан роутер #$id\n";
    return 1;
  } else {
    print "Роутер не создан\n";
    return 0;
  }
}

sub CMD_delete_router {
  my $self = shift;
  if ($self->soap('router','delete',@_)) {
    print "Роутер удалён\n";
    return 0;
  } else {
    print "Роутер не удалён\n";
    return 1;
  }
}

sub CMD_modify_router {
  my ($self,$id,$p) = @_;
  my $p  = $self->strToHash($p);
  my $data = $self->soap('router','get',$id);
  unless ($data) {
    print "Нет такого роутера\n";
    return 1;
  }
  foreach (keys %$data) {
    $data->{$_}=$p->{$_}
      if exists $p->{$_};
  }
  print "Изменения роутера:\n";
  $p=$self->questrouter($data) || return undef;
  if ($self->soap('router','modify',$id,$p)) {
    print "OK\n"; return 0;
  } else {
    print "Ошибка\n";  return 1;
  }
}


1;
