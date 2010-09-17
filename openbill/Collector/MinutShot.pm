package openbill::Collector::MinutShot;
use strict;
use openbill::Host;
use openbill::Base;
use openbill::System;
use openbill::Period;
use openbill::Router;
use openbill::Collector::LogShot;
use openbill::Utils;
use openbill::Locker;
use dpl::System;
use dpl::Context;
use dpl::Log;
use dpl::Db::Table;
use dpl::Db::Database;
use dpl::Db::Filter;
use dpl::Error;
use Error qw(:try);
use Exporter;
use vars qw(@ISA
            @EXPORT);

@ISA=qw(Exporter
        openbill::Base);

@EXPORT=qw(minutshot);

sub minutshot {
  return openbill::Collector::MinutShot->instance('minut_shot',@_);
}

sub GetMinShotSinceDate {
  my ($self,$date) = @_;
  $date=filter('date')->ToSQL($date);
  my $res = db()->SelectAndFetchOne("select min(id) as id from minut_shot where dfrom>='$date'");
  return $res ? $res->{id} : undef;
}

sub GetMinShotFromLogShot {
  my ($self,$log_shot_id) = @_;
  return db()->SelectAndFetchOne("select min(id) as id from minut_shot where to_ushot_id>=$log_shot_id")->{id};
}

sub string {
  my $self = shift;
  return $self->Data('id');
}

sub CheckDatabase {
  my $self = shift;
  my $db = db();
  my $count = $db->SelectAndFetchOne('select count(*) as count, max(id) as max from minut_shot');
  print "Проверка минутной базы ($count->{count}/$count->{max})\n" if setting('terminal');
  my $m_sth = $db->Select('select * from minut_shot order by id desc');
  my $i;
  while (my $a=$db->Fetch($m_sth)) {
    my $res = $db->SelectAndFetchOne("select sum(bytes) as bytes from log_shot where shot_id>=$a->{from_ushot_id} and shot_id<=$a->{to_ushot_id}");
    $i++;
    print "\r$i" if setting('terminal');
    unless ($res->{bytes}==($a->{bytes}+$a->{lost_bytes})) {
      print "\nСнимок $a->{id} ($a->{dfrom} - $a->{dto}/$a->{shottime}, $a->{from_ushot_id} - $a->{to_ushot_id}) имеет неверный трафик - $a->{bytes} + $a->{lost_bytes} <> $res->{bytes}\n";
    }
  }
  $m_sth->finish();
  print "\n";
  return 1;
}

sub Create {
  my ($self,$from_id,$to_id,$dfrom,$dto) = @_;
  $self->DeleteBroken();

  $self=$self->SUPER::Create({shottime=>undef,
                              dfrom=>$dfrom,
                              dto=>$dto,
                              from_ushot_id=>$from_id,
                              to_ushot_id=>$to_id,
                             });
  fatal("Internal no self in minut shot create") unless $self;
  fatal("В статистике есть данные из будущего - $dto. ($from_id-$to_id)")
    if $dto>today()+setting('today_plus');
  $self->{is_open}=1;
  return $self;
}

sub GetLastProcessedUshotID  {
  my $self = shift;
  my $h = db()->SelectAndFetchOne('select max(to_ushot_id) as last from minut_shot where shottime is not null');
  return $h->{last};
}

sub GetShotsInfo {
  my ($self,$from_id) = @_;
  my $h = db()->SelectAndFetchOne('select min(id) as min from minut_shot where shottime is null');
  my $w;
  $w=" and id<$h->{min}" if $h->{min};
  $w.=" and id>$from_id" if $from_id;
  $h = db()->
    SelectAndFetchOne(qq(select max(id) as max, count(id) as count from minut_shot where shottime is not null $w));
  return ($h->{max},$h->{count});
}


