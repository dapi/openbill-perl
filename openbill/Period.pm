package openbill::Period;
use strict;
use Number::Format qw(:subs);
use openbill::Host;
use openbill::Base;
use openbill::Street;
use openbill::Utils;
use openbill::Tariff;
use openbill::Locker;
use openbill::IPTraff;
use openbill::Client;
use dpl::Log;
use dpl::Context;
use dpl::System;
use dpl::Error;
use dpl::Db::Database;
use dpl::Db::Table;
use dpl::Db::Filter;
use Error qw(:try);
use Exporter;
use vars qw(@ISA
            %PERIOD_IP_HASH
            @EXPORT);

%PERIOD_IP_HASH=();
@ISA=qw(Exporter
        openbill::Base);

@EXPORT=qw(period);

#use overload (
#              '""' => 'sss',
#             );


sub period {
  return openbill::Period->instance('period',@_);
}

sub DataFull {
  my ($self,$key) = @_;
  $self->Load() unless $self->isLoaded();
#  $self->{data}->{service}||=$self->GetService()->string();
  return $key ? $self->{data}->{$key} : $self->{data};
}

sub string {
  my ($self,$a) = @_;
  return $a ? $self->Data('start')->TimeFormat('%Y-%m') : $self->Data('start')->TimeFormat('%B %Y');
}

# Возвращает минимальную и максималную дату из списка непрерывных
# открытых периодов прилежащих к текущему

sub GetMinimalOpenDate {
  my ($self) = @_;
  my $a = db()->SelectAndFetchOne("select min(start) as date from period where is_closed=0");
  if ($a) {
    return filter('date')->FromSQL($a->{date});
  } else {
    logger()->error("Нет минимальной даты");
    return today()-30*60*60;    #  TODO в конфиг
  }
}

sub IsDateInPeriod {
  my ($self,$date) = @_;
  #  print STDERR $self->Data('start').'-'.$self->Data('end').'-'.$date;
  return $self->Data('end')>=$date && $self->Data('start')<=$date;
}

sub List {
  my ($self,$from,$to,$is_closed) = @_;
  my $f = filter('date')->ToSQL($from) if $from;
  $to = filter('date')->ToSQL($to) if $to;
  my $w;
  if ($to && $from) {
    $w = "((start<='$from' and end>='$from') or end>='$to')";
  } elsif ($to) {
    fatal("Не указано from");
  } elsif ($from) {
    $w = "(start<='$from' and end>='$from')";
  }
  if ($is_closed) {
    $w="$w and " if $w;
    $w.="is_closed=1";
  }

  $w="where $w"
    if $w;
  my $q = qq(select * from period $w order by start asc);
  my $list = db()->SelectAndFetchAll($q);
  return [] unless $list;
  my @p;
  foreach (@$list) {
    push @p, period()->Load($_->{id},$self->{table}->FromSQL($_));
  }
  return \@p;
}

sub GetOpenList {
  my ($self, $date)  = @_;
  my $w = $date ? " and start>='".filter('date')->ToSQL($date)."'" : '';
  my $list = db()->SelectAndFetchAll(qq(select * from period
                                        where is_closed=0 $w order by start asc));
  return [] unless $list;
  my @p;
  foreach (@$list) {
    push @p, period()->Load($_->{id},$self->{table}->FromSQL($_));
  }
  return \@p;
}

sub Days {
  my $self = shift;
  my $delta = $self->Data('end') - $self->Data('start') + 1;
  return round($delta->Seconds()/(24*60*60),0);
}

# Устанавливается для того, чтобы можно было изменить параметры периода day_shot и тд
# устанавливается до начала изменений. Если этот флаг не установлет ->SaveStatus ругнётся
sub SetUpdatable {
  my $self = shift;
  if ($self->Data('is_closed')) {
    logger()->error("Попытка обновить перод, который закрыт");
    return undef;
  }
  $self->{updatable}=1;
}

sub UnsetUpdatable {
  my $self = shift;
  $self->{updatable}=0;
}

sub IsOpen {
  my $self = shift;
  return !$self->Data('is_closed');
}

