#!/usr/bin/perl
use lib qw(/home/danil/projects/openbill/
           /home/danil/projects/dpl/);
use dpl::XML;
use NetAddr::IP;
use dpl::Error;
use dpl::Db::Database;
use dpl::Db::Table;
use dpl::Db::Filter;
use Date::Language;
use Date::Parse;
use strict;
use openbill::Period;
use openbill::System;
use openbill::Tariff;
use openbill::Service;
use openbill::Collector;
use openbill::Client;
use openbill::Host;
use openbill::Utils;
use openbill::AccessMode;
my $addr=0;
my $PERIOD_DATE;
my %TARIFF_LOG;
my %tf = (
          street=>{
                   street_name=>'name',
                   street_desc=>'comment'
                  },
          building=>{
                     building_desc=>'comment',
                     building_num=>'number'
                    },
          tarif=>{
                  __table=>'tariff',
                  tarif_id=>'id',
                  is_secret=>'is_hidden',
                  local_mb_price=>0,
                  __post=>sub { postTariff(@_) }
                 },
          tarif_log=>{
                      tarif_id=>'tariff_id',
                      __table=>'tariff_log',
                      __post=>sub { postTariffLog(@_) }
                     },
          payment=>{
                    payment_id=>'id',
                    payment_desc=>'comment',
                    payment_type=>'type',
                    payment_date=>'date',
                    __post=>sub { postPayment(@_); }
                   },
          client=>{
                   bank_rschet=>0,
                   bank_okpo=>0,
                   client_desc=>'comment',
                   bank_bik=>0,
                   bank_okonh=>0,
                   bank_inn=>'inn',
                   bank_korschet=>0,
                   bank=>0,
                   _reg_date=>'date',
                   __post=>sub { postAddress(@_) }
                  },
          host=>{
                 bridge_id=>'router_id',
                 host_id=>0,
                 host_desc=>'comment',
                 __post=>sub { my $d=shift; postAddress($d); postHost($d); }
                },
          bridge=>{
                   __table=>'router',
                   bridge_desc=>'comment',
                   bridge_name=>'hostname',
                   bridge_shortname=>'shortname',
                   bridge_ip=>'ip',
                   dont_download=>0,
                   __post=>sub { postBridge(@_) }
                  }
         );

openbill::System::Init({
                   -config=>'/home/danil/projects/openbill/etc/system.xml',
                   -terminal=>1
                  });
my $db = db();
$db->Connect();
my $file = $ARGV[0];
print STDERR "Import from '$file'\n";
fatal("No file to import") unless -f $file;
my $xml = xmlFile($file);
my $root = $xml->documentElement();
db()->Query('truncate table street');
db()->Query('truncate table building');
db()->Query('truncate table client');
db()->Query('truncate table charge');
db()->Query('truncate table period');
db()->Query('truncate table address');
db()->Query('truncate table ha_log');
db()->Query('truncate table host_attach');
db()->Query('truncate table service');
db()->Query('truncate table collector');
db()->Query('truncate table access_mode');
db()->Query('truncate table host_access');
db()->Query('truncate table activation');

my $service = service()->Create({name=>'iptraff',module=>'openbill::Service::IPTraff'});
$tf{tariff}->{service_id} = $service->ID();
my $c = collector()->Create({name=>'ulog',
                             service_id=>$service->ID(),
                             module=>'openbill::Collector::Ulog'});

$tf{tariff}->{__post} = sub {

                             #$_[0]->{mb_price}=~s/\./,/g;
                             return 1;};
createAccessModes();
my $aa = access_mode()->LoadBy('name','active');
importXml($root,'building');
importXml($root,'street');
importXml($root,'tarif');
importXml($root,'bridge');
importXml($root,'client');
importXml($root,'host');
importXml($root,'tarif_log');
importActivation($root);
importWithdrawal($root);
#die 1;
importXml($root,'payment');
SetPeriods();
#TODO provider_log
#TODO day_log


$db->Disconnect();

sub SetPeriods {
  db()->Query("update period set is_closed=1, is_corrupted=0, season_date=end");
  my $period = period()->LoadByDate($service,today()) || die  'error';#period()->Open($service,today());
  $period->{table}->Modify({is_closed=>0},$period->ID());
  my $periods = period()->List();
  foreach my $p (@$periods) {
    $service->attachHostes($p);
  }
}

sub postTariff {
  my $data = shift;
  #  die ->{mb_price};
  $data->{service_id}=$service->ID();
  $data->{is_active}=1;
  $data->{mb_price}=~s/\./\,/;
  $data->{season_price}=~s/\./\,/;
  $data->{mail_price}='1,5';
  return 1;
}