sub GetBytes {
  my ($self,$router) = @_;
  my $from = $self->Data('from_ushot_id');
  my $last = $self->Data('to_ushot_id');
  my $id = $self->ID();
  my $rid = $router->ID();
  my $a = db()->SelectAndFetchOne("select sum(bytes) as bytes from minut_traffic where shot_id=$id and router_id=$rid");
  unless (defined $a->{bytes}) {
    logger()->warn("minut_traffic пустой");
    $a->{bytes}=0;
  }
  my $b = db()->SelectAndFetchOne("select sum(bytes) as bytes from log_shot where shot_id>=$from and shot_id<=$last and router_id=$rid");
  my ($bytes,$lost)=($a->{bytes},$b->{bytes}-$a->{bytes});
  my $b = FormatBytes($bytes,1);
  my $l = FormatBytes($lost,1);
  if (setting('terminal')) {
    print "$b байт";
    print " (неопределено (minut - shot_id=$id): $l байт)" if $l;
    print "\n";
  }
  logger()->warn("Есть не определённый траффик: $lost. minut_shot_id=".$self->ID())
    if $lost;
  return ($bytes,$lost);
}

sub Close {
  my ($self,$bytes,$lost) = @_;
  my $l = $lost ? ", неопределено: ".$lost : '';
  logger()->debug("Минутный снимок (".$self->Data('from_ushot_id')."-".$self->Data('to_ushot_id')
                  ."), всего: $bytes байт ".$l);

  #print "Определяю ночной и валентско-феврельско-мартовский праздничный бесплатный трафик: ";
  print "Определяю ночной трафик";
  startTimer('night');
  db()->Query("update minut_traffic set class=class+10 where class=0 and shot_id=? and (time>='21:00' or time<'08:00')",$self->ID());
  
  
  ## 20-й класс ночной траффик в день валентина
  #db()->Query("update minut_traffic set class=20 where class=10 and shot_id=?  and ( (time>='21:00' and date='2008-02-14') or (time<'08:00' and date='2008-02-15'))",$self->ID());
  ## 20-й класс 23 февраля 2008
  #db()->Query("update minut_traffic set class=20 where class=10 and shot_id=?  and ( (time>='21:00' and date='2008-02-23') or (time<'08:00' and date='2008-02-24'))",$self->ID());
  ## 20-й класс 8 марта
  #db()->Query("update minut_traffic set class=20 where class=10 and shot_id=?  and ( (time>='21:00' and date='2008-03-08') or (time<'08:00' and date='2008-03-09'))",$self->ID());
 
  my $t = stopTimer('night') || 0;
  print " $t секунд.\n";
  db()->Query('update minut_shot set shottime=now(), bytes=?, lost_bytes=? where id=?',
              $bytes,$lost,$self->ID());
  $self->updateHostInfo();
  $self->updateRouterInfo();
  print "Удаляю traflog статистику ".$self->Data('from_ushot_id')."-".$self->Data('to_ushot_id')."\n";
  openbill::Collector::LogShot::logshot()->DeleteOldTraffic($self->Data('from_ushot_id'),$self->Data('to_ushot_id'));
  db()->Commit();
  $self->{is_open}=0;
#  $self->DeleteOldTraffic(14);
}

sub DeleteIfBroken {
  my $self = shift;
  if ($self->{is_open}) {
    db()->Query("delete minut_traffic from minut_traffic, minut_shot where minut_shot.id=minut_traffic.shot_id and minut_shot.id=".$self->ID());
    db()->Query("delete minut_shot from minut_shot where id=".$self->ID());
    #  db()->Commit();
  }
}

sub Delete {
  die 'not implemented';
}

