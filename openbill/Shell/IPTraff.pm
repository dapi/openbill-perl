package openbill::Shell::IPTraff;
use strict;
use openbill::Shell;
use openbill::System;
use openbill::Utils;
use Number::Format qw(:subs);
use dpl::Error;
use dpl::Context;
use dpl::System;
use Text::FormatTable;
use Error qw(:try);
use openbill::Shell::Base;
use Exporter;
use vars qw(@ISA
            @EXPORT);
@ISA=qw(Exporter
        openbill::Shell::Base);


registerCommands('openbill::Shell::IPTraff',
                 {
                  show_traffic=>{},
                  update_traffic=>{},
                  check_database=>{},
                  check_traffic=>{},
                  show_virus_log=>{},
                  delete_old_traffic=>{},

                  list_log_shots=>{},
                  show_log_shot=>{},
                 });


sub CMD_show_traffic {
  my ($self,$p)=@_;
  $p=$self->strToHash($p);
  my %r;
  $r{date}=$p->{date} if $p->{date};#ParseDate($p->{date}) || fatal("Неверная дата")  if $p->{date};
  $p->{show_all}=1 unless defined $p->{show_all};
  $r{ip}=inet_aton($p->{ip}) if $p->{ip};
  $r{dip}=inet_aton($p->{dip}) if $p->{dip};
  $r{class}=$p->{class} if defined $p->{class};
  $r{client_id}=$p->{client_id} if $p->{client_id};
  $r{router_id}=$p->{router_id} if $p->{router_id};
  $r{host_id}=$p->{host_id} if $p->{host_id};
  if ($p->{month}) {
    $r{from_date}=ParseMonth($p->{month}) || fatal("Неверный месяц month");
    $r{to_date}=$r{from_date}+($r{from_date}->DaysInMonth()-1)*60*60*24;
  } else {
    $r{from_date}=ParseDate($p->{from_date}) || fatal("Неверная дата from") if $p->{from_date};
    $r{to_date}=ParseDate($p->{to_date}) || fatal("Неверная дата to") if $p->{to_date};
  }
  my @group = split(',',$p->{group});
  foreach (0..$#group) {
    if ($group[$_] eq 'date' || $group[$_] eq 'time' ||
        $group[$_] eq 'tariff_id' || $group[$_] eq 'is_unlim' ||
        $group[$_] eq 'is_firm' ||
        $group[$_] eq 'direction' || $group[$_] eq 'class' ||
        $group[$_] eq 'month' || $group[$_] eq 'ip' || $group[$_] eq 'dip') {
    } elsif ($group[$_] eq 'router') {
      $group[$_]='router_id';
    } elsif ($group[$_] eq 'host') {
      $group[$_]='host_id';
    } elsif ($group[$_] eq 'client') {
      $group[$_]='client_id';
    } else {
      fatal("Неизвестный параметр: $group[$_]");
    }
  }
  fatal("Не указан параметры для группировки") unless @group;
  # TODO Сейчас берётся трафик только у 1- сервиса
  my $traff = $self->soap('iptraff','traffic',1,\%r,[@group]);
  $self->
    showTable(
              ShowTraffic($self,$p,$traff,@group)
             );
}


sub CMD_list_log_shots {
  my $self = shift;
  my $p = shift;
  $p=$self->strToHash($p);
  my $list = $self->soap('iptraff','list_log_shots',$p);
  print "\nСписок снимков статистики\n";
  my $table = Text::FormatTable->new('r | l | l | l | l | l | l  | l ');
  $table->rule('=');
  $table->head('ID', 'Роутер', 'Дата файла', 'Загружено', 'Байт', 'За пределы', 'Удалён', 'iface');
  $table->rule('-');
  foreach (@$list) {
    $table->row($_->{shot_id},$_->{router_id},$_->{filetime},
                $_->{shottime},$_->{bytes},
                $_->{count_min}+$_->{count_max},$_->{is_removed} ? 'да' : 'нет',$_->{iface});
  }
  $table->rule('-');
  $self->showTable($table);
}

