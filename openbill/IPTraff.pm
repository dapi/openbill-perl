package openbill::IPTraff;
use strict;
use dpl::Error;
use dpl::Db::Filter;
use dpl::Db::Table;
use dpl::Db::Database;
use dpl::Log;
use dpl::Config;
use dpl::System;
use dpl::XML;
#use openbill::Client;
use openbill::Period;
use openbill::System;
use openbill::Host;
use dpl::Context;
use openbill::Router;
use openbill::Locker;
use openbill::Collector;
use openbill::Collector::LogShot;
use openbill::Collector::DayShot;
use openbill::Collector::MinutShot;
use openbill::Utils;
use openbill::Tariff;
use Error qw(:try);
use Exporter;
use vars qw(@ISA
            @EXPORT);

@ISA=qw(Exporter);

@EXPORT=qw(iptraff);


sub iptraff {
  my $self =  bless {}, 'openbill::IPTraff';
  $self->{name} = 'iptraff';
  return $self;
}

sub chargetable {
  my $self = shift;
  return table('charge:iptraff');
}

sub charge {                    #  Генерировать charge-records, сбрасывать все данные оп периоду и устанавливать необходимые данные по сервису
  my ($self,$period) = @_;
  logger()->debug("Считаю период ".$period->string());
  my $summa = 0;
  $self->SetNewPeriodStatus($period);
  my $clients = $self->GetNewTraffic($period) || return undef;
  foreach my $cid (sort keys %$clients) {
    my $client = openbill::Client::client($cid);
    #    print "cid:$cid," if setting('terminal');
    # TODO Откуда появляются клиенты (49-й к примеру). Активированные,
    # но без charge, в результате выдаёт "ERROR: ID для tariff не
    # определён"

    $summa+=$client->MakeCharge($period,$clients->{$cid});
  }
  return $summa;
}

sub newCharge {
  my ($self,$period) = @_;
  logger()->debug("Пересчитываю период ".$period->string());
  $self->SetNewPeriodStatus($period,1);
  $|=1 if setting('terminal');;
  print "Get new traffic " if setting('terminal');
  my $clients_traffic = $self->GetNewTraffic($period);
  print "ok\nGet tariffed clients " if setting('terminal');
  my $clients_tariffes = $period->CreateTariffesCache();
  print "ok\n" if setting('terminal');
#  my $clients_activations = $period->CreateActivationsCache();
  logger()->warn("Нового трафика нет") unless $clients_traffic;
  my $summa = 0;
  my %c;
  foreach my $cid (sort keys %$clients_tariffes) {
    print "." if setting('terminal');
    my $client = openbill::Client::client($cid);
    $summa+=$client->MakeCharge($period,$clients_traffic->{$cid},2);
#    delete $clients_activations->{$cid};
    delete $clients_traffic->{$cid};
    $c{$cid}=$client;
  }

  print "ok\nCheck active clients " if setting('terminal');
  my $sth = db()->Select("select * from client where is_active=1 ");
  while (my $a = db()->Fetch($sth)) {
    unless ($c{$a->{client_id}}) {
      my $s = "Нет снятия для активного клиента $a->{client_id}";
      logger()->error($s);
      print "$\n" if setting('terminal');
    }
  }
  my $co = keys %c;
  print "$co клиентов\n" if setting('terminal');
  #   if (%$clients_activations) {
  #     fatal("Существует активация для клиентов: ".join(',',keys %$clients_activations).' в то время как тарифы не установлены');
  #   }
  db()->Commit();
  if (%$clients_traffic) {
    fatal("Существует трафик для клиентов: ".join(',',keys %$clients_traffic).' в то время как тарифы не установлены');
  }
  return $summa;
}

sub CheckDatabase {
  my $self = shift;
  dayshot()->CheckDatabase();
  minutshot()->CheckDatabase();
  logshot()->CheckDatabase();
}

