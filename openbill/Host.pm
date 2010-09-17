package openbill::Host;
use strict;
use openbill::Utils;
use openbill::Base;
use openbill::Client;
use openbill::Router;
use openbill::Janitor;
use openbill::Address;
use openbill::Manager;
use openbill::AccessMode;
use dpl::Context;
use dpl::System;
use dpl::Log;
use dpl::Error;
use dpl::Db::Filter;
use dpl::Db::Table;
use dpl::Db::Database;
use openbill::Sendmail;
use Error qw(:try);
use Exporter;
use vars qw(@ISA
            @EXPORT);

@ISA=qw(Exporter
        openbill::Base);

@EXPORT=qw(host);

sub host {
  return openbill::Host->instance('host',@_);
}

sub DataFull {
  my ($self,$key) = @_;
  $self->Load() unless $self->isLoaded();
  $self->{data}->{host}=inet_fromint($self->{data}->{ip},$self->{data}->{bits});
  $self->{data}->{client}||=client($self->{data}->{client_id})->string()
    if $self->{data}->{client_id};
  $self->{data}->{manager}=$self->{data}->{manager_id} ? manager($self->{data}->{manager_id})->DataFull() : 'НЕИЗВЕСТНО';
  $self->{data}->{router}||=router($self->{data}->{router_id})->string();
  $self->{data}->{janitor}||=janitor($self->{data}->{janitor_id})->string()
    if $self->{data}->{janitor_id};
  unless ($self->{data}->{address}) {
    if ($self->{data}->{address_id}) {
      my $a = $self->GetAddress();
      $self->{data}->{address}||=$a->string();
      my $building=$a->building();
      $self->{data}->{street}||=$building->street()->Data('name');
      $self->{data}->{building}||=$building->Data('number');
      $self->{data}->{room}||=$a->Data('room');
    } else {
      $self->{data}->{address}='???';
    }
    #   } else {
    #     logger()->error("Ну установлен address_id для хоста $self->{data}->{host_id}");
  }
#  unless ($self->{data}->{bits}) {
#    my $res = db()->SelectAndFetchOne("select max(date) as date from day_traffic where ip=$self->{data}->{ip} and router_id=$self->{data}->{router_id}");
#    next unless $res->{date};
#    my $rest = db()->SelectAndFetchOne("select max(time) as time from minut_traffic where date='$res->{date}' and ip=$self->{data}->{ip} and router_id=$self->{data}->{router_id}");
#    $self->{data}->{last_datetime}="$res->{date} $rest->{time}";
#  }
  return $key ? $self->{data}->{$key} : \%{$self->{data}};
}

# sub List {
#   my ($self,$where) = @_;
#   return $self->SUPER::List($where);
# }

sub DataFullList {
  my ($self,$where) = @_;
  #  my $list = $self->{table}->List($where);
  if (ref($where)=~/HASH/) {
    if (exists $where->{building_id}) {
      $where->{'address.building_id'}=$where->{building_id};
      delete $where->{building_id};
    }
    if (exists $where->{street_id}) {
      $where->{'building.street_id'}=$where->{street_id};
      delete $where->{street_id};
    }
    if (exists $where->{street}) {
      $where->{and}=["street.name like '%$where->{street}%'"];
      delete $where->{street};
    }
    if (exists $where->{address_id}) {
      $where->{'host.address_id'}=$where->{address_id};
      delete $where->{address_id};
    }
    if (exists $where->{building}) {
      $where->{'building.number'}=$where->{building};
      delete $where->{building};
    }
    if (exists $where->{from_ip}) {
      $where->{from_ip}=~s/\'|\"//g;
      $where->{and}=["ip>=inet_aton('$where->{from_ip}')"];
      delete $where->{from_ip};
    }
    if ($where->{client_id} eq 'no') {
      $where->{and}=[] unless $where->{and};
      push @{$where->{and}},"client_id is null";
      delete $where->{client_id};
    }
    if (exists $where->{to_ip}) {
      $where->{to_ip}=~s/\'|\"//g;
      $where->{and}=[] unless $where->{and};
      push @{$where->{and}},"ip<=inet_aton('$where->{to_ip}')";
      delete $where->{to_ip};
    }
  }
#  push @$where,"
  my $sth = db()->Select('host left join address on host.address_id=address.address_id left join building on address.building_id=building.building_id left join street on building.street_id=street.street_id',
                         'host.*, street.name as street, building.number as building, address.room as room',$where);
#  my $list = db()->SelectAndFetchAll(qq(select * from host where client_id=$cid));
  #from_ym<='$ym' and (to_ym<from_ym or to_ym>='$ym')  and
#  my @hosts;
#  print STDERR "get hosts\n";
#   foreach (@$list) {
#     my $h = host();
#     $h->SetData($_);
#     $h->SetID($_->{host_id});
#     push @hosts,$h;
#   }
  my @l;
  while ($_=$sth->fetchrow_hashref()) {
    $_->{address}="$_->{street}, $_->{building}, кв. $_->{room}";
    my $h = $self->host($_);

    push @l,$h->DataFull();
  }
  $sth->finish();
  return \@l;
}