sub importWithdrawal {
  my $root = shift;
  print STDERR "Import withdrawals\n";
  my $node = $root->findnodes("./withdrawal")->pop() || fatal("No such table (node): withdrawal");
  my $idname = xmlDecode($node->getAttribute('idname')) if $node->hasAttribute('idname');
  foreach my $row (reverse @{$node->findnodes("./row")}) {
    my $id = xmlDecode($row->getAttribute('id')) if $row->hasAttribute('id');
    my %h;
    foreach ($row->findnodes("./*")) {
      my $attr = $_->nodeName();
      $h{$attr} = xmlText($_);
      if ($attr=~/date/) {
        my $lang = Date::Language->new('Russian');
        $h{$attr} = $lang->str2time($h{$attr});
      }
    }
    doWithdrawal(\%h);
  }
}

sub doWithdrawal {
  my $data = shift;
  my $ym = $data->{year_month};
  $data->{service_id}=$service->ID();
  my $m = $ym % 12;
  my $y = ($ym-$m)/12;
  $y=~s/^.//;
  $m++;
  $m="0$m" if $m<10;
  $y+=2000;
  $data->{date} = MonthToDate("$y$m");
  my $period = period()->LoadByDate($service,$data->{date}) ||
    period()->Create($service,$data->{date});
  my $client = client($data->{client_id});
  my $charge = $period->LoadChargeRecord($client);
  my $new;
  unless ($charge) {
    $new = 1;
    my $tid = FindTariff($data->{client_id},$period->Data('start'),$period->Data('end'));
    my $act  = $client->getActivationsLog($period);
    $charge = tariff($tid)->NewChargeRecord($period,$client,$act);
    $charge->{season_date}=$period->Data('end');
  }

  my %ext;
  if ($data->{withdrawal_type}) {
    # traffic
    my ($ibytes,$lbytes)=(0,0);
    $ibytes=$data->{quantity} if $data->{quantity}>1;
    $charge->{traffic_summa}=$data->{summa};
    $charge->{traffic}={1=>$lbytes*1024*1024,
                        0=>$ibytes*1024*1024};
  } else {
    # season
    $charge->{season_summa}=$data->{summa};
    $charge->{season_days}=$period->Days();
  }
  $charge->{summa}+=$data->{summa};
  if ($new) {
    $period->CreateChargeRecord($charge);
  } else {
    $period->ModifyChargeRecord($charge);
  }
}

