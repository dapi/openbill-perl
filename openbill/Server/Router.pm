package openbill::Server::Router;
use strict;
use openbill::Server::BaseDb;
use openbill::Router;
use openbill::Sendmail;
use openbill::Host;
use openbill::Utils;
use dpl::Db::Table;
use dpl::Db::Database;
use dpl::Error;
use Exporter;
use vars qw(@ISA);
@ISA = qw(Exporter
          openbill::Server::BaseDb);


openbill::Server::Base::addSOAPObject(router=>'openbill::Server::Router');

sub METHOD_whole_update {
  my ($self,$router_id) = @_;
  if ($router_id eq 'all') {
    db()->Query('update router set need_whole_update=1');
  } else {
    db()->Query('update router set need_whole_update=1 where router_id=?',
                $router_id);
  }
}

sub METHOD_check_loyal_hosts {
  my ($self,$p) = @_;
  $p={} unless $p;
  my $list = table('router_ip')->
    List({type=>'client'});
  my %client_ip;
  foreach (@$list) {
    next if $_->{mask}<10;
    $client_ip{$_->{router_id}}=[]
      unless $client_ip{$_->{router_id}};
    push @{$client_ip{$_->{router_id}}},$_;
  }
  my $hosts = table('host')->List();
  #  print "Hosts: ",scalar @$hosts,"\n";
  my @list;
  foreach my $h (@$hosts) {
    push @list,$h
      unless CheckIP($h->{ip},$client_ip{0},$client_ip{$h->{router_id}});
  }
  my @notused;
  foreach my $a (keys %client_ip) {
    foreach (@{$client_ip{$a}}) {
      unless ($_->{count}) {
        if ($p->{delete_not_used}) {
          table('router_ip')->Delete({mask=>$_->{mask},
                                      bits=>$_->{bits},
                                      router_id=>$_->{router_id}})
        } else {
          push @notused,$_;
        }
      }
    }

  }
  return {hosts=>scalar @$hosts,
          notused=>\@notused,
          list=>\@list};
}


sub CheckIP {
  my ($ip,$a1,$a2)=@_;
  foreach (@$a1,@$a2) {
    return ++$_->{count} if $_->{mask}==$ip>>$_->{bits};
  }
  return undef;
}

sub ConvertIP  {
  my $ip = shift;
  if ($ip eq 'router') {
    $ip='0.0.0.1';
  } elsif ($ip eq 'router_real') {
    $ip='0.0.0.2';
  } elsif ($ip eq 'routers') {
    $ip='0.0.0.3';
  } elsif ($ip eq 'routers_real') {
    $ip='0.0.0.4';
  } elsif ($ip eq 'hosts') {
    $ip='0.0.0.5';
  } else {
    return $ip;
  }
}

sub METHOD_list_router_ip {
  my ($self,$p) = @_;
  return table('router_ip')->List($p);
}

sub METHOD_add_ip {
  my ($self,$p) = @_;
  fatal("Не все параметры указаны (router, type, net, comment)")
    unless defined $p->{router} && $p->{type} && $p->{net} && $p->{comment};
  fatal("Не указан или неизвестный тип")
    unless $p->{type} eq 'local' || $p->{type} eq 'client';
  my $i = inet_atobm($p->{net}) || fatal("Неверно указан net");
  #   my $typestr = $p->{type} eq 'local' ? 'локальный' : 'клиентский';
  #    print "Добавляю $typestr ".inet_bmtoa($i)." к роутеру ".$r->string()."\n";
  table('router_ip')->Create({router_id=>$p->{router},
                              type=>$p->{type},
                              mask=>$i->{mask},
                              bits=>$i->{bits},
                              comment=>$p->{comment}});
}

sub METHOD_delete_ip {
  my ($self,$router_id,$type,$net)=@_;
  my $r = router()->Load($router_id);
  fatal("Не указан или неизвестный тип ($type)")
    unless $type eq 'local' || $type eq 'client';
  my $i = inet_atobm(ConvertIP($net));
  my $typestr = $type eq 'local' ? 'локальный' : 'клиентский';
  print "Удаляю $typestr ".inet_bmtoa($i)." от роутера ".$r->string()."\n";
  table('router_ip')->Delete({router_id=>$r->ID(),
                              type=>$type,
                              mask=>$i->{mask},bits=>$i->{bits}});
  return 1;
}