sub UpdateTraffic {
  my ($self,$max_files) = @_;
  #  my $lock = Locker('service','iptraff');
  $max_files = 100 unless $max_files;
  my $max_records = 30000;
  my $lock = Locker('traffic','write');

  openbill::Period::period()->LoadOrCreate(today());
  my $ms = minutshot();
  my $list_shots = logshot()->ListNewShots();
  my $count = @$list_shots;
  unless ($count) {
  	print "Нет снимков к обработке\n";
	return undef;
  }
  print "Всего к обработке ($list_shots->[0]->{shot_id} - $list_shots->[$#$list_shots]->{shot_id}) $count снимков пакетами по, максимум, $max_files файлов, $max_records записей\n\n";
  do {
  	my ($count,$date_from,$date_to,$shots)=(0,0,0,0);
	my $from_id = $list_shots->[0]->{shot_id};
  	my $to_id;
	do {
		my $a = shift @$list_shots;
		$count+=$a->{count};
		$date_from = $a->{minlogtime} if !$date_from || ($a->{minlogtime}<$date_from && $a->{minlogtime});
		$date_to = $a->{maxlogtime} if !$date_to || ($a->{maxlogtime}>$date_to && $a->{maxlogtime});
		$to_id=$a->{shot_id}; $shots++;
	} while (@$list_shots && $count+$list_shots->[0]->{count}<$max_records && $shots<$max_files);
  	my $ms = minutshot();
	print "\nМинутный снимок. Файлы: $date_from - $date_to, ($from_id - $to_id) $shots, записей: $count. ID = ";
	$ms->Create($from_id,$to_id,$date_from,$date_to);
	print $ms->ID();
        my $res = $ms->UpdateTraffic();
  } while (@$list_shots);
  print "\n";
  dayshot()->UpdateTraffic();
}

sub DeleteTraffic {
  my ($self,$p) = @_;
  my $minut_days=7;
  my $date_days=90;
  my $minut_date = today() - $minut_days*24*60*60;
  my $day_date = today() - $date_days*60*60*60;

#  my $l=logshot()->GetMinShotSinceDate($minut_date);

 # print "Удалять logshot начиная с: $l->{shot_id}, файл $l->{filetime}\n";
  my $minut_id = minutshot()->GetMinShotSinceDate($minut_date);
  my $day_id = dayshot()->GetMinShotSinceDate($day_date);
#  my $minutshot = minutshot()->Load($minut_id);
#  my $dayshot = dayshot()->Load($day_id);

  if ($p->{force}) {
    my $sd = filter('date')->ToSQL(today()-7*24*60*60);
    db()->Query("delete from manager_session where create_time<='$sd'");
    if ($day_id) {
      print "Удаляю дневню статистику:\n";
      db()->Query("delete from day_traffic where shot_id<=$day_id");
      db()->Query("delete from day_shot where id<=$day_id");
      print "ok\n";
    }
    if ($minut_id) {
      print "Удаляю минутную статистику:\n";
      db()->Query("delete from minut_traffic where shot_id<=$minut_id");
      db()->Query("delete from minut_shot where id<=$minut_id");
      print "ok\n";
    }
    db()->Commit();
  } else {
    print "Удаление отменено, не установлен флаг force (day_traffic - shot_id<=$day_id, minut_traffic - shot_id<=$minut_id)\n";
  }

  return 1;
}