sub updateHostInfo {
  my $self = shift;
  startTimer('host_info');
  my $id = $self->ID();
  print "Обновляю дату последнего трафика по хостам ($id): ";
  if ($id) {
    my $sth =  db()->
      Query('select max(datetime) as last_date, ip from minut_traffic where shot_id=? group by ip',
            $self->ID());

    while ($_=$sth->fetchrow_hashref()) {
      next unless $_->{last_date};
      db()->Query(qq(update host set
                   lastwork_time=?
                   where ip=? and (lastwork_time<? or lastwork_time is null)),
                  $_->{last_date},
                  $_->{ip},
                  $_->{last_date});
    }
    $sth->finish();

    my @clients;
    print "Обновляю дату последнего трафика по клиентам ($id): ";
    my $sth =  db()->
      Query('select max(datetime) as last_date, client_id from minut_traffic where shot_id=? group by client_id',
            $self->ID());
    while ($_=$sth->fetchrow_hashref()) {
      next unless $_->{last_date};
 #     print "client:$_->{client_id} - $_->{last_date}\n";
      db()->Query(qq(update client set
                   lastwork_time=?
                   where client_id=? and (lastwork_time<? or lastwork_time is null)),
                  $_->{last_date},
                  $_->{client_id},
                  $_->{last_date});
    }
    $sth->finish();

  } else {
    print "нет снимка ";
  }
  my $t = stopTimer('host_info');
  print "$t\n";
}

sub updateRouterInfo {
  my $self = shift;
  # TODO
  startTimer('router_info');
  print "Обновляю дату последнего трафика по роутерам: ";
  if ($self->ID()) {
    my $sth =  db()->
      Query('select max(datetime) as last_date, router_id
                         from minut_traffic where
                         shot_id=? group by router_id',
             $self->ID());
    while ($_=$sth->fetchrow_hashref()) {
      db()->Query(qq(update router set
                   lastwork_time=?
                   where router_id=?),
                  $_->{last_date},$_->{router_id});
    }
    $sth->finish();
  } else {
    print "нет снимка ";
  }
  my $t = stopTimer('router_info');
  print "$t\n";
}

sub DeleteBroken {
  my ($self)=@_;
  db()->Query('delete minut_traffic from minut_traffic, minut_shot where minut_shot.id=minut_traffic.shot_id and shottime is null');
  db()->Query('delete minut_shot from minut_shot where shottime is null');
#  db()->Commit();
}


sub UpdateTraffic {
  my ($mshot) = @_;
  my $db=db();
  #logshot()->DeleteBroken();
  # TODO Реальное определение колличесов снимков для вставки для управления через max?
  # TODO устанавливать act=-1 если его нет

  return try {
    #    my $period = period()->LoadByDate($self,$dfrom);
    my ($dfrom,$dto)=$mshot->Data('dfrom'),$mshot->Data('dto');
    my $periods = openbill::Period::period()->List($dfrom,$dto);
    #TODO проверить както на то, что все  приоды существуют
    # может в статистике  есть даты из несуществующих периодов
    fatal("Ненайден ни один период для обновления минутной статистики ($dfrom> X <=$dto)")
      unless @$periods;
    foreach my $p (@$periods) {
      fatal("Один из периодов для обновления минутной статистики закрыт ($dfrom> X <=$dto)".$p->ID())
        unless $p->IsOpen();
    }
    # TODO Вставлять каждый log_shot отдельно
    my ($from,$to)=($mshot->Data('from_ushot_id'),$mshot->Data('to_ushot_id'));
    my $rs = db()->
      SelectAndFetchAll(qq(select router_id from log_shot
                           where shot_id>=$from and shot_id<=$to group by router_id),
                       );
    my @routers = map {router($_->{router_id})} @$rs;
    my ($bytes,$lost_bytes)=0;
    print "\n";
    foreach my $r (@routers) {
      InsertLog($mshot->ID(),$from,$to,$r);
#      SetClients($mshot->ID());
      my ($b,$lost) = $mshot->GetBytes($r);
      if ($lost) {
        my ($tl,$fl) = DumpLostTraffic($mshot,$r);
        unless ($lost==$tl) {
          my $s = $mshot->ID().": Потерянные байты не совпадают с выведенными ($lost<>$tl -> $fl)";
          logger()->warn($s);
          print STDERR "$s\n"
        }
      }
      $bytes+=$b;
      $lost_bytes+=$lost;
      # TODO Обновлятьстатистику по router-у здесь, а не в Close
    }
    $mshot->Close($bytes,$lost_bytes);
    return $to-$from+1;
  } otherwise {
    $mshot->DeleteIfBroken();
    my $e = shift;
    $e->throw();
    return 0;
  };
  return 0;
}