sub METHOD_copy_hosts {
  my ($self,$src_id,$dst_id)=@_;
  my $router_src=router($src_id)->Load() || fatal("Не найден роутер источник $src_id");
  my $router_dst=router($dst_id)->Load() || fatal("Не найден роутер назначение $dst_id");
  my $list = host()->List({router_id=>$src_id});
#  my $free = $router_dst->GetFreeIPs();
#  fatal("Слишком много хостов") if @$free<@$list;
  my @h;
  foreach my $h (@$list) {
    my $dd = $h->Data();
    my %d=%$dd;
#    die join(',',keys %$d);
    my %r={old=>$h->DataFull()};
        $d{hostname}="$d{router_id}_$d{hostname}";
    $d{router_id}=$dst_id;
 #   my $f = shift @$free;
#    $d{ip}=inet_aton($f);
    $d{am_time}=undef;

    $d{comment}="old_host_id:$d{host_id} $d{comment}";
    delete $d{host_id};
    my $nh = host()->Create(\%d);
    $r{new}=$nh->DataFull();
  }
  return \@h;
}

sub METHOD_clean_hosts {
  my ($self,$p)=@_;
  my $force = $p->{force};
  delete $p->{force};
  my $router=router($p->{router_id})->Load() || fatal("Не найден роутер источник $p->{router_id}");
  my $list = host()->List({router_id=>$p->{router_id}});
  #   my $free = $router_dst->GetFreeIPs();
  #   fatal("Слишком много хостов") if @$free<@$list;
  #   my @h;
  my %H;
  my $traff = iptraff()->GetTraffic($p,['host_id']);
  foreach my $k (sort keys %$traff) {
    $H{$k}=1;
  }
  my $deleted=0;
  foreach my $h (@$list) {
    my $dd = $h->DataFull();
    my $id = $h->ID();
   # $h->Modify({hostname=>"14_$dd->{hostname}"});
    #      if $dd->{hostname}=~s/[^a-z_0-9]/_/g;
#    print "Host: $id, $dd->{host}\n";
    unless (exists $H{$id}) {
      print "Delete host: $id, $dd->{host}\n";
      $h->Modify({router_id=>100+$dd->{router_id}})
        if $force;
      #      table('host')->Delete({comment=>"old_host_id:$id"});
      $deleted++;
    }
  }
  return $deleted;
}


sub METHOD_check_host {
  my ($self,$id) = (shift,shift);
  return router($id)->CheckHost(@_) || return undef;
}

sub METHOD_get {
  my ($self,$id) = @_;
  my $r = router()->Load($id) || return undef;
  my $d = $r->DataFull();
  return $d;
}

sub METHOD_get_next_free_ip {
  my ($self,$id,$subnet_ip) = @_;
  my $b = router()->Load($id) || return undef;
  return $b->GetNextFreeIP($subnet_ip);
}

sub METHOD_find {
  my ($self,$router) = @_;
  my $r = router()->Find($router);
  return ref($r) ? $r->DataFull() : $r;
}

sub METHOD_list {
  my ($self,$p) = @_;
  $p={} unless $p;
  my $list = openbill::Router::router()->List($p);
  return [map {$_->DataFull()} @$list];
}

sub METHOD_create {
  my ($self,$data) = @_;
  my $r = router()->Create($data) || return undef;
  notify('create_router',{router=>$r->DataFull()});
  return $r->ID();
}

sub METHOD_modify {
  my ($self,$id,$data) = @_;
  my $router = router($id);
  my $old = $router->DataFull();
  my $res = $router->Modify($data);
  return undef unless $res;
  notify('modify_router',{new=>$router->DataFull(),
                          old=>$old});
  return $res;
}

sub METHOD_delete {
  my ($self,$id) = @_;
  return router($id)->Delete($id);
}

sub METHOD_makeSshKey {
  my ($self,$id) = @_;
  return router($id)->MakeSshKey();
}



1;