sub CheckTraffic {
  my ($self,$p) = @_;
#  unless ($p->{date}) {
#    $p={date=>today()-1*24*60*60};
  #  }
  fatal("Можно указывать только month или date") if $p->{date} && $p->{month};
  my $clients;
  if ($p->{clients}) {
    $clients='client_id is not null and ';
  }
  if ($p->{date}) {
    my $date = filter('date')->ToSQL($p->{date});
    my $db = db();
    my $sth = $db->Select("select class, prov_router_id, sum(bytes) as bytes, router_id from prov_day_traffic join prov_router on prov_router.id=prov_day_traffic.prov_router_id where date='$date' group by prov_router_id, class order by prov_router_id ");

    my %provs;
    my %routers;
    my %prov_routers;

    while (my $r = $db->Fetch($sth)) {
      $provs{$r->{prov_router_id}}={} unless $provs{$r->{prov_router_id}};
      $provs{$r->{prov_router_id}}->{$r->{class}}=$r->{bytes};
      #    die "$r->{class} $r->{bytes}";
      $routers{$r->{router_id}}=$r->{prov_router_id};
      $prov_routers{$r->{prov_router_id}}=$r->{router_id};
    }
    my %traf;

    $sth = db()->Select("select class, router_id, sum(bytes) as bytes from day_traffic where $clients date='$date' group by router_id, class order by router_id ");
    while (my $r = $db->Fetch($sth)) {
      $traf{$r->{router_id}}={} unless $traf{$r->{router_id}};
      $traf{$r->{router_id}}->{$r->{class}}=$r->{bytes};
    }

    my @res_traf;
    foreach (keys %traf) {
      my $p = $routers{$_};
      my %h = (prov_bytes=>$provs{$p},
               bytes=>$traf{$_},
               router_id=>$_,
               router=>router($_)->string(),
               prov_router_id=>$p);
      $h{prov}=table('prov_router')->Load($p)->{name} if $p;
      delete $provs{$p};
      push @res_traf, \%h;
    }
    foreach (keys %provs) {
      my $rid = $prov_routers{$_};
      my %h = (prov_bytes=>$provs{$_},
               prov_router_id=>$_);
      if ($rid) {
        $h{router_id}=$rid;
        $h{router}=router($rid)->string();
      }
      $h{prov}=table('prov_router')->Load($_)->{name};
      push @res_traf, \%h
        if $provs{$_}->{0} || $provs{$_}->{1}; # TODO сделать проверку на все классы через функцию IsTraffic
    }
    return {date=>$p->{date},
            traff=>\@res_traf};
  } elsif ($p->{month}) {


    my ($from,$to) = PeriodFromDate($p->{month});
    my $from = filter('date')->ToSQL($from);
    my $to = filter('date')->ToSQL($to);
    my $db = db();
    my $sth = $db->Select("select class, prov_router_id, sum(bytes) as bytes, router_id from prov_day_traffic join prov_router on prov_router.id=prov_day_traffic.prov_router_id where date>='$from' and date<='$to' group by prov_router_id, class order by prov_router_id ");
    my %provs;
    my %routers;
    my %prov_routers;

    while (my $r = $db->Fetch($sth)) {
      $provs{$r->{prov_router_id}}={} unless $provs{$r->{prov_router_id}};
      $provs{$r->{prov_router_id}}->{$r->{class}}=$r->{bytes};
      #    die "$r->{class} $r->{bytes}";
      $routers{$r->{router_id}}=$r->{prov_router_id};
      $prov_routers{$r->{prov_router_id}}=$r->{router_id};
    }
    my %traf;

    $sth = db()->Select("select class, router_id, sum(bytes) as bytes from day_traffic where $clients date>='$from' and date<='$to' group by router_id, class order by router_id ");
    while (my $r = $db->Fetch($sth)) {
      $traf{$r->{router_id}}={} unless $traf{$r->{router_id}};
      $traf{$r->{router_id}}->{$r->{class}}=$r->{bytes};
    }

    my @res_traf;
    foreach (keys %traf) {
      my $p = $routers{$_};
      my %h = (prov_bytes=>$provs{$p},
               bytes=>$traf{$_},
               router_id=>$_,
               router=>router($_)->string(),
               prov_router_id=>$p);
      $h{prov}=table('prov_router')->Load($p)->{name} if $p;
      delete $provs{$p};
      push @res_traf, \%h;
    }
    foreach (keys %provs) {
      my $rid = $prov_routers{$_};
      my %h = (prov_bytes=>$provs{$_},
               prov_router_id=>$_);
      if ($rid) {
        $h{router_id}=$rid;
        $h{router}=router($rid)->string();
      }
      $h{prov}=table('prov_router')->Load($_)->{name};
      push @res_traf, \%h
        if $provs{$_}->{0} || $provs{$_}->{1}; # TODO сделать проверку на все классы через функцию IsTraffic
    }
    return {month=>$p->{month},
            date_from=>$from,
            date_to=>$to,
            traff=>\@res_traf};
  } else {
    fatal("No parameters for CheckTraffic");
  }
}