sub createAccessModes {
  my $a=access_mode();
  $a->Create({name=>'deny',
              service_id=>$service->ID(),
              rules=>{INPUT=>[
                              {source=>'$IP',
                               jump=>'DROP'},
                              {"mac-source"=>'$MAC',
                               jump=>'DROP'},
                              {destination=>'$IP',
                               jump=>'DROP'}
                             ]
                     }
             });
  $a->Create({name=>'active',
              service_id=>$service->ID(),
              rules=>{
                      FORWARD=>[
                                {"in-interface"=>'$LOCAL_INT',
                                 source=>'$IP',
                                 "mac-source"=>'$MAC',
                                 jump=>'ULOG',
                                },
                                {"out-interface"=>'$LOCAL_INT',
                                 jump=>'ULOG'},
                               ]
                     }
             });
  $a->Create({name=>'deactive',
              service_id=>$service->ID(),
              rules=>{
                      FORWARD=>[
                                {protocol=>'tcp',
                                 "destination-port"=>80,
                                 destination=>'$WWW',
                                 source=>'$IP',
                                 "mac-source"=>'$MAC',
                                 "out-interface"=>'$REAL_INT',
                                 "in-interface"=>'$LOCAL_INT',
                                 jump=>'ULOG',
                                },
                                {protocol=>'tcp',
                                 "source-port"=>80,
                                 destination=>'$IP',
                                 source=>'$WWW',
                                 "in-interface"=>'$REAL_INT',
                                 "out-interface"=>'$LOCAL_INT',
                                 jump=>'ULOG'},
                               ]
                     }
             });
  $a->Create({name=>'mail',
              service_id=>$service->ID(),
              rules=>{
                      FORWARD=>[
                                {protocol=>'tcp',
                                 "destination-port"=>80,
                                 destination=>'$WWW',
                                 source=>'$IP',
                                 "mac-source"=>'$MAC',
                                 "out-interface"=>'$REAL_INT',
                                 "in-interface"=>'$LOCAL_INT',
                                 jump=>'ULOG',
                                },
                                {protocol=>'tcp',
                                 "source-port"=>80,
                                 destination=>'$IP',
                                 source=>'$WWW',
                                 "in-interface"=>'$REAL_INT',
                                 "out-interface"=>'$LOCAL_INT',
                                 jump=>'ULOG'},

                                {protocol=>'tcp',
                                 "destination-port"=>110,
                                 destination=>'$WWW',
                                 source=>'$IP',
                                 "mac-source"=>'$MAC',
                                 "out-interface"=>'$REAL_INT',
                                 "in-interface"=>'$LOCAL_INT',
                                 jump=>'ULOG',
                                },
                                {protocol=>'tcp',
                                 "source-port"=>110,
                                 destination=>'$IP',
                                 source=>'$WWW',
                                 "in-interface"=>'$REAL_INT',
                                 "out-interface"=>'$LOCAL_INT',
                                 jump=>'ULOG'},

                                {protocol=>'tcp',
                                 "destination-port"=>25,
                                 destination=>'$WWW',
                                 source=>'$IP',
                                 "mac-source"=>'$MAC',
                                 "out-interface"=>'$REAL_INT',
                                 "in-interface"=>'$LOCAL_INT',
                                 jump=>'ULOG',
                                },
                                {protocol=>'tcp',
                                 "source-port"=>25,
                                 destination=>'$IP',
                                 source=>'$WWW',
                                 "in-interface"=>'$REAL_INT',
                                 "out-interface"=>'$LOCAL_INT',
                                 jump=>'ULOG'},

                                {protocol=>'tcp',
                                 "destination-port"=>5223,
                                 destination=>'$WWW',
                                 source=>'$IP',
                                 "mac-source"=>'$MAC',
                                 "out-interface"=>'$REAL_INT',
                                 "in-interface"=>'$LOCAL_INT',
                                 jump=>'ULOG',
                                },
                                {protocol=>'tcp',
                                 "source-port"=>5223,
                                 destination=>'$IP',
                                 source=>'$WWW',
                                 "in-interface"=>'$REAL_INT',
                                 "out-interface"=>'$LOCAL_INT',
                                 jump=>'ULOG'},
                               ]
                     }
             });

}

sub postTariffLog  {
  my $data = shift;
  my $ym = $data->{year_month};
#  $data->{service_id}=$service->ID();
  my $m = $ym % 12;
  my $y = ($ym-$m)/12;
  $y=~s/^.//;
  $m++;
  my $date = new Date::Handler({ date => [2000+$y,$m,1,0,0,0],
                                 time_zone => 'Europe/Moscow'});
  #  die "$date" if
  $TARIFF_LOG{$data->{client_id}}=[] unless $TARIFF_LOG{$data->{client_id}};
  push @{$TARIFF_LOG{$data->{client_id}}},{date=>$date,
                                           tid=>$data->{tariff_id}};
  my $period = period()->LoadByDate($service,$date) || period()->Create($service,$date);
  $data->{period_id}=$period->ID();
  delete $data->{year_month};
  #  die join(',',%$data);
  return 1;
}

sub postHost {
  my $data = shift;
  $data->{create_time}=today();
  my $cid = $data->{client_id};
  delete $data->{client_id};
  my $host = host()->Create($data);
  my $client = client($cid);
  my $date = $client->Data('reg_date');
  $host->AttachToClient($client,$aa,$date);

#  die $client->ID() if inet_ntoa($host->IP()) eq '10.100.9.200';
  return 0;
}

sub postPayment {
  my $data = shift;
  $data->{form} = $data->{summa_beznal} ? 'order' : 'cash';
  delete $data->{summa_beznal};
  return 1;
}

sub postAddress {
  my $data = shift;
  my $b = table('building')->
    Load($data->{building_id}) ||
      fatal("No such record in building table: building_id=$data->{building_id}");
  my $a = $data->{room} ? table('address')->Load({building_id=>$b->{building_id},
                                                  room=>$data->{room}}) : undef;
  $data->{room}=$data->{comment}
    || $data->{hostname} || "none:$addr" unless $data->{room};
  $addr++;
  $a = table('address')->Create({building_id=>$b->{building_id},
                                 room=>$data->{room}}) unless $a;
  fatal("Can't create address")
    unless $a;
  delete $data->{room};
  delete $data->{building_id};
  $data->{address_id}=$a->{address_id};
  return 1;
}

