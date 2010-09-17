package openbill::Server::Payment;
use strict;
use dpl::Db::Database;
use dpl::Db::Table;
use dpl::Db::Filter;
use dpl::Error;
use dpl::Log;
use dpl::System;
use dpl::Context;
use openbill::Server::BaseDb;
use openbill::Client;
use openbill::Payment;
use Exporter;
use vars qw(@ISA);
@ISA = qw(Exporter
          openbill::Server::BaseDb);

openbill::Server::Base::addSOAPObject(payment=>'openbill::Server::Payment');

sub METHOD_methods {
  my ($self,$p) = @_;
  return $p ? table('payment_method')->HashList() : table('payment_method')->List();
}

sub METHOD_getMethod {
  my ($self,$p) = @_;
  return table('payment_method')->Load($p);
}

sub PrepareParams {
  my ($p) = @_;
  my @p;
  my @bind;
  if (exists $p->{manager_id}) {
    $p->{'payment.manager_id'}=$p->{manager_id};  delete $p->{manager_id};
  }
  if (exists $p->{payment_method_id}) {
    $p->{'payment.payment_method_id'}=$p->{payment_method_id};  delete $p->{payment_method_id};
  }
  if (exists $p->{client_id}) {
    $p->{'payment.client_id'}=$p->{client_id};  delete $p->{client_id};
  }
  if (exists $p->{from_id}) {
    push @p,"payment.id>=?";
    push @bind,$p->{from_id};
    delete $p->{from_id};
  }
  if (exists $p->{to_id}) {
    push @p,"payment.id<=?";
    push @bind,$p->{to_id};
    delete $p->{to_id};
  }
  if (exists $p->{from_summa_order}) {
    push @p,"summa_order>=?";
    push @bind,$p->{from_summa_order};
    delete $p->{from_summa_order};
  }
  if (exists $p->{to_summa_order}) {
    push @p,"to_summa_order<=?";
    push @bind,$p->{to_summa_order};
    delete $p->{to_summa_order};
  }
  if (exists $p->{to_date}) {
    push @p,"date<=?";
    push @bind,filter('date')->ToSQL($p->{to_date});
    delete $p->{to_date};
  }
  if (exists $p->{from_date}) {
    push @p,"date>=?";
    push @bind,filter('date')->ToSQL($p->{from_date});
    delete $p->{from_date};
  }
  if (exists $p->{date}) {
    push @p,"date=?";
    push @bind,filter('date')->ToSQL($p->{date});
    delete $p->{date};
  }
  if (exists $p->{comment}) {
    push @p,"payment.comment like ?";
    push @bind,"%$p->{comment}%";
    delete $p->{comment};
  }


  if (%$p) {
    foreach (keys %$p) {
      if ($p->{$_}=~/\*/) {
        $p->{$_}=~s/\*/\%/g;
        push @p,"$_ like ?";
        push @bind, lc($p->{$_});
        delete $p->{$_};
      }
    }
    push @p,$p if %$p;
  }
  return \@p,@bind;
}


sub METHOD_list {
  my ($class,$where,$order,$start,$limit)=@_;
  $start+=0;
  $limit=$limit+0 || 20;
  my $date;
  $where={} unless $where;
  foreach (keys %$where) {
    delete $where->{$_} if $where->{$_} eq "";
  }
  my $db = db();
  my ($p,@bind) = PrepareParams($where);
  my $w = $db->prepareData($p,'and',\@bind,1);
  my $pm = table('payment_method')->HashList();
  $pm->{0}={};
  $w="WHERE $w"
    if $w;

  my $q=qq(select count(payment.id) as max
           from payment $w);

  $db->Connect();
  logger('sql')->debug($q,join(',',@bind));
  my $sth = $db->{dbh}->prepare($q);
  my $rv  = $sth->execute(@bind);
  my $max = $db->Fetch($sth)->{max};
  fatal("Запрещённые символы в параметре сортировки. Можно только a-z и ,") if $order=~/[^a-z ,]/;
  my $o = $order ? "order by $order" : '';
  my $query = qq(SELECT payment.*,
                 manager.name as manager,
                 client.name as client_name, client.firmname as client_firmname, client.is_firm as client_is_firm,
                 payment_method.name as method
                 FROM payment
                 left join manager on manager.manager_id=payment.manager_id
                 left join client on client.client_id=payment.client_id
                 left join payment_method on payment_method.id=payment.payment_method_id
                 $w $o limit $start,$limit);
  logger('sql')->debug($query,' -values are- ',@bind);
  my $sth = $db->{dbh}->prepare($query);
  my $rv  = $sth->execute(@bind);
  my @list;
  while (my $f = $db->Fetch($sth)) {
    $f->{date} = filter('date')->FromSQL($f->{date});
    $f->{timestamp} = filter('timestamp')->FromSQL($f->{timestamp});
    $f->{description} = $f->{type} ? 'Услуги связи' : 'Подключение';
    $f->{description} = 'Реализация' if $f->{type}==2;
    $f->{client} = $f->{is_firm} ? $f->{client_firmname} : $f->{client_name};
    $f->{client} = "[$f->{client_id}] $f->{client}";
    $pm->{$f->{payment_method_id}}->{summa}+=$f->{summa};
    $pm->{$f->{payment_method_id}}->{summa_order}+=$f->{summa_order};
    $pm->{$f->{payment_method_id}}->{count}++;
    $pm->{0}->{count}+=1;
    $pm->{0}->{summa}+=$f->{summa};
    $pm->{0}->{summa_order}+=$f->{summa_order};
    push @list,$f;
  }
  $pm->{0}->{name}='По всем';
  return {start=>$start,
          payment_methods=>$pm,
          limit=>$limit,
          max=>$max,
          list=>\@list};
}