sub SetNewPeriodStatus {
  my ($self,$period,$do_reset)=@_;
  $period->Modify({dayshot_id=>0,season_date=>undef})
    if $do_reset;
  my $cur_id = dayshot()->GetLastID($period);
  my $d = $period->Data('end');
  $period->SetNewStatus({dayshot_id=>$cur_id, season_date=>$d});
}

sub GetClientsTraffic {
  my ($self,$period,$client) = @_;
  my $ds_id = $period->Data('dayshot_id');
  return undef unless $ds_id;
  my $cid = $client->ID();
  my $pid = $period->ID();
  my $start = filter('date')->ToSQL($period->Data('start'));
  my $end = filter('date')->ToSQL($period->Data('end'));
  my $sth = db()->
    Select(qq(select client_id, class, sum(bytes) as bytes
              from day_traffic where shot_id<=$ds_id
              and date>='$start' and date<='$end'
              and client_id=$cid group by class));
  #              and from_ym<='$start' and (to_ym<from_ym or to_ym>='$start')
  my %bytes;
  while (my $rec=$sth->fetchrow_hashref()) {
    $bytes{$rec->{class}}+=$rec->{bytes};
  }
  return \%bytes;
}

sub ChangeTrafficOwner {
  my ($self,$host,$client,$date_from,$date_to) = @_;
  my $ip = $host->Data('ip');
  my $rid = $host->Data('router_id');
  my $cid = $client->ID();
  my $df = filter('date')->ToSQL($date_from);
  my $dt = $date_to ? filter('date')->ToSQL($date_to) : undef;
  my $dts = $dt ? "date<='$dt'" : undef;
  #  db()->Query("update minut_traffic set client_id=$cid where router_id=$rid and ip=$ip and date>='$df' $dts");
  #db()->Query("update day_traffic set client_id=$cid where router_id=$rid and ip=$ip and date>='$df' $dts");
  db()->Commit();
}

sub GetNewTraffic {
  my ($self,$period) = @_;
  my $cur_id=$period->GetNewStatus()->{dayshot_id};
  return undef unless $cur_id;
  my $ds_id = $period->Data('dayshot_id');
  return undef if $ds_id==$cur_id;
  fatal("Обсчитаный снимок выше существующего!")
    if $ds_id>$cur_id;
  # TODO
  # Неизвестно что делать если снимок попадает по параметрам в указанные id и выходит по датам
  # Если пришёл снимок недельной давности,то пока будет делать, чтобы снимок при приходе
  # не устанавливался в дату из закрытого периода
  my $pid = $period->ID();
  my $start = filter('date')->ToSQL($period->Data('start'));
  my $end = filter('date')->ToSQL($period->Data('end'));
  my $ids = "shot_id<=$cur_id";
  $ids.=" and shot_id>$ds_id"  if $ds_id;
  my $sth = db()->
    Select(qq(select client_id, class, sum(bytes) as bytes
              from day_traffic where $ids
              and date>='$start' and date<='$end'
              group by client_id, class));
  #               and from_ym<='$start'  and (to_ym<from_ym or to_ym>='$start')
  my %clients;
  #  print "Тарификация: ";
  my %bytes;
  while (my $rec=$sth->fetchrow_hashref()) {
    next unless $rec->{client_id};
    $clients{$rec->{client_id}}={} unless $clients{$rec->{client_id}};
    $clients{$rec->{client_id}}->{$rec->{class}}+=$rec->{bytes};
    $bytes{$rec->{class}}+=$rec->{bytes};
  }
  my $a = db()->
    SelectAndFetchAll(qq(select sum(bytes) as bytes, class
                         from day_traffic where $ids and date>='$start' and date<='$end' group by class));

  foreach (@$a) {
    # TODO Выводить и высылать мылом список хостов которые неизвестно кому принадлежат
    logger()->warn("Не весь трафик определён по клиентам (класс: $_->{class}) $_->{bytes}>$bytes{$_->{class}}")
      unless $_->{bytes}==$bytes{$_->{class}};
  }
  #TODO Неопознанные хосты
  #Сделать таблицу своих хостов (роутеров и тп)
  return \%clients;
}