sub SetClients {
  my $id = shift;
  my $list = db()->SelectAndFetchAll("select ip, router_id from minut_traffic where shot_id=$id group by ip, router_id");
  foreach my $i (@$list) {
    my $cid  = FindClient($i->{ip},$i->{router_id}) || next;
    db()->Query("update minut_traffic set client_id=$cid where shot_id=$id and ip=$i->{ip} and router_id=$i->{router_id}");
  }
}

sub GetHost_fake {
  my ($ip,$rid) = @_;
  my $a = db()->SelectAndFetchOne('select client_id from host where ip=$ip >> bits and router_id=$rid');
  return $a && %$a ? $a->{client_id} : undef;
}

sub DumpLostTraffic {
  my ($mshot,$router) = @_;
  my $from = $mshot->Data('from_ushot_id');
  my $last = $mshot->Data('to_ushot_id');
  my @dates;
  my $rid = $router->ID();
  # print " [router:$rid]" if setting('terminal');
  my $db = db(); my $dbh = $db->{dbh};
  my $interval = setting('interval');
#   my $locals  = $router->GetIPs('local');  fatal("Не указаны адреса типа local для роутера $rid")  unless @$locals;
  my $src_ip_local = IpClassQuery('src_ip');
  my $dst_ip_local = IpClassQuery('dst_ip');
  my $clients = $router->GetIPs('client');  fatal("Не указаны адреса типа client для роутера $rid")    unless @$clients;
  my $group_by_src_ip = IpQuery('src_ip',$clients);
  my $group_by_dst_ip = IpQuery('dst_ip',$clients);
  my $not_calculate_client_output = "and not ($group_by_dst_ip)";
  # TODO Сделать broken_ip списко ip в роутере по которым статистику вообще не надо считать
  #TODO
  # Есть 'свои' сервера, а есть абонентскиа машины, трафик считается и для тех и для других,
  # но если клиент скачал со своего трафика, то надо это повесить на клиента, а не на сервер
  #  print "Вывожу неопознанный трафик:" if setting('terminal');
  my $q = qq(select from_unixtime(logtime-mod(logtime,$interval)) as time,
             inet_ntoa(dst_ip) as dst_ip, inet_ntoa(src_ip) as src_ip,
             sum(traflog.bytes) as bytes from log_shot, traflog
             where traflog.shot_id=log_shot.shot_id
             and log_shot.shot_id>=$from and log_shot.shot_id<=$last
             and !((($group_by_dst_ip) or (($group_by_src_ip) $not_calculate_client_output)))
             and router_id=$rid
             group by dst_ip, src_ip); #from_unixtime(logtime-mod(logtime,$interval)),
  logger('sql')->debug($q);
  my $sth = $dbh->prepare($q);
  my $rv  = $sth->execute();
  my $file = directory('temp')."iptraff_lost-".$mshot->ID()."-$rid.minuts.dump";
  my $all=0;
  open(FILE,"> $file");
  print FILE "time\tdst\tsrc\tbytes\n";
  while (my $a=$sth->fetchrow_hashref()) {
    print FILE "$a->{time}\t$a->{dst_ip}\t$a->{src_ip}\t$a->{bytes}\n";
    $all+=$a->{bytes};
  }
  close(FILE);
  #  print "Ok\n" if setting('terminal');
  logger()->info("Потеряный трафик скинут в $file");
  return ($all,$file);
}