sub METHOD_get {
  my ($class,$id) = @_;
  my $p = openbill::Payment::payment($id) || return undef;
  my $data = $p->DataFull();
  $data->{log}=table('payment_log')->List({payment_id=>$id});
  return $data;
}

sub METHOD_modify {
  my ($self,$id,$data) = @_;
  delete $data->{method}; # TODO сделать фильтр аттрибутов
  my $old = payment()->Load($id) || fatal("Нет такого платежа $id");
  my %log=%{$old->Data()};
  $log{payment_id}=$id;
  $log{timestamp}=today();
  $log{manager_id}=context('manager')->ID();
  $log{new_client_id}=$data->{client_id}
    if exists $data->{client_id};
  $log{new_summa}=$data->{summa}
    if exists $data->{summa};
  $log{new_summa_order}=$data->{summa_order}
    if exists $data->{summa_order};
  $log{new_payment_method_id}=$data->{payment_method_id}
    if exists $data->{payment_method_id};
  $log{new_date}=$data->{date}
    if exists $data->{date};
  $log{new_type}=$data->{type}
    if exists $data->{type};
  $log{new_comment}=$data->{comment}
    if exists $data->{comment};
  $log{modify_comment}=$data->{modify_comment};
  delete $log{secret_comment};
  delete $log{id};
  delete $log{balance};
  delete $log{invoice_id};
  fatal("Не указана причина исправления") unless $data->{modify_comment};
  delete $data->{modify_comment};
  #  die join(',',%log);
  table('payment_log')->Create(\%log);
  my $res = payment($id)->Modify($data);
  return undef unless $res;
  #  $res->{diff} =
  if (exists $data->{client_id}) {
    client($data->{client_id})->RestoreBalance();
    client($old->Data('client_id'))->RestoreBalance()
      unless $data->{client_id}==$old->Data('client_id');
  } else {
    client($old->Data('client_id'))->RestoreBalance();
  }
  if (!$old->Data('type') || !$data->{type}) {
    my $nc = client($data->{client_id} || $old->Data('client_id'));
    my $ns = $nc->Data('real_payment_summ');
    $ns+=$data->{summa} unless $data->{type};

    if (!$old->Data('type')) {
      if ($old->Data('client_id')==$data->{client_id}) {
        $ns-=$old->Data('summa');
      } else {
        my $oc = client($old->Data('client_id'));
        my $os = $oc->Data('real_payment_summ');
        $os-=$old->Data('summa');
        $oc->Modify({real_connection_summ=>$os});
      }
    }

    $nc->Modify({real_connection_summ=>$ns});
    db()->Commit();
  }

  # TODO Делать Recharge клиента в payment->modify
  return $res;
}

sub METHOD_delete {
  my ($self,$id) = @_;
  return payment($id)->Delete();
}

sub METHOD_ext_list {
  my ($self,$h) = @_;
  $h={} unless $h;
  my $methods = table('payment_method')->HashList();
  my $db = db();
  #   $db->Connect();
  #   $db->Commit();
  my @w;
  my @bind;
  if ($h->{date_from}) {
    push @w,"date>=?";    push @bind,filter('date')->ToSQL($h->{date_from});
  }
  if ($h->{date_to}) {
    push @w,"date<=?";    push @bind,filter('date')->ToSQL($h->{date_to});
  }

  if ($h->{id_to}) {
    push @w,"id<=?";    push @bind,$h->{id_to};
  }
  if ($h->{id_from}) {
    push @w,"id>=?";    push @bind,$h->{id_from};
  }

  foreach (qw(payment_method_id client_id type)) {
    next unless exists $h->{$_};
    push @bind,$h->{$_};
    my $k = $_;
    $k='payment.payment_method_id' if $_ eq 'payment_method_id';
    $k='payment.client_id' if $_ eq 'client_id';
    push @w,"$k=?";
  }

  my $w = join(' and ',@w);

  my $query =
    qq(select payment.*, manager.name as manager_name,
       client.name as name, client.is_firm as is_firm, client.firmname as firmname
       from payment
       left join client on payment.client_id=client.client_id
       left join manager on payment.manager_id=manager.manager_id
       where $w);
  #  $query="$query $extra" if $extra;
  my $sth = $db->{dbh}->prepare($query);
  my $rv  = $sth->execute(@bind);
  my @list;

  my %ms = (0=>{});
  logger('sql')->debug("PAYMENTS");
  logger('sql')->debug($query,' bind ',@bind);

  while (my $f = $db->Fetch($sth)) {
    $f->{date}=filter('date')->FromSQL($f->{date});
    $f->{client} = GetClientName($f);

    $f->{payment_method}=$methods->{$f->{payment_method_id}};
#    $f->{manager}=$managers->{$f->{manager_id}};
    push @list,$f;
#    logger('sql')->debug("FETCH: ". join(',',%$f));
    $ms{$f->{payment_method_id}}={} unless $ms{$f->{payment_method_id}};
    $ms{$f->{payment_method_id}}->{$f->{type}}+=$f->{summa};
    $ms{$f->{payment_method_id}}->{all}+=$f->{summa};
    $ms{0}->{$f->{type}}+=$f->{summa};
    $ms{0}->{all}+=$f->{summa};

  }
  $methods->{0}={name=>'По всем'};
  #  $db->Disconnect();
  return {list=>\@list,
          ms=>\%ms,
          methods=>$methods,
         }
}

sub GetClientName {
  my $client = shift;
  return "$client->{firmname} ($client->{name})" if $client->{is_firm};
  return $client->{firmname} ? "$client->{name} ($client->{firmname})" : "$client->{name}";
}


1;
