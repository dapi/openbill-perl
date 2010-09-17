package openbill::Shell::Host;
use strict;
use openbill::Shell;
use openbill::Utils;
use dpl::Context;
use dpl::Db::Table;
use dpl::Error;
use openbill::Shell::Base;
use Date::Parse;
use Data::Dumper;
use Exporter;
use vars qw(@ISA
            @EXPORT);

@ISA=qw(Exporter
        openbill::Shell::Base);

registerCommands('openbill::Shell::Host',
                 {
                  'show_host'=>{},
                  'deactivate_host'=>{},
                  'activate_host'=>{},
                  'move_host'=>{},
                  'delete_host'=>{},
                  'check_host'=>{},
                  'attach_host'=>{},
                  'list_hosts'=>{},
                  'list_all_hosts'=>{},
                  'create_vpn_host'=>{},
                  'create_host'=>{},
                  'modify_host'=>{},

                 });


# delete_unused

sub CMD_list_hosts {
  my ($self,$p) = @_;
  $p  = $self->strToHash($p);
  if ($p->{router}) {
    my $r = $self->soap('router','find',$p->{router});
    unless ($r) {
      print "Нет такого роутера: $p->{router}\n";
      return undef;
    }
    delete $p->{router};
    $p->{router_id}=$r->{router_id};
  }
  my $list = $self->soap('host','list',$p);
  my $table;
  $table = Text::FormatTable->new('l | l | l | l | l | l | l ');
  $table->head('ID', 'HOST', 'Hostname', "Роутер\nТип подключения", "Клиент\nАдрес", "Время", 'Коментарий');
  $table->rule('=');
  foreach my $h (@$list) {
    my $client = $h->{client_id} ? "[$h->{client_id}] $h->{client}\n" : "БЕЗХОЗНЫЙ\n";
    $table->row($h->{host_id}, "$h->{host}\n$h->{mac}", $h->{is_vpn} ? "$h->{hostname}\nVPN" : $h->{hostname},
                "$h->{router}\n$h->{am_type}/$h->{am_name}",
                "$client$h->{address}",
                $h->{lastwork_time},
                $h->{is_active} ? "ВКЮЧЕН: $h->{comment}" : "ВЫКЛЮЧЕН: $h->{comment}");
  }
  $self->showTable($table);
}


sub CMD_list_all_hosts {
  my ($self,$p) = @_;
  $p  = $self->strToHash($p);
  my $list = $self->soap('host','list_all',$p->{month});
  print "month: $p->{month}\n";
  print join("\t",qw(host is_vpn last_time tariff_id is_unlim speed)),"\n";
  foreach my $h (@$list) {
    my $l = $h->{lastwork_time} || $h->{createtime};
    print "$h->{host}\t$h->{is_vpn}\t$l\t$h->{tariff_id}\t$h->{tariff}->{is_unlim}\t$h->{tariff}->{speed}\n";
  }
}



sub CMD_check_host {
  my ($self,$pp) = @_;
  my $p  = $self->strToHash($pp);
  my $data;
  if ($p->{host_id}) {
    $data = $self->soap('host','check_link',$p->{host_id});
    unless ($data) {
      print "Нет такого хоста\n";
      return 1;
    }
  } elsif ($p->{router_id}) {
    $data = $self->soap('router','check_host',$p->{router_id},3,$p->{ip});
  } elsif ($p->{client_id}) {
    #    $data = $self->soap('router','check_host',$p->{router_id},$p->{ip});
    my $list = $self->soap('host','list',$p);
    my %r;
    foreach (@$list) {
      next unless $_->{is_active};
      $r{$_->{router_id}}=[] unless $r{$_->{router_id}};
      push @{$r{$_->{router_id}}},$_;
    }
    foreach (keys %r) {
      my $rid = $_;
      # TODO hack
      next if $rid==36;

#      print "Роутер: $rid\n";

      $data = $self->soap('router','check_host',$rid,3,map {$_->{host}} @{$r{$rid}});
      foreach (keys %$data) {
        print "Хост: $_: ";
        $self->ShowCheckHostResult($data->{$_})
      }
      print "\n";
    }
  } elsif ($p->{ip}) {
    my $list = $self->soap('host','list',$p);
    unless (@$list) {
      print "Такой хост не найден\n";
      return 1;
    }
    $data = $self->soap('host','check_link',$list->[0]->{host_id});
  } elsif ($pp=~/(\d+).(\d+).(\d+).(\d+)/) {
    my $list = $self->soap('host','list',{ip=>$pp});
    unless (@$list) {
      print "Такой хост не найден\n";
      return 1;
    }
    $data = $self->soap('host','check_link',$list->[0]->{host_id});
  } else {
    print "Не правильно указан хост ($p)\n";
  }
  $self->ShowCheckHostResult($data);
}