sub CheckDatabase {
  die 'not implemented';
  #  select * where deattach_date>attach_date";
  # записи с одним id не должны пересекаться  attach_date, deattach_date
  # в таблице host должун быть записн соответсвующий с логом клиент
}

sub checkHostname {
  my $data = shift;
  fatal("Неверный символ в названии хоста или логине ($data->{hostname}), должен быть [a-z_0-9]")
    if $data->{hostname}=~/[^a-z_0-9]/i;
}

sub Create  {
  my ($self,$data) = @_;
  $data={} unless $data;

  ($data->{ip},$data->{bits})=inet_toint($data->{host})
    if $data->{host};
  delete $data->{host};
  $data->{am_name}='deactive';
  $self->checkParams($data,'hostname','ip','bits','router_id','mac');
  checkHostname($data);
  $data->{janitor_id}=router($data->{router_id})->Data('default_janitor_id')
    unless $data->{janitor_id};
#   $data->{janitor_router_id}=$data->{router_id}
#     unless $data->{janitor_router_id};
  return $self->SUPER::Create($data);
}

sub Modify  {
  my ($self,$data) = @_;
  if ($data->{host}) {
    ($data->{ip},$data->{bits})=inet_toint($data->{host});
    delete $data->{host};
  }
  $data->{am_time}=undef;
  my $text;
  checkHostname($data);
  my $mid =context('manager')->ID() || fatal('unknown manager in host->Modify of ',$self->ID());
#  $data->{modifytime}='now()';
  foreach (qw(ip bits am_type am_name mac hostname janitor_id is_deactive address_id router_id client_id)) {
    my $v = $self->Data($_);
    if (exists $data->{$_} && $v ne $data->{$_} ) {
      my $n = $data->{$_};
      if ($_ eq 'ip') {
        $v=inet_ntoa($v);
        $n=inet_ntoa($n);
      }
      $text.="$_:$v->$n ";
    }
  }
  table('host_log')->
    Create({host_id=>$self->ID(),
            manager_id=>$mid,
            text=>$text});
  return $self->SUPER::Modify($data);
}

sub CheckLink {
  my ($self,$count) = @_;
  unless ($self->{data}->{janitor_id}) {
    logger()->warn("Не установлен привратник $self->{data}->{host_id}");
    return undef;
  }
  my $janitor=janitor($self->{data}->{janitor_id});
  my $router = router($self->{data}->{router_id});
  my $ip = $self->IP();
  $count||=1;
  my $res = $janitor->CheckLink($router,$count,$ip);
  return {} unless $res;
  return $res->{$ip};
}


sub GetAddress {
  my $self = shift;
  return address($self->Data('address_id'));
}

sub GetAccessMode {
  my ($self,$date) = @_;
  return undef if $self->Data('am_name') eq 'none';
  return access_mode()->Load({type=>$self->Data('am_type'),
                              name=>$self->Data('am_name'),
                              janitor_id=>$self->Data('janitor_id')}) || fatal("(hid:$self->{data}->{host_id})Не найден access_mode -  ".$self->Data('am_type').'/'.$self->Data('am_name'));
}

sub SetAccessMode {
  my ($self,$am,$datetime,$comment) = @_;
  $self->Modify({am_name=>$am,
                 am_time=>undef});
}

sub Delete {
  my ($self) = @_;
  my $mid =context('manager')->ID() || fatal('unknown manager in host->Delete of ',$self->ID());
  my $text;
  foreach (keys %{$self->{data}}) {
    $text.="$_=$self->{data}->{$_};";
  }
  $self->fatal("Нет ID для удаления") unless defined $self->ID();
  table('host_log')->
    Create({host_id=>$self->ID(),
            manager_id=>$mid,
            text=>$text});
  return $self->SUPER::Delete();
}

sub DeattachFromClient {
  my ($self,$client,$date) = @_;
  # TODO Определять и устанавливать actiation для этого хоста
  my $ip = $self->IP();
  die 'not implemented';
}


