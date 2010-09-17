package openbill::Tariff;
use strict;
use Number::Format qw(:subs);
use openbill::Host;
use openbill::Base;
use openbill::Utils;
use openbill::System;
use openbill::Period;
use dpl::Log;
use dpl::Error;
use dpl::Context;
use dpl::Db::Table;
use dpl::Db::Filter;
use dpl::Db::Database;
use Error qw(:try);
use Exporter;
use vars qw(@ISA
            @EXPORT);

@ISA=qw(Exporter
        openbill::Base);

@EXPORT=qw(tariff);

sub tariff {
  return openbill::Tariff->instance('tariff',@_);
}

sub string {
  my $self = shift;
  return $self->Data('name');
}

sub List {
  my ($self) = @_;
  my %t={is_active=>1};
  my $list = $self->{table}->List({%t});
  my @l;
  foreach (@$list) {
    push @l, tariff($_->{id});
  }
  return \@l;
}

sub CheckContext {
  my ($self,$client) = @_;
  my $data = $self->Data();
  # Для не анлимных тарифов ограничений нет
  return 1 unless $data->{is_unlim};
  my $hosts = $client->GetHosts();
  my $vpns;
  my $no_vpn_only;
  foreach my $h (@$hosts) {
    if ($h->Data('is_vpn')) {
      $vpns++;
    } elsif ($h->Data('am_type') eq 'vpn_only') {
    } else {
      $no_vpn_only++;
    }
  }
  fatal("Тариф не может быть установлен так, как у клиента есть $no_vpn_only хостов, имеющих доступ не vpn_only")
    if $no_vpn_only;
  fatal("Тариф не может быть установлен так, как у клиента уже прописано $vpns. Лимит для этого тарифа составляет $data->{hosts_limit}.")
    if $vpns>$data->{hosts_limit};
  fatal("тариф не может быть установлен так, как с клиентом не заключен новый договор")
    unless $client->Data('new_contract_date');
  return 1;
}

sub DataFull {
  my $self = shift;
  my $data = $self->Data();
  $data->{desc}=$self->desc();
  return $data;
}

sub desc {
  my $self = shift;
  my $name  = $self->Data('name');
  my $free  = $self->Data('traffic_mb0');
  my $price  = $self->Data('price_mb0');
  my $price10  = $self->Data('price_mb10');
  my $abon  = $self->Data('price');

  return "$name ($abon/$price($price10); free:$free Mb)";
}


sub Create  {
  my ($self,$data) = @_;
  $self->checkParams($data,'name');
  return $self->SUPER::Create($data);
}

sub NewCharge {
  my ($self,$period,$traffic,$client) = @_;
  my $is_firm = $client->Data('is_firm');
  my $days = $period->Days();#$period->FindDays($activations);

  if ($client->Data('reg_date')>$period->Data('start')) {
    my $l = $period->Data('end') - $client->Data('reg_date');
    $days = round($l->Seconds()/(24*60*60));
    fatal("days<0 ($days) for client $client->{data}->{client_id}")
      if $days<0;
    $days=1 if $days<1;
    $days=$period->Days() if $days>$period->Days();
  }
  $days=0 if !$client->Data('is_active')
    && ( (!defined $client->Data('activation_time')) 
    	 || ($client->Data('activation_time')<$period->Data('start')));
  unless ($days) {
    logger()->debug("Трафик у отключенного клиента [$client->{data}->{client_id}] ($traffic->{0}/$traffic->{10}/$traffic->{1}/$traffic->{11}) более 100Kb. Период ".$period->string())
      if $traffic->{1}+$traffic->{11}>100000;
    return undef;
  }

  #  return undef unless $days && $traffic->{0}<1024; # TODO to config
  #." активация: ".join(',',@$activations)
  fatal("internal error season_days>period_days")
    if $period->Days()<$days;
  my $iptraff_summa = $self->Data('price')*$days/$period->Days();
  my $iptraff_summa_order = $is_firm ? round($iptraff_summa*1.18,2) : $iptraff_summa;
  my $inet_traffic = $self->Data('traffic_mb0')+$self->Data('traffic_mb10');

  my %cr=(total_days=>$days,
          #act_log=>$activations,
          period_id=>$period->ID(), tariff_id=>$self->ID(),
          traffic=>{},traffic_summa=>0, traffic_order=>0,
          traffic_free=>round($days*$inet_traffic*$openbill::Utils::MBYTES/$period->Days()),

          iptraff_summa=>$iptraff_summa, iptraff_summa_order=>$iptraff_summa_order,
          season_summa=>$iptraff_summa, season_order=>$iptraff_summa_order,
	  );

  #summa и summa_order определять не надо, они определятся в Charge
  my $ncr=$self->Charge($period,$traffic,\%cr,$client,1);
  return {%cr,%$ncr};
}