sub ShowCheckHostResult {
  my ($self,$data) = @_;
  if ($data->{result} eq 'OK') {
    print "\t+ Всё в порядке. MAC: $data->{mac}, задержка: $data->{time}, потери: $data->{loss}%, попыток: $data->{count}";
  } elsif ($data->{result} eq 'NO') {
    print "\t- НЕТ: ";
    if ($data->{mac} eq 'ARP') {
      print "такого хоста не встречалось";
    } elsif ($data->{mac} eq 'UNKNOWN') {
      print "неизвестная версия или отсутсвует arping";
    } else {
      print "ошибка запуска arping ($data->{mac})";
    }

  }
#     print "ping: $data->{ping}, " if $data->{ping};
#     print "arping: $data->{arping}, " if $data->{arping};
#     print "в dhcp был " if $data->{dhcp};
#   } else {
#     print "НЕТ СВЯЗИ";
#   }
  print "\n";
}

sub questhost {
  my ($self,$p,$is_new) = @_;
  my $at = $self->soap('host','access_types');
  my @a = (
           {key=>'router',name=>'Роутер',obligated=>1,
            pre=>sub {return $_[2];},
            post=>sub {
              my $params=shift;
              if ($params->{router}=~/^\d+$/) {
                $params->{router_id}=$params->{router};
                delete $params->{router};
              } else {
                my $router = $self->soap('router','find',$params->{router})
                  || return undef;
                unless (ref($router)) {
                  print "Ошибка поиска роутера, найдено: $router\n";
                  return undef;
                }
                $params->{janitor_id}=$router->{default_janitor_id}
                  unless $params->{janitor_id};
                delete $params->{router};
                $params->{router_id}=$router->{router_id};
              }
            }},

           {key=>'mac',name=>'MAC (или IP с которого взять или none)',obligated=>1,
            post=>sub {
              my $params = shift;
              return $params->{mac} eq 'none'
                || CheckMac($params->{mac})
                  unless $params->{mac}=~/\./;
              $params->{_ip}=$params->{mac};
              print "Ищу MAC адрес по IP ($params->{mac}) - ";
              my $data = $self->soap('router','check_host',
                                     $params->{router_id},1,$params->{mac});
              
              if ($data && $data->{$params->{mac}}->{result} eq 'OK') {
                $params->{mac}=$data->{$params->{mac}}->{mac};
                print "Установлен MAC $params->{mac}\n";
                return 1;
              } else {
                print "Такой хост не найден\n";
                return undef;
              }
            }
           },
           {key=>'host',name=>'Хост или сеть (подсеть)',obligated=>1,
            pre=>sub {
                         my $params = shift;
                         if ($params->{_ip}) {
                           return $self->soap('router','get_next_free_ip',$params->{router_id},$params->{_ip});
                         } else {
                           return $_[2]->{host};
                         }
                       },
            post=>sub {
              my $params = shift;
              delete $params->{_ip};
              if (!$params->{host} || $params->{host}=~/^\d+$/) {
                return $params->{host}=$self->soap('router','get_next_free_ip',$params->{router_id},"10.100.$params->{host}.10");
                # return $self->soap('router','get_next_free_ip',$params->{router_id},"10.100.$params->{host}.10");
              } else {
                return $params->{host};
              }
            }
           },
           {key=>'hostname',name=>'hostname',obligated=>1,
            pre=>sub { return $_[2] if defined $_[2];
                       my $h = $_[0]->{host};
                       $h=~s/10.100.//;
                       $h=~s/\./_/g;
                       return "host_$h";
                     },
           },
           {key=>'am_type',name=>'Тип подключения ('.join(',',@$at).')',obligated=>1,
            pre=>sub {return $_[2] if defined $_[2]; return 'vpn_only';},
            post=>sub {
              my $params=shift;
              foreach (@$at) {
                return $_ if $params->{am_type} eq $_;
              }
              return undef;
            }
           },
           {key=>'street',name=>'Улица',obligated=>1,post=>sub {
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
            key=>'is_active',name=>'Включен',obligated=>1,type=>'boolean',
            pre=>sub {
              return $_[2] ? 'да' : 'нет';
            }},
           {key=>'janitor',name=>'Привратник',obligated=>0,
            pre=>sub {
              my $params = shift;
              return $params->{janitor_id};
            },
            post=>sub {
              my $params=shift;
              unless ($params->{janitor}) {
                delete $params->{janitor};
                return 1;
              }
              my $j = $self->soap('janitor','find',$params->{janitor})
                || return undef;
              delete $params->{janitor};
              $params->{janitor_id}=$j->{id};
            }},
           {key=>'comment',name=>'Коментарий'}
          );
  if ($is_new) {
    unshift @a,{key=>'client_id',name=>'Клиент',obligate=>'1',
                post=>sub {
                  my $params = shift;
                  my $p = shift;
                  return 1 unless $params->{client_id};
                  print "Ищу клиента - ";
                  my $data = $self->soap('client','get',$params->{client_id});
                  if ($data) {
                    $params->{room}=$data->{room};
                    $params->{building}=$data->{building};
                    $params->{street_id}=$data->{street_id};
                    $params->{street}=$data->{street};
                    print "$data->{name}\n";
                    return 1;
                  } else {
                    print "Нет такого клиента\n";
                    return undef;
                  }
                }
               };
  }
  return $self->{shell}->
    Question('host',\@a,$p);
}

sub CMD_attach_host {
  my ($self,$p)=@_;
  my $p  = $self->strToHash($p);
  fatal("Не указан хост (host_id)") unless $p->{host_id};
  fatal("Не указан клиент (client_id)") unless $p->{client_id};
  my $res = $self->soap('host','attach',$p->{host_id},$p->{client_id},$p->{date},$p->{comment});
#  print join(',',%$res);
#  print "Результат: $res\n"
#    if $res;
  return $res;
}

sub CMD_create_host {
  my ($self,$p) = @_;
  my $p  = $self->strToHash($p);
  print "Создание нового хоста:\n";
  # TODO Сделать чтобы клиент создавался автоматически если параметры указаны со строки
  $p=$self->questhost($p,1) || return undef;
  $p->{am_name}='deactive';
  my $id = $self->soap('host','create',$p);
  unless ($id) {
    print "Ошибка создания хоста.";
    return 1;
  }
#   if ($client_id) {
#     print "Присоединяю к абоненту: $client_id\n";
#     my $res = $self->soap('host','attach',$id,$client_id);
#   }
  print "Создан хост $id\n";
}


sub questvpnhost {
  my ($self,$p,$is_new) = @_;
  my @a = (
                     # TODO Проверять логин на уникальность
                     {key=>'hostname',name=>'Логин',obligated=>1,
                      pre=>sub {return $_[2];},
                      _pre=>sub { return $_[2] if defined $_[2];}
                     },
                     {key=>'password',name=>'Пароль',obligated=>1},
                     {key=>'host',name=>'IP',obligated=>1,
                      pre=>sub {
                        my $params = shift;
                        return $_[2]->{host} if $_[2]->{host};
                        return $self->soap('router','get_next_free_ip',36); # TODO router_id
                      }},
                     #                     {key=>'mac',name=>'MAC',obligated=>0},
#                     {key=>'hostname',name=>'hostname',obligated=>1},
                      {key=>'am_name',name=>'Включение',obligated=>1,
                       pre=>sub { return $_[2] if defined $_[2]; return 'deactive';},
                       post=>sub {
                         my $params=shift;
                         return $params->{am_name}
                           if $params->{am_name} eq 'active'
                             || $params->{am_name} eq 'deactive';
                         return undef;
                       }
                      },
                     {key=>'comment',name=>'Коментарий'}
          );
  if ($is_new) {
    unshift @a,{key=>'client_id',name=>'Клиент',obligate=>'1',
                post=>sub {
                  my $params = shift;
                  return 1 unless $params->{client_id};
                  print "Ищу клиента - ";
                  my $data = $self->soap('client','get',$params->{client_id});
                  if ($data) {
                    print "$data->{name}\n";
                    return 1;
                  } else {
                    print "Нет такого клиента\n";
                    return undef;
                  }
                }
               };
  }
  return $self->{shell}->
    Question('host',\@a,$p);
}


sub CMD_create_vpn_host {
  my ($self,$p) = @_;
  my $p  = $self->strToHash($p);
  print "Создание нового хоста:\n";
  # TODO Сделать чтобы клиент создавался автоматически если параметры указаны со строки
  $p=$self->questvpnhost($p,1) || return undef;
  $p->{router_id}=36;
  $p->{mac}=$p->{hostname};
  $p->{am_type}='common';
#  $p->{am_name}='deactive';
  $p->{janitor_id}=3;
  $p->{is_vpn}=1;
  $p->{am_name}='deactive';
  my $id = $self->soap('host','create',$p);
  unless ($id) {
    print "Ошибка создания хоста.";
    return 1;
  }
#   if ($p->{client_id}) {
#     print "Присоединяю к абоненту: $p->{client_id}\n";
#     my $res = $self->soap('host','attach',$id,$p->{client_id});
#   }
  print "Создан хост $id\n";
}


sub CMD_modify_host {
  my ($self,$id,$p) = @_;
  my $p  = $self->strToHash($p);
  my $data = $self->soap('host','get',$id);
  unless ($data) {
    print "Нет такого хоста\n";
    return 1;
  }
  foreach (keys %$data) {
    $data->{$_}=$p->{$_}
      if exists $p->{$_};
  }

  if ($data->{is_vpn}) {
    print "Изменение VPN соединения:\n";
    $p=$self->questvpnhost($data) || return undef;
    delete $p->{password} unless $p->{password};
    $p->{router_id}=36;
    $p->{mac}=$p->{hostname};
    $p->{am_type}='common';
    #  $p->{am_name}='deactive';
    $p->{janitor_id}=3;
    $p->{is_vpn}=1;
  } else {
    print "Изменение хоста:\n";
    $p=$self->questhost($data) || return undef;

  }


  if ($self->soap('host','modify',$id,$p)) {
    print "OK\n"; return 0;
  } else {
    print "Ошибка\n";  return 1;
  }
}


sub quest_delete_host {
  my ($self,$p) = @_;
  my @a = (
           {
            key=>'quest',name=>'Вы уверены что хотите удалить этот хост? (уверен)',obligated=>1,
           },
          );
  return $self->{shell}->Question('delete_host',\@a,{});
}


sub CMD_delete_host {
  my ($self,$id,$p) = @_;
  my $p  = $self->strToHash($p);
  my $data = $self->soap('host','get',$id);
  unless ($data) {
    print "Нет такого хоста\n";
    return 1;
  }
  $self->ShowHost($data);
  my $p = $self->quest_delete_host($data) || return undef;
  if ($p->{quest} eq 'уверен') {
    if ($self->soap('host','delete',$id)) {
      print "Хост удален\n"; return 0;
    } else {
      print "Ошибка удаления\n";  return 1;
    }
  }
}


sub ShowHost {
  my ($self,$res) = @_;
  my $table = Text::FormatTable->new('r | l');
  $table->rule('=');

  if ($res->{is_vpn}) {
    $table->row('VPN CONNECTION',$res->{host});
    $table->row('Login',$res->{mac});
  } else {
    $table->row('HOST',$res->{host});
    $table->row('MAC',$res->{mac});
    $table->row('hostname',$res->{hostname});
    $table->row('Адрес',$res->{address});
  }

  $table->row('Роутер',$res->{router});
  $table->row('Зарегистрировал менеджер',ref($res->{manager}) ? $res->{manager}->{name} : 'не установлен');
  $table->row('Доступ',$res->{is_active} ? 'есть' : 'НЕТ');
  $table->row('Привратник',$res->{janitor});
  $table->row('Привратник обновлен',$res->{am_time} || 'Требует обновления');
  if ($res->{current_speed}) {
    $table->row('Скорость',$res->{current_speed});
    $table->row('Ночной режим',$res->{is_night_mode} ? 'Активен' : 'нет');
    $table->row('Пороговое ограничение',$res->{is_limited} ? 'Достигнуто' : 'Не достигнуто');
  } else {
    $table->row('Скорость','неограничена');
  }

  $table->row('Абонент',"[$res->{client_id}] $res->{client}")
    if $res->{client};
  $table->rule('-');
  $table->row('Создан',$res->{createtime});
#  $table->row('Первый трафик',$res->{firstwork_time});
  $table->row('Последний трафик',$res->{lastwork_time});
  $table->rule('-');
  $table->row('Коментарий',$res->{comment})
    if $res->{comment};
  $self->showTable($table);

}

sub CMD_show_host {
  my ($self,$p) = @_;
  # TODO Если по таким праметрам находится несколько хостов - выводить их всех по очереди
  my $res = $self->soap('host','get',$p);
  $self->ShowHost($res);
  if ($res->{attaches} && @{$res->{attaches}}>1) {
    print "\nЖурнал присоединений\n";
    my $table = Text::FormatTable->new('r | l');
    $table->rule('=');
    $table->row('Дата','Клиент');
    $table->rule('=');
    foreach (@{$res->{attaches}}) {
      $table->row($_->{changetime},"#$_->{client_id}");
    }

    $self->showTable($table);
  }

  if ($res->{log} && @{$res->{log}}) {
    print "\nЖурнал Изменений\n";
    my $table = Text::FormatTable->new('r | l | l');
    $table->rule('=');
    $table->row('Дата','Менеджер','Изменения');
    $table->rule('=');
    foreach (@{$res->{log}}) {
      $table->row($_->{timestamp},$_->{manager}->{name},$_->{text});
    }

    $self->showTable($table);
  }

  return 0;
}

sub CMD_activate_host {
  my ($self,$id) = @_;
  my $res = $self->soap('host','get',$id);
  unless ($res) {
    print "нет такого хоста\n";
    return;
  }
  print "Включаю хост $res->{hostname} ($res->{host}):";
  $self->soap('host','modify',$id,{is_active=>1});
  print "ok\n";
  return 0;
}

sub CMD_deactivate_host {
  my ($self,$id) = @_;
  my $res = $self->soap('host','get',$id);
  unless ($res) {
    print "нет такого хоста\n";
    return;
  }
  print "Отключаю хост $res->{hostname} ($res->{host}):";
  $self->soap('host','modify',$id,{is_active=>0});
  print "ok\n";
  return 0;
}



sub CMD_move_host {
  my $self = shift;
  my $p = $self->strToHash(@_);
  unless ($p->{building_id} && $p->{net}) {
    print "Недостаточно параметров. Должно быть > move_host building_id=?? net=??\n.Где [net] - номер сети из 10.100.net.*\n";
    return 0;
  }

  my $list = $self->soap('host','list',{building_id=>$p->{building_id}});
  print "Всего хостов:",scalar @$list,"\n";
  foreach my $data (@$list) {
    #,"10.100.$p->{net}.10","10.100.$p->{net}.250"
    print "Меняю у хоста [$data->{host_id}] $data->{host} подсеть ($p->{net}) ";
    if ($data->{router_id}==36) {
      print "Не меняем адрес на VPN соедениния\n";
      next;
    }
    unless ($data->{host}=~/^10\.100\./) {
      print "не подлежит замене - уникальный адрес: $data->{host}\n";
      next;
    }
    my $new_ip = $self->soap('router','get_next_free_ip',$data->{router_id},"10.100.$p->{net}.10");
    $data->{host}=$new_ip;
    if ($data->{hostname}=~/host_/) {
      $new_ip=~/\.(\d+)\.(\d+)$/;
      $data->{hostname}="host_$1_$2";
    }
    print "-> $data->{host} ($data->{hostname}) ";
    if ($self->soap('host','modify',
                    $data->{host_id},
                    {host=>$data->{host},
                     hostname=>$data->{hostname}})) {
      print "OK\n";
    } else {
      print "Ошибка\n";
    }
  }

}


1;