sub postBridge {
  my $data = shift;
  postAddress($data);
  $data->{is_active}=!$data->{dont_download};
  $data->{is_active}=0 if $data->{hostname}=~/orionet/
    || $data->{hostname}=~/bridge3/
      || $data->{hostname}=~/bridge4/;
  $data->{router_id}=$data->{bridge_id};
  #die " - $data->{address_id}";
  delete $data->{bridge_id};
  return 1;
}

sub importXml {
  my ($root,$table) = @_;
  print STDERR "Import table '$table'\n";
  my $tff=$tf{$table} || {};
#  die join(',',%$tff);# if $table eq 'tarif';
  my $tt = defined $tff->{__table} ? $tff->{__table} : $table;
  my $t = $tt eq 'tariff' ? tariff() :  ($tt ? table($tt) : undef);
  if ($tt) {
    my $t2 = table($tt);
    $t2->Delete({});
  }
  my $node = $root->findnodes("./$table")->pop() || fatal("No such table (node): $table");
  my $idname = xmlDecode($node->getAttribute('idname')) if $node->hasAttribute('idname');
  foreach my $row ($node->findnodes("./row")) {
    my $id = xmlDecode($row->getAttribute('id')) if $row->hasAttribute('id');
    my %h;
    foreach ($row->findnodes("./*")) {
      my $attr = $_->nodeName();
      next if exists $tff->{$attr} && !$tff->{$attr};
      $attr=$tff->{$attr} if exists $tff->{$attr};
      $h{$attr} = xmlText($_);
      if ($tff->{"_$attr"} eq 'date') {
        my $lang = Date::Language->new('Russian');
        $h{$attr} = $lang->str2time($h{$attr});
      }
    }
    if ($idname) {
      if ($tff->{$idname}) {
        $h{$tff->{$idname}}=$id;
      } else {
        $h{$idname}=$id;
      }
    }
    if ($tff->{__post}) {
#      die join(',',%$tff) if $table eq 'tarif';
      $t->Create(\%h) if $tff->{__post}(\%h);
    } else {
      $t->Create(\%h);
    }
  }
  $db->Commit();
}


sub importActivation {
  my ($root) = @_;
  print STDERR "Import activation\n";
  my $node = $root->findnodes("./activation")->pop() || fatal("No such table (node): activation2");
  my $idname = xmlDecode($node->getAttribute('idname')) if $node->hasAttribute('idname');
  my $aaa;
  foreach my $row (reverse @{$node->findnodes("./row")}) {
    my $id = xmlDecode($row->getAttribute('id')) if $row->hasAttribute('id');
    my %h;
    foreach ($row->findnodes("./*")) {
      my $attr = $_->nodeName();
      $h{$attr} = xmlText($_);
      if ($attr=~/date/) {
        my $lang = Date::Language->new('Russian');
        $h{$attr} = $lang->str2time($h{$attr});
      }
    }
    my $h = host()->Load($h{ip});
    my $a;
    my $ac=0;
    if ($h{activation_type}==1) {
      $ac=1;
      $a = access_mode()->LoadBy('name','active');
    } elsif ($h{activation_type}==2) {
      $a = access_mode()->LoadBy('name','mail');
      $ac=1;
    } elsif ($h{activation_type}==3) {
      $a = access_mode()->LoadBy('name','deactive');
    } else {
      $a = access_mode()->LoadBy('name','deny');
    }
    my $date = new Date::Handler({ date => $h{activation_date},
                                   time_zone => 'Europe/Moscow'});
    ;
    $h->SetAccessMode($a,
                      $date,
                      $h{activation_desc});
#    my $period = period()->LoadByDate($service,$date)
#      || period()->Create($service,$date);
    #    my $c = $service->LoadClientByIP($period,);
    my $client = client()->FindByIP($h{ip},$date);
    fatal("Не могу загрузить клиента для $h{ip}") unless $c;
    # print STDERR "$h{ip}\n";
    if ($ac) {
      $client->Activate($service,$date,$h{activation_desc});
    } else {
      $client->Deactivate($service,$date,$h{activation_desc});
    }
  }
  $db->Commit();
}


sub FindTariff {
  my ($cid,$start,$end)=@_;
  my $tt=$TARIFF_LOG{$cid};
  my $tariff;
  foreach (@$tt) {
    next if $_->{date}>$end;
    $tariff=$_ if !$tariff->{date} || $_->{date}>$tariff->{date};
  }
  return $tariff ? $tariff->{tid} : die "no tariff - cid:$cid, $start, $end. Log:".join(',',map {"$_->{tid}-$_->{date}"} @$tt);
}