sub CMD_show_log_shot {
  my $self = shift;
  my $l = $self->soap('iptraff','get_log_shot',@_);
  my $table = Text::FormatTable->new('r | l');
#  $table->head('ID', 'Роутер');
  $table->rule('=');
  $table->row('ID',$l->{shot_id});
  $table->rule('-');
  $table->row('Роутер',$l->{router_id});
  $table->row('Файл',$l->{filename});
  $table->row('Дата файла',$l->{filetime});
  $table->row('Время загрузки', $l->{shottime});
  $table->row('Время от',$l->{minlogtime})
    if $l->{minlogtime};
  $table->row('Время до',$l->{maxlogtime})
    if $l->{maxlogtime};
  $table->row('Байт',FormatBytes($l->{bytes}));
  $table->row('Интерфейс',$l->{iface});
  $table->row('С роутера удалён?',$l->{is_removed} ? 'ДА' : 'нет, еще');
  $table->row('ПРЕДЕЛЫ с низу',$l->{count_min})
    if $l->{count_min};
  $table->row('ПРЕДЕЛЫ с верху',$l->{count_max})
    if $l->{count_max};
  $table->row('Коллектор',$l->{collector_id});
  $table->rule('=');
  $self->showTable($table);
}




sub CMD_update_traffic {
  my ($self,$max) = @_;
#  print "Обновляю информацию по трафику ($max): ";
  my $res = $self->soap('iptraff','updateTraffic',$max);
 # print "$res\n";
}

sub CMD_delete_old_traffic {
  my ($self,$p) = @_;
  # date = дата с которой удалять
  # force = действитльно удалять
  $p  = $self->strToHash($p);
  print "Удаляю статистику: ";
  my $res = $self->soap('iptraff','deleteTraffic',$p);
  print "$res\n";
}

sub CMD_check_database {
  my ($self,$id,$p) = @_;
  print "Проверка базы: ";
  my $res = $self->soap('iptraff','checkDatabase');
  print "$res\n";
}

sub CMD_check_traffic {
  my ($self,$p) = @_;
  print "Проверка трафика: ";
  my $p  = $self->strToHash($p);
  my %r;
  if ($p->{date}) {
    $r{date}=ParseDate($p->{date}) || fatal("Неверная дата");
  } elsif ($p->{month}) {
    $r{month}=ParseMonth($p->{month}) || fatal("Неверный месяц month ($p->{monthe})")
  } else {
    $r{date}=ParseDate('yesterday');
  }
  $r{clients}=$p->{clients};
  my $percent = $p->{percent} || 7;
  my $bytes = $p->{bytes} || 7*1024*1024;
  my $res = $self->soap('iptraff','checkTraffic',\%r);
  my $mb=0;
  my $prov_mb=0;
  my $per;
  my $tr = $p->{clients} ? 'Продали' : 'Потребили';
  foreach my $s (@$res) {
    print "Служба: $s->{service}, $s->{date}\n";
    my $table = Text::FormatTable->new('l | l | l | l | r | l ');
    $table->head('Роутер', $tr, 'Провайдер', 'Разница', '%', '');
    $table->rule('=');
    foreach my $t (sort {$a->{router_id} <=> $b->{router_id}} @{$s->{traff}}) {
      my $f;
      my $d;
      my $p;
      if ($t->{router_id} && $t->{prov_bytes}->{0}) {
        my $d = $t->{bytes}->{0}-$t->{prov_bytes}->{0};
        my $leak = 100*$d/$t->{prov_bytes}->{0};
        $f="LEAK!"
          if $leak<-$percent && $d<-$bytes;
        $p=round($leak,1)."%" if $leak;
      }
      $table->row($t->{router} ? "[$t->{router_id}] $t->{router}" : $t->{prov} || "prov:$t->{prov_router_id}",
                  FormatBytes($t->{bytes}->{0}),
                  FormatBytes($t->{prov_bytes}->{0}),
                  FormatBytes($t->{bytes}->{0}-$t->{prov_bytes}->{0}),
                  $p,
                  $f);
      $mb+=$t->{bytes}->{0};
      $prov_mb+=$t->{prov_bytes}->{0};
    }
    $table->row("ИТОГО:",
                FormatBytes($mb),FormatBytes($prov_mb),
                FormatBytes($mb-$prov_mb),'','');

    $self->showTable($table);
  }
}