sub Charge {
  my ($self,$period,$traffic,$charge_record,$client,$recharge) = @_;
  my $is_firm = $client->Data('is_firm');
  my $inet_day = $charge_record->{traffic}->{0}+$traffic->{0};
  my $inet_night = $charge_record->{traffic}->{10}+$traffic->{10};
  my $inet_all  = $inet_day + $inet_night;

  my $tariffed_inet_day;
  my $tariffed_inet_night;

  # $charge_record->{traffic_free} - это сумма бесплатных трафиков (дневной+ночной)
  # Если traffic_mb10 != 0, то дневной (бесплатный) трафик - отдельно, ночной - отдельно. Нужно было для тарифа Сучкова, больше не используется.
  if ($self->Data('traffic_mb10')) {
  	logger()->error("Считаю разные бесплатные трафики для клиента ", $client->ID());
  	my $traffic_free_night = round($charge_record->{total_days}*$self->Data('traffic_mb10')*$openbill::Utils::MBYTES/$period->Days());
  	my $traffic_free_day = $charge_record->{traffic_free} - $traffic_free_night;

  	$traffic_free_night = $inet_night if ($client->Data('night_speed'));

	$tariffed_inet_day = $inet_day - $traffic_free_day;
	$tariffed_inet_day = 0 if ( $tariffed_inet_day < 0);

	$tariffed_inet_night = $inet_night - $traffic_free_night;
	$tariffed_inet_night = 0 if ( $tariffed_inet_night < 0);

  }else {
	# Если traffic_mb10 = 0 (т.е. ночной бесплатный трафик не установлен),  
	# то считаем что бесплатный трафик распространяется на все периоды.
	# Вычитаем бесплатные мегабайты в первую очередь из дневного трафика, затем остатки - из ночного.
	$tariffed_inet_night = $client->Data('night_speed') ? 0 : $inet_night;
	$tariffed_inet_day = $inet_day - $charge_record->{traffic_free};

	if ( $tariffed_inet_day < 0 ) {
		$tariffed_inet_night += $tariffed_inet_day;
		$tariffed_inet_night = 0 if ( $tariffed_inet_night < 0);
		$tariffed_inet_day = 0;
	}
  }

  my $price_mb0 = $self->Data('price_mb0');
  my $price_mb10 = $self->Data('price_mb10'); 

  if ( ($self->Data('is_unlim') == 0) 
  	&& ($price_mb10 == 0) 
	&& ($price_mb0 != 0) 
	&& ($client->Data('night_speed') == 0) ) {
	$price_mb10 = $price_mb0;
  	logger()->error("Стоимость ночного трафика равна 0 (tariff_id=",$self->ID(),", client_id=",$client->ID(),"). Использую вмeсто нее стоимость дневного трафика");
	logger()->error("Стоймость дневного трафика тоже равна 0. Странный тариф.") if ( $price_mb0 == 0);
  }

  my $summa = ($price_mb0*$tariffed_inet_day + $price_mb10*$tariffed_inet_night)/$openbill::Utils::MBYTES;

  my %new_cr = (traffic_summa=>$summa,
                traffic=>\%{$charge_record->{traffic}});

  foreach (keys %$traffic) {
    $new_cr{traffic}->{$_}+=$traffic->{$_};
  }

  $new_cr{traffic}->{free}=$inet_all - $tariffed_inet_day - $tariffed_inet_night;
  $new_cr{traffic}->{inet}=$inet_all;

  $new_cr{season_summa} = $self->Data('price')*$charge_record->{total_days}/$period->Days();

  $new_cr{iptraff_summa}=$new_cr{traffic_summa}+$new_cr{season_summa};

  unless ($charge_record->{total_days}) {
    $new_cr{traffic_summa}=0;
    $new_cr{season_summa}=0;
    logger()->error("Нулевой съём у отключенного клиента. Трафик ($charge_record->{traffic}->{0}/$charge_record->{traffic}->{1}). Период ".$period->string());
  }
  $new_cr{traffic_order} = $is_firm ? round($new_cr{traffic_summa}*1.18,2) : $new_cr{traffic_summa};
  $new_cr{season_order} = $is_firm ? round($new_cr{season_summa}*1.18,2) : $new_cr{season_summa};
  $new_cr{iptraff_summa_order} = $new_cr{season_order} + $new_cr{traffic_order};
  my $cs = $is_firm ? round($new_cr{iptraff_summa}*1.18) : $new_cr{iptraff_summa};

  $new_cr{other_summa}=GetOtherServicesSumm($period,$client)+0;
  $new_cr{other_summa_order} = $is_firm ? round($new_cr{other_summa}*1.18,2) : $new_cr{other_summa};
  $new_cr{summa}=$new_cr{iptraff_summa}+$new_cr{other_summa};
  $new_cr{summa_order}=$new_cr{iptraff_summa_order}+$new_cr{other_summa_order};

  my $t = $openbill::Utils::MBYTES*$self->Data('traffic_mb0');

  $new_cr{total_days} = $charge_record->{total_days};

#  die join(',',%new_cr) if $self->ID()==58;

  db()->Query("update client set period_month=? where period_month<? and client_id=?",
              $period->Data('start'),$period->Data('start'),$client->ID());

  db()->Query("update client set period_traffic_mb=?, period_tariff_id=? where client_id=?",
	$inet_all/$openbill::Utils::MBYTES,
	$self->ID(),
	$client->ID());
  if ($self->Data('is_unlim') &&
	(($inet_all>=$t && !$client->Data('night_speed')) || $inet_day>=$t)) {
     if (!$client->Data('period_limited') || $recharge) {
	logger()->error("Абонент превысил пороговое ограничение ($inet_all>=$t) ",$client->ID());
	db()->Query("update host set is_limited=?, am_time=NULL where client_id=?",
	      1,$client->ID());
	db()->Query("update client set period_limited=? where client_id=?",
	      1,$client->ID());
     }
  } elsif ($client->Data('period_limited')) {
     logger()->error("Выключаю пороговое ограничение ($inet_all>=$t) ",$client->ID());
     db()->Query("update host set is_limited=?, am_time=NULL where client_id=?",
	   0,$client->ID());
     db()->Query("update client set period_limited=? where client_id=?",
	   0,$client->ID());
  }

  #Программа лояльности
  #client.good_month_period_id - id периода которому соответствуют значения
  #client.is_good_month и client.good_month_cnt
  my $cur_month_id = $client->Data('good_month_period_id') || $period->ID();
  my $p = openbill::Period::period($cur_month_id);

  if ($cur_month_id != $period->ID()) {
     #Если после открытого периода $cur_month_id есть открытые периоды
     #храним в client значения is_good_month и good_month_cnt старого периода,
     #пока он не будет закрыт (XXX: точно не работает)
     $cur_month_id = $p->IsOpen() ? 0 : $period->ID();
  }
  if ($cur_month_id) { 
     my $is_good_month = openbill::Client::IsGoodMonth(\%new_cr, $client, $period, $self);
     $is_good_month = $client->Data('is_good_month')
	if((($client->Data('is_good_month') < 0)
	      || ($client->Data('is_good_month') == 100))
	      && ($client->Data('is_good_month') != 8) #8 - доп сервисы 300/200
	  );
     my $good_month_cnt = $is_good_month >= 0 ? $client->Data('good_month_cnt') : 0;
     #Данные в client
     if (($client->Data('is_good_month') != $is_good_month)
	   || ($client->Data('good_month_cnt') != $good_month_cnt)
	   || ($client->Data('good_month_period_id') != $cur_month_id)
	   ) {
	db()->Query("update client
	      set good_month_cnt=?,is_good_month=?,good_month_period_id=?
	      where client_id=?",$good_month_cnt,$is_good_month,$cur_month_id,$client->ID());
	logger()->debug("is_good_month/good_month_cnt/period changed: ".$client->Data('is_good_month')."/".$client->Data('good_month_cnt')." -> $is_good_month/$good_month_cnt. client_id:", $client->ID(),"\n");
     }
     #Те же данные в charge, для истории
     $new_cr{is_good_month}=$is_good_month;
     $new_cr{good_month_cnt}=$good_month_cnt;
   }else{
     $new_cr{is_good_month}=$client->Data('is_good_month');
     $new_cr{good_month_cnt}=$client->Data('good_month_cnt');
   }

  return \%new_cr;
}

sub GetOtherServicesSumm {
  my ($period,$client) = @_;
  my $period_id = $period->ID();
  my $client_id = $client->ID();
  my $a = db()->
    SelectAndFetchOne("select sum(summa) as summa from subscriber_charge where period_id=$period_id and client_id=$client_id");
  return undef unless $a;
  return $a->{summa};
}

sub Find {
  my ($self,$like) = @_;
  if ($like=~/^(\d+)$/) {
    return $self->Load($like);
  } else {
    my %h = (like=>$like, is_active=>1);
    my $list = $self->List(\%h) || return undef;
    return @$list==1 ? $list->[0] : scalar @$list;
  }
}

sub List {
  my ($self,$p) = @_;
  if (exists $p->{like}) {
    my $like = $p->{like};
    delete  $p->{like};
    my @a=("name like '%$like%'");
    unshift @a,$p if %$p;
    $p=\@a;
  }
  return $self->SUPER::List($p);
}

1;