sub GetUnit {
  return 'байт';
}

sub GetTraffic {
  # TODO Ввести параметр sort
  # TODO Ограничить снизу и взять day_shot.actshot_id
  my ($self,$r,$group) = (shift,shift,shift);
  my $key = $group->[0];
  die 'error' if $r->{period};
  fatal("Слишком много парметров для группировки") if @$group>3;
  fatal("Нельзя указывать в качестве ограничителя одновременно клиента и ip")
    if $r->{ip} && $r->{client_id};
  fatal("Нельзя указывать в качестве ограничителя одновременно клиента и host_id")
    if $r->{host_id} && $r->{client_id};
  if ($r->{month}) {
    fatal("Указаны from или to, когда указан month")
      if $r->{from_date} || $r->{to_date};
    ($r->{from_date},$r->{to_date}) = PeriodFromDate($r->{month});
  }
  fatal("Указанная дата ($r->{date}) не входит в указанный период $r->{from_date} - $r->{to_date}")
    if (defined $r->{date} &&
        ((defined $r->{from_date} && $r->{from_date}>$r->{date}) or (defined $r->{to_date} && $r->{to_date}<$r->{date})));
  fatal("from старше чем to")
    if $r->{from_date} && $r->{to_date} && $r->{from_date}>$r->{to_date};
  my $dtable = 'day_traffic';
  my $need_host;
  foreach (@$group) {
    if ($_ eq 'time' || $_ eq 'direction' || $_ eq 'dip') {
      $dtable='minut_traffic';
#      last;
    }
    if ($_ eq 'host_id') {
      $need_host=1;
 #     last;
    }
  }
  if ($r->{direction}) {
    fatal("Неверное значение параметра direction: '$r->{direction}'. Должно быть in или out")
      unless $r->{direction} eq 'in' || $r->{direction} eq 'out';
    $dtable='minut_traffic';
  }
  $dtable='minut_traffic' if $r->{dip};

  #  if ($dtable eq 'minut_traffic') {
  #    if ($shot_id) {
  #      my $res = dayshot()->Load($shot_id) || fatal("Ненайден дневной снимок");
  #      $shot_id=$res->{last_mshot_id};
  #    }
  #  }

  my @keys;
  my @select;
  my %group;
#  my ($gc,$gt)=@_;
  foreach (@$group) {
    fatal("Нельзя группировать по ограничивающему параметру ($_)")
      if defined $r->{$_};
    if ($_ eq 'router_id' || $_ eq 'date' ||
        $_ eq 'time' || $_ eq 'class' || $_ eq 'host_id'
        || $_ eq 'direction') {
      push @keys,$_;
      push @select,$_;
    } elsif ($_ eq 'ip') {
      push @keys,"$dtable.ip" ;
      push @select,"$dtable.ip";
    } elsif ($_ eq 'client_id') {
      push @keys,"$dtable.client_id" ;
      push @select,"$dtable.client_id";
    } elsif ($_ eq 'dip') {
      push @keys,"$dtable.dip" ;
      push @select,"$dtable.dip";
    } elsif ($_ eq 'router') {
      push @keys,'router_id' ;
      push @select,'router_id';
    } elsif ($_ eq 'month') {
      push @keys,'extract(year_month from date)' ;
      push @select,'extract(year_month from date) as month' ;
    } elsif ($_ eq 'is_unlim') {
#      $gu=1;
    } elsif ($_ eq 'is_firm') {
 #     $gf=1;
    } elsif ($_ eq 'tariff_id') {
      #$gt=1;
      #      push @keys,'extract(year_month from date)' ;
      #push @select,'extract(year_month from date) as month' ;
    } else {
      fatal("Неизвестный параметр для группировки: $_");
    }
    $group{$_}=1;
  }
  if ($group{tariff_id} || $group{is_firm} || $group{is_unlim}) {
    unless ($group{client_id}) {
      push @keys,"$dtable.client_id" ;
      push @select,"$dtable.client_id";
    }
    fatal("При группировке по tariff_id и is_unlim необходимо устанавливать фильтр date, month или from_date или включить в группировку date")
      unless $r->{date} || $r->{from_date} || $group{date};
  }
  my $select = join(', ',@select, 'sum(bytes) as bytes');
  my $group_by = @keys ? 'group by '.join(', ',@keys) : '';
  my @w;
  $r->{from_date} = filter('date')->ToSQL($r->{from_date}) if $r->{from_date};
  $r->{to_date} = filter('date')->ToSQL($r->{to_date}) if $r->{to_date};
  push @w,"$dtable.date='".filter('date')->ToSQL($r->{date})."'" if defined $r->{date};
  if ($r->{client_id} eq 'no') {
    push @w,"$dtable.client_id is null";
  } elsif ($r->{client_id} eq 'yes') {
    push @w,"$dtable.client_id is not null";
  } elsif ($r->{client_id}) {
    push @w,"$dtable.client_id=$r->{client_id}";
  }
  my $lj;
  if ($r->{host_id} eq 'no') {
    die 'not implemented where host_id is no';
  } elsif ($r->{host_id} || $need_host) {
    $lj="left join host on host.ip=$dtable.ip";
  }

  push @w,"$dtable.ip=$r->{ip}" if $r->{ip};
  push @w,"dip=$r->{dip}" if $r->{dip};
  push @w,"host_id=$r->{host_id}" if $r->{host_id};
  push @w,"$dtable.date>='$r->{from_date}'" if $r->{from_date};
  push @w,"$dtable.date<='$r->{to_date}'" if $r->{to_date};
  push @w,"direction=$r->{direction}" if $r->{direction};
  push @w,"$dtable.class=$r->{class}" if defined $r->{class};
  push @w,"$dtable.router_id=$r->{router_id}" if $r->{router_id};
  #  push @w,"$dtable.period_id=$pid" if defined $r->{period};
  my $cw="where ".join(' and ',@w) if @w;
  #  $cw = ", host $cw" if $r->{client_id} || $group{client_id};
  my $q = "select $select from $dtable $lj $cw $group_by";
  my $sth = db()->Select($q);
  my %traffic;
  my $t=\%traffic;
  foreach (@$group) {
#    $t->{all}={};
    $t=$t->{all};
  }
  my %groups;
  my @possible_keys=@$group>1 ? map {{}} (0..$#$group-1) : ();
  my %cache;
  
  while (my $rec=$sth->fetchrow_hashref()) {
    unless (@$group) {
      $traffic{all}+=$rec->{bytes};
      die "Нет группировки";
      next;
    }
    #    my $t = \%traffic;
    my @d = (\%traffic);
    ($rec->{tariff_id})
      = getCharge(\%cache,$rec->{client_id},$rec->{date} || $r->{date} || $r->{from_date})
        if $group{tariff_id} || $group{is_unlim};
    ($rec->{is_unlim})
      = getTariff(\%cache,$rec->{client_id},$rec->{date} || $r->{date} || $r->{from_date})
        if $group{is_unlim};
    ($rec->{is_firm})
      = getClient(\%cache,$rec->{client_id})
        if $group{is_firm};
    foreach my $i (0..$#$group) {
      my $k = $group->[$i];
      my $v = $rec->{$k};
      $possible_keys[$i-1]->{$v}=1 if $i;
      if ($i==$#$group) {
        foreach (@d) {
          $_->{$v}+=$rec->{bytes};
          #          print "$_->{all}+$rec->{bytes}=$_->{all}\n";
          $_->{all}+=$rec->{bytes};
        }
      } else {
        my @a;
        foreach (@d) {
          $_->{$v}={} unless exists $_->{$v};
          $_->{all}={} unless exists $_->{all};
          push @a,$_->{$v},$_->{all};
        }
        @d=@a;
      }
    }
  }
  $traffic{all}->{_possible_keys}=\@possible_keys
    if @$group>1;
  return \%traffic;
}

sub getClient {
  my ($cache,$client_id) = @_;
  return undef unless $client_id;
  my $client = $cache->{clients}->{$client_id};
  unless ($client) {
    $client = db()->
      SelectAndFetchOne("select * from client where client_id=$client_id")
        || fatal("нет такого тарифа $client_id");
    $cache->{clients}->{$client_id}=$client;
  }
  return ($client->{is_firm});
}  

sub getTariff {
  my ($cache,$client_id,$month) = @_;
  return undef unless $client_id;
  my ($tariff_id) = getCharge($cache,$client_id,$month);
  return undef unless $tariff_id;
  my $tariff = $cache->{tariffes}->{$tariff_id};

  unless ($tariff) {
    $tariff = db()->
      SelectAndFetchOne("select * from tariff where id=$tariff_id")
        || fatal("нет такого тарифа $tariff_id");
    $cache->{tariffes}->{$tariff_id}=$tariff;
  }
  return ($tariff->{is_unlim});
}

sub getCharge {
  my ($cache,$client_id,$month) = @_;
  return undef unless $client_id;
  $month=~s/^(\d+)-(\d+).+$/$1-$2-01/;
  my $period = $cache->{periods}->{$month};
  unless ($period) {
    $period = db()->
      SelectAndFetchOne("select * from period where start=\"$month\"")
        || fatal("нет такого периода $month");
    $cache->{periods}->{$month}=$period;
    $period->{clients}={};
  }
  unless ($period->{$client_id}) {
    $period->{$client_id}=db()->
      SelectAndFetchOne("select * from charge where period_id=$period->{id} and client_id=$client_id")
        || {};
  }
  return ($period->{$client_id}->{tariff_id});
}

sub UpdateActivation {
  my ($self,$client,$is_active,$date,$comment) = @_;
  my $hosts = $client->GetHosts();
  foreach my $h (@$hosts) {
    $h->SetAccessMode($is_active ? 'active' : 'deactive',
                      $date,$comment);
  }
}



###############################
#
# Работа с трафиком
#
###############################






################################
#
# Старые процедуры
#
################################

sub DeleteLog {
  my ($self,$days) = @_;
  my $date = filter('date')->ToSQL(today()-$days*24*60*60);
  my $a = db()->SelectAndFetchOne(qq(select max(last_ushot_id) as id
                                     from minut_shot));
  logshot()->DeleteOld($a->{id},$date)
    if $a && $a->{id};
}




sub TruncateStats {
  my $self = shift;
  my $collectors = $self->List();
  my %d=(collectors=>0);
  logger()->info("Удаляю базу статистики.");
  foreach (@$collectors) {
    $_->DeleteStats();
  }
  db()->Query('truncate table minut_shot');
  db()->Query('truncate table minut_traffic');
  db()->Query('truncate table day_traffic');
  db()->Query('truncate table day_shot');
}

sub DeleteLogs {
  my ($self,$date) = @_;
  my $collectors = $self->List();
  #TODO
  # парсить дату и преедавать уже объект

  logger()->info("Удаляю логи старше $date.");
  foreach (@$collectors) {
    $_->DeleteLogs($date);
  }
}

1;