sub IpClassQuery {
  my $name = shift;
  my $db = db(); my $dbh = $db->{dbh};
  my $sth = $dbh->prepare('select * from ip_class order by class');
  my $rv  = $sth->execute();
  my %class;
  while (my $a=$sth->fetchrow_hashref()) {
    $class{$a->{class}}=[] unless $class{$a->{class}};
    my $b = inet_atobm($a->{net});
    push @{$class{$a->{class}}},
      $b->{bits} ? "$b->{mask} = $name >> $b->{bits}" : "$name=$b->{mask}";
  }
  my @s;
  foreach my $c (sort keys %class) {
    my $a = join(' or ',@{$class{$c}});
    push @s, "WHEN ($a) THEN $c";
  }
  return "CASE ".join(' ',@s). " ELSE 0 END";
}


sub IpQuery {
  my ($name, $list) = @_;
  return join(' or ',map {$_->{bits} ? "$_->{mask} = $name >> $_->{bits}" : "$name=$_->{mask}"} @$list);
}

# Поминутный трафик с которого вводится новая система расчёта (с клинетом)
# ulog - 97034-99007

sub InsertLog {
  my ($sid,$from,$last,$router) = @_;
  $from=0 unless $from;
  my $rid = $router->ID();
  print " [router:$rid]" if setting('terminal');
  my $db = db(); my $dbh = $db->{dbh};
  my $interval = setting('interval');
  my $clients  = $router->GetIPs('client') || fatal("Не указаны адреса типа client для роутера $rid");
  my $src_ip_local = IpClassQuery('src_ip');
  my $dst_ip_local = IpClassQuery('dst_ip');
  my $group_by_src_ip = IpQuery('src_ip',$clients) || fatal('no clients ips');
  my $group_by_dst_ip = IpQuery('dst_ip',$clients) || fatal('no clients ips');
  my $not_calculate_client_output = "and not ($group_by_dst_ip)";
  # TODO Есть 'свои' сервера, а есть абонентскиа машины, трафик считается и для тех и для других,
  # но если клиент скачал со своего трафика, то надо это повесить на клиента, а не на сервер
  print ', входящий' if setting('terminal');
  # and host.router_id=log_shot.router_id
  my $q = qq(insert into minut_traffic
             select ?, log_shot.router_id, DATE(\@t:=from_unixtime(logtime-mod(logtime,$interval))),
             TIME(\@t), \@t, dst_ip, src_ip, ($src_ip_local), ?, sum(traflog.bytes), client_id
             from log_shot, traflog left join host on (host.ip=traflog.dst_ip)
             where traflog.shot_id=log_shot.shot_id
             and log_shot.shot_id>=? and log_shot.shot_id<=?
             and log_shot.router_id=? and ($group_by_dst_ip)
             group by log_shot.router_id, from_unixtime(logtime-mod(logtime,$interval)), dst_ip, src_ip);
  logger('sql')->debug($q,join(';',$sid,'in',$from,$last,$rid));
  my $sth = $dbh->prepare_cached($q);
  my $rv  = $sth->execute($sid,'in',$from,$last,$rid);
  print ', исходящий ' if setting('terminal');
  # and host.router_id=log_shot.router_id
  $q = qq(insert into minut_traffic
          select ?, log_shot.router_id, DATE(\@t:=from_unixtime(logtime-mod(logtime,$interval))),
          TIME(\@t), \@t, src_ip, dst_ip, ($dst_ip_local), ?, sum(traflog.bytes), client_id
          from log_shot, traflog left join host on (host.ip=traflog.src_ip)
          where traflog.shot_id=log_shot.shot_id
          and log_shot.shot_id>=? and log_shot.shot_id<=?
          and log_shot.router_id=? and ($group_by_src_ip) $not_calculate_client_output
          group by log_shot.router_id, from_unixtime(logtime-mod(logtime,$interval)), src_ip, dst_ip);
  $sth = $dbh->prepare_cached($q);
  logger('sql')->debug($q,join(';',$sid,'out',$from,$last,$rid));
  $rv=$sth->execute($sid,'out',$from,$last,$rid);
}



1;