sub CMD_show_virus_log {
  my ($self,$p) = @_;
  print "Проверка трафика: ";
  my $p  = $self->strToHash($p);
  my $date = $p->{date} ? ParseDate($p->{date}) || fatal("Неверная дата") : today();
  my $bytes_limit = $p->{bytes_limit} || 100000;
  print "Поиск вирусового трафика за $date, минимальный размер: ".FormatBytes($bytes_limit)."\n";
  my $res = $self->soap('iptraff','get_virus_log',$date);
  my $table = Text::FormatTable->new('l | l | l | l | l');
  $table->head('IP', 'Порт', 'Трафик', 'Пакетов', 'Записей');
  $table->rule('=');
  my ($bytes,$packets,$records);
  foreach my $t (@$res) {
    next if $t->{bytes} < $bytes_limit;
    $table->row($t->{ip},
                $t->{port},
                FormatBytes($t->{bytes}),
                $t->{packets},
                $t->{records});
    $bytes+=$t->{bytes};
    $packets+=$t->{packets};
    $records+=$t->{records};
  }
  $table->row("ИТОГО:",'*',
              FormatBytes($bytes),FormatBytes($packets),
              FormatBytes($records));

  $self->showTable($table);
}



sub ShowTraffic {
  my ($self,$p,$traff,@group) = @_;
  print "Трафика нет" unless $traff;
#  die Dumper($traff);
  my $table;
  die 'too many groups parameters' if @group>3;
  if (@group<2) {
    $table = Text::FormatTable->new(' r | l ');
  } elsif (@group>=2) {
    die "no statistics" unless ref($traff->{all}->{_possible_keys}->[0]);
    $table = Text::FormatTable->new(' r | '.join(' | ',map {"l"} sort keys %{$traff->{all}->{_possible_keys}->[0]}));
  }
#  $table->rule('-');
  if (@group==0) {
    $table->row('байт',FormatBytes($traff->{all}));
#    $table->rule('=');
    return  $table;
  } elsif (@group==1) {
    $table->head($group[0],'байт');
  } else {
    $table->head($group[0],map {showKey($self,$group[1],$_)} sort keys %{$traff->{all}->{_possible_keys}->[0]});
  }
  $table->rule('=');
  foreach my $k (sort {$a<=>$b} keys %$traff) {
    next if $k eq 'all';
    $table->row(Row($self,$traff,$k,@group));
  }
  $table->rule('-');
  $table->row(Row($self,$traff,'all',@group));
  return  $table;
}

sub Row  {
  my ($self,$traff,$k,@group) = @_;
  my @a = (showKey($self,$group[0],$k));
  my $t = $traff->{$k};
  if (@group==1) {
    push @a,defined $t ? FormatBytes($t) : '-';
  } elsif (@group==2) {
    my $pk = $traff->{all}->{_possible_keys};
    foreach (sort keys %{$pk->[0]}) {
      push @a,exists $t->{$_} ? FormatBytes($t->{$_}) : '-';
    }
  } elsif (@group==3) {
    my $pk = $traff->{all}->{_possible_keys};
    foreach my $r (sort keys %{$pk->[0]}) {
      push @a unless exists $t->{$r};
      push @a,join(' / ',map {exists $t->{$r}->{$_} ? FormatBytes($t->{$r}->{$_}) : '-'} sort keys %{$pk->[1]});
    }
  }
  return  @a;
}

sub showKey {
  my ($self,$key,$value) = @_;
  return 'ИТОГО' if $value eq 'all';
  if ($key eq 'ip') {
    return inet_ntoa($value);
  } elsif ($key eq 'router_id') {
    my $res = $self->soap('router','get',$value) || return "id:$value";
    return $res->{hostname};
  } elsif ($key eq 'dip') {
    return inet_ntoa($value);
  } elsif ($key eq 'client_id') {
    return '---' unless $value;
    my $res = $self->soap('client','get',$value);
    return $res  ? "[$value] $res->{client}" : "\#$value";
  } elsif ($key eq 'host_id') {
    return $value || '---';
    #    my $client = $value;
    #    return '['.$client->ID(1).'] '.$client->GetName();
  } else {
    return $value;
  }
}


1;