sub Load_fake {
  my ($self,$id,$data) = @_;
  die "$id";
  return $self->SUPER::Load($id) if ref($id)=~/HASH/;
  return $self->SUPER::Load($id) if $id=~/^\d+$/;
  die "$id";
  my ($ip,$bits)=inet_toint($id);
  return $self->SUPER::Load({ip=>$ip,bits=>$bits});
}

sub AttachToClient {
  my ($self,$client,$date,$comment) = @_;

  $date=today()
    unless $date;
  # TODO Проверять состояние хоста и состояние клиента - отключать если надо
  # TODO Проверять на то к кому сейчас присоединён этот хост
  # TODO проверять на изменение в закрытых периодах и если это так 1) ругаться и неделать; 2) помечать периоды как нуждающиеся в пересчёте
  # TODO Влиять на am_time
  #  my $ip = inet_ntoa($self->IP());
  my $id = $self->ID();
  my $host = $self->Host();
  logger()->info("Присоединение хоста \#$id ($host) к клиенту '[".$client->ID()."] ".$client->Data('name')."' датой $date");
  my $tariff = $client->GetCurrentTariff();
  fatal("Клиенту не установлен тариф")
    unless $tariff;

  $tariff->CheckContext($client);

  my $reg_date=$client->Data('reg_date');
  fatal("Нельзя присоеденить host к клиенту раньше ($date), чем дата регистрации клиента ($reg_date)")
    if $reg_date>$date;
   fatal("Хост уже присоединён к другому клиенту")
     if $self->Data('client_id')!=$client->ID() && !$comment;
  my $min_date = openbill::Period::period()->GetMinimalOpenDate();
  fatal("Дата присоединения хоста ($date) выходит в закрытый период (<$min_date)")
    if $date<$min_date;
  openbill::IPTraff::iptraff()->ChangeTrafficOwner($self,$client,$date);
#  my $traffic = $service->GetTraffic({router_id=>$self->Data('router_id'),
#                                      ip=>$self->Data('host'),
#                                      from=>$date});
  my $res = table('host_attach_log')->
    Create({client_id=>$client->ID(),
            host_id=>$self->ID(),
            from_ym=>$date,
            to_ym=>'0000', # TODO Проверить
            attach_done_time=>today(),
            deattach_done_time=>undef,
            comment=>$comment});
  my $h = {am_time=>undef,
           client_id=>$client->ID()};
  $h->{am_name}=$client->Data('is_active') ? 'active' : 'deactive' ;
  $self->Modify($h);
  db()->Commit();
  notify('attach_host',{host=>$self->DataFull(),
                        client=>$client->DataFull(),
                        date=>$date});
  # TODO Более точно учитывать дату присоединения
  return $res;
  # TODO делать recharge клиента
}

sub openbill::Client::Find {
  my ($self,$like) = @_;
  return $self->SUPER::Find($like) unless
    ((ref($like)=~/HASH/ && exists $like->{ip})
     || $like=~/^\d+\.\d+\.\d+\.\d+/);
  my $ym = filter('ym')->ToSQL(today());
  my ($ip,$exclude);
  if (ref($like)) {
    $ip = $like->{ip};
    #  logger()->debug("Поиск#1 клиента по ip=".inet_ntoa($ip).", датой=$ym");
    $exclude = $like->{exclude_hosts} ? "and comment not like '$like->{exclude_hosts}'" : '';
  } else {
    $ip=$like;
  }
  my $res = db()->SelectAndFetchOne(qq(select client_id, current_speed from host where ip=inet_aton('$ip') >> bits $exclude));
  #from_ym<='$ym' and (to_ym<from_ym or to_ym>='$ym') and
  my $client = $res && $res->{client_id} ? openbill::Client::client($res->{client_id}) : undef;
  return undef unless $client;
  $client->{data}->{host_speed}=$res->{current_speed};
  $client->{host_speed}=$res->{current_speed};
  return $client;
}

sub IP {
  my ($self) = @_;
  return inet_ntoa($self->Data('ip'));
}

sub Host {
  my $self = shift;
  return inet_fromint($self->Data('ip'),$self->Data('bits'));
}

sub openbill::Client::GetHosts {
  my ($self,$period) = @_;
  my $cid = $self->ID();
#  my $ym = filter('ym')->ToSQL($period ? $period->Data('start') : today());
  my $list = db()->SelectAndFetchAll(qq(select * from host where client_id=$cid));
  #from_ym<='$ym' and (to_ym<from_ym or to_ym>='$ym')  and
  my @hosts;
#  print STDERR "get hosts\n";
  foreach (@$list) {
    my $h = host();
    $h->SetData($_);
    $h->SetID($_->{host_id});
    push @hosts,$h;
  }
  return \@hosts;
}



1;