sub GetNextClosed {             # Возвращает 1 если все периоды включая текущий открыты и не корректны.
  my ($self) = @_;
  my $start = filter('date')->ToSQL($self->Data('start'));
  my $sid = $self->Data('service_id');
  return db()->SelectAndFetchOne(qq(select * from period
                                    where service_id=$sid and start>'$start'
                                    and is_closed=1
                                    order by start asc limit 1));
}

sub Charge {
  my ($self) = @_;
#  print "Счёт периода ".$self->string().": " if setting('terminal');
  # TODO блокировать period
  unless ($self->IsOpen()) {
    logger()->error("Попытка сделать расчёт в закрытом периоде");
    return undef;
  }
  my $lock = Locker('period','write',$self->ID());
  $self->SetUpdatable();
  my $summa = try {
    my $summa =  iptraff()->charge($self);
    $self->SaveStatus();
    db()->Commit();
    return $summa;
  } otherwise {
    my $e = shift;
    db()->Rollback();
    $e->throw();
  } finally {
    $self->UnsetUpdatable();
  };
  logger()->debug("Списано абонплаты $summa за счёт периода ".$self->string());
  return $summa;
}

sub Recharge {                  # Всё удаляет и перерасчитывает
  my ($self) = @_;
#  print "Пересчёт периода ".$self->string().": " if setting('terminal');
  unless ($self->IsOpen()) {
    logger()->error("Попытка сделать перерасчёт в закрытом периоде");
    return undef;
  }
  my $lock = Locker('period','write',$self->ID());
  $self->SetUpdatable();

  my $summa = try {
    table('charge')->Delete({period_id=>$self->ID()});
    my $summa = iptraff()->newCharge($self);
    $self->SaveStatus();
    db()->Commit();
    return $summa;
  } otherwise {
    my $e = shift;
    db()->Rollback();
    $e->throw();
  } finally {
    $self->UnsetUpdatable();
    $self->ClearCaches();
  };
  logger()->debug("Списано абонплаты $summa за пересчёт периода ".$self->string());
#  if (defined $summa) {
#    print FormatMoney($summa)."\n" if setting('terminal');
#  } else {
#    print "ничего не списано\n" if setting('terminal');
#  }
  return $summa;
}

sub Close {
  my $self = shift;
  return undef unless $self->Data('end')<today();
  return undef if $self->Data('is_closed');
  my $lock = Locker('period','write');
  #TODO Блокировка делать recharge перед закрыванием?
  my $summa = $self->Recharge();
  $self->{table}->Modify({is_closed=>1},$self->ID());
  db()->Commit();
  my $table = iptraff()->chargetable();
  my $list = $table->List({period_id=>$self->ID()});
  foreach my $h (@$list) {
    my $client = openbill::Client::client($h->{client_id})->Load();
    my $summa = round($h->{summa},2);
    my $so = $summa;
    if ($client->Data('is_firm')) {
      $so = round($summa*1.18,2);
    }
    $table->Modify({summa_order=>$so,summa=>$summa},
		    {period_id=>$h->{period_id},client_id=>$h->{client_id}});

    my $cnt = $client->Data('good_month_cnt');
    $cnt = $client->Data('is_good_month') >= 0 ? $cnt + 1 : 0;

    db()->Query("update client
    	set good_month_cnt=?
	where client_id=?",$cnt,$client->ID());
  }

  #TODO Посылать абонентам письма с информацией о законченном периоде.
  # TODO Посылать письмо оператору кому и насколько выписывать счёт
  return $summa;
}

sub SaveStatus {
  my ($self) = @_;
  my $status = $self->{new_status} || fatal("internal error");
  # TODO Обьновлять можно только season_date и dayshot_id, как бы сделать проверку на это?
  fatal('Попытка обновить данные периода, когда это не разрешено')
    unless $self->{updatable};
  foreach (keys %$status) {
    unless ($status->{$_}==$self->Data($_)) {
      $self->{table}->Modify($status,$self->ID());
      map {$self->{data}->{$_}=$status->{$_}} keys %$status;
      last;
    }
  }
  $self->{new_status}=undef;
}

sub SetNewStatus {
  my ($self,$status) = @_;
  $self->{new_status}=$status;
}

sub GetNewStatus {
  my $self = shift;
  return $self->{new_status};
}

sub SetData {
  my ($self,$data) = @_;
  $self->SUPER::SetData($data);
  if ($data) {
    #    $data->{end}=filter('date')->FromSQL($data->{end})
    #      unless UNIVERSAL::isa($data->{end},'openbill::DataType::DateObject');
    #    $data->{start}=filter('date')->FromSQL($data->{start})
    #      unless UNIVERSAL::isa($data->{end},'openbill::DataType::DateObject');
#     unless ($self->{service} && $self->{service}->ID()==$data->{service_id}) {
#       $self->{service}=openbill::Service::service($data->{service_id});
#     }
    $self->{data}->{start} =
      new openbill::DataType::Date({ date => {year => $self->{data}->{start}->Year(),
                                   month => $self->{data}->{start}->Month(),
                                   day => $self->{data}->{start}->Day(),
                                   hour => 0, min => 0, sec => 0, },
                          time_zone => 'Europe/Moscow', locale => 'ru_RU.KOI8-R',
                        });

    $self->{data}->{end} =
      new openbill::DataType::Date({ date => {year => $self->{data}->{start}->Year(),
                                   month => $self->{data}->{start}->Month(),
                                   day => $self->{data}->{start}->DaysInMonth(),
                                   hour => 23, min => 59, sec => 59, },
                          time_zone => 'Europe/Moscow', locale => 'ru_RU.KOI8-R',
                        });
  } else {
    $self->{service} = undef;
  }
}

sub GetService  {
  my $self = shift;
  die "No such method GetService";
#  return $self->{service} if $self->{service};
#  $self->{service}=openbill::Service::service($self->Data('service_id'));
}

sub GetMonthName {
  my $self = shift;
  return $self->Data('start')->TimeFormat('%Y-%m');
}

sub GetMonth {
  my $self = shift;
  return $self->Data('start')->TimeFormat('%Y-%m');
}

# TODO в Load поместить проверку на is_opening и is_charging и ругаться

sub Create {
  my ($self,$date) =  @_;
#  die 'umimplemented, проверить чтобы в SetData передавались объектами даты';
  # TODO проверять не открыт ли уже, может открыт, но не докончен (create_time) удалять в таком
  # случае все charges, attach_hosts и создавать заново
  my $lock = Locker('period','write',0);
  return try {
    $date = today() unless $date;
    $date = new openbill::DataType::Date({ date => {year => $date->Year(), month => $date->Month(),
                                         day => 1, hour => 0, min => 0, sec => 0, },
                                time_zone => $date->TimeZone(), locale => $date->Locale(),
                              });
    my $end = new openbill::DataType::Date({ date => {year => $date->Year(), month => $date->Month(),
                                                      day => $date->DaysInMonth, hour => 23, min => 59, sec => 59, },
                                             time_zone => $date->TimeZone(), locale => $date->Locale(),
                                });
    my %w=(start=>$date, end=>$end);
    print STDERR "Создаю новый период $date\n";
    logger()->debug("Создаю новый период $date");
    my $res;
    if ($res = $self->{table}->Load(\%w)) {
      if ($res->{create_time}) {
        logger()->warn("Период уже существует: $date - $end)");
        return $self->Load($res->{id},$res);
      } else {
        $self->SetID($res->{id}); $self->SetData($res);
        die 'delete periods data'; # TODO
        $self->Delete();
      }
    } else {
      my $d = {%w,create_time=>today(),is_closed=>0,};
      $res = $self->SUPER::Create($d);
      $self->SetData($d);
    }
    $self->SetUpdatable();
    iptraff()->newCharge($self);
    $self->SaveStatus();
    $self->UnsetUpdatable();
    db()->Commit();
    return period()->LoadByDate($date);
  } otherwise {
    my $e = shift;
    db()->Rollback();
    $self->Delete()
      if $self->{is_created};
    db()->Commit();
    $e->throw();
  } finally {
    print "Ok.\n" if setting('terminal');
  };

}


sub Delete {
  my $self = shift;
  table('charge')->Delete({period_id=>$self->ID()});
  return $self->SUPER::Delete();
}

sub LoadByDate {
  my ($self,$date)  = @_;
  my $p;
  if ($date=~/^(\d\d\d\d)[\-\.\/](\d{1,2})$/) {
    $date="$1-$2-01";
    $p = db()->SelectAndFetchOne("select * from period where start='$date'");
  } else {
    $date =  filter('date')->ToSQL($date || today());
    $p = db()->SelectAndFetchOne("select * from period where start<='$date' and end>='$date'");
  }
  return undef unless $p;
  $p->{start}=filter('date')->FromSQL($p->{start});
  $p->{end}=filter('date')->FromSQL($p->{end});
  $self->SetData($p);
  $self->SetID($p->{id});
  return $self;
}

sub CreateIfNeed {
  my ($self,$date) = @_;
  # TODO
  return period()->LoadOrCreate($date);
}

sub LoadOrCreate {
  my ($self,$date) = @_;
  return $self->LoadByDate($date) || $self->Create($date);
}

sub FindDays {
  my ($self,$log) = @_;
  my $days=0;
  foreach (@$log) {
    $days+=1 if $_;
  }
  return $days;
}

sub CreateTariffesCache {
  my ($self) = @_;
  my $start = filter('date')->
    ToSQL($self->Data('start'));
  my %clients;
  my $p = db()->SelectAndFetchAll(qq(select * from tariff_log
                                     where from_ym<='$start'
                                     order by client_id, from_ym desc));
  foreach (@$p) {
    next if $clients{$_->{client_id}};
    $clients{$_->{client_id}}=$_->{tariff_id};
  }
  $self->{cache}->{tariffes}=\%clients;
  return \%clients;
}


# sub CreateActivationsCache {    # возвращает список активированных на этот период клиентов и генерирует кеш активаций
#   my ($self) = @_;
#   my $start = $self->Data('start');
#   my $sql_end = filter('date')->ToSQL($self->Data('end'));
#   #(service_id=$sid or service_id is null) and
#   my $a = db()->
#     SelectAndFetchAll(qq(select * from activation_log
#                          where date<='$sql_end'
#                          order by date desc));
#   my %clients;
#   my $max = $self->Days()-1;
#   my @e= map {undef} (0..$max);
#   foreach my $l (@$a) {
#     my $date = filter('date')->FromSQL($l->{date});
#     # die "$date - ".join(',',%$l) if $l->{client_id}==59;
#     $clients{$l->{client_id}}=[@e] unless $clients{$l->{client_id}};
#     my $c = $clients{$l->{client_id}};
#     if (defined $c->[0]) {
#       die $l->{client_id} unless ref($c) eq 'ARRAY';
#       delete $clients{$l->{client_id}} unless $self->FindDays($c);
#       next;
#     }
#     next if defined $c->[0];
#     my $day = $date<$start ? 0 : $date->Day()-1;
#     foreach ($day..$max) {
#       next if defined $c->[$_];
#       $c->[$_]=$l->{is_active} ? 1 : 0;
#     }
#   }
#   $self->{cache}->{activations}=\%clients;
#   return \%clients;
# }

sub FindClientsTariff {
  my ($self,$client) = @_;
  my $tid;
  if (exists $self->{cache} && exists $self->{cache}->{tariffes}) {
    $tid = $self->{cache}->{tariffes}->{$client->ID()};
  } else {
    $tid = $client->FindCurrentTariff($self->Data('start'));
  }
  fatal("Ненайден тариф ($tid) для клиента ".$client->ID()) unless $tid;
  return openbill::Tariff::tariff($tid);
}

# sub FindClientsActivation  {
#   my ($self,$client) = @_;
#   if (exists $self->{cache} && $self->{cache}->{activations}) {
#     return $self->{cache}->{activations}->{$client->ID()} if $self->{cache}->{activations}->{$client->ID()};
#     logger()->warn("В кеше не найдена активация для клиента $client->{id}");
#   }
#   return $client->getActivationsLog($self);
# }

sub ClearCaches {
  my $self = shift;
  $self->{cache}=undef;
}

1;
