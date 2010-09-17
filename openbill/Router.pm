package openbill::Router;
use strict;
use openbill::Host;
use openbill::Base;
use openbill::Utils;
use openbill::Address;
use openbill::Building;
use openbill::Street;
use openbill::System;
use openbill::Janitor;
use dpl::Log;
use dpl::Db::Table;
use dpl::Db::Filter;
use dpl::Db::Database;
use dpl::Context;
use Exporter;
use vars qw(@ISA
            @EXPORT);

@ISA=qw(Exporter
        openbill::Base);

@EXPORT=qw(router);

sub router {
  return openbill::Router->instance('router',@_);
}

sub DataFull {
  my ($self,$key) = @_;
  $self->Load() unless $self->isLoaded();
  $self->{data}->{address}||=$self->address()->string();
  my $building = building($self->address()->Data('building_id'));
  $self->{data}->{building} = $building->Data('number');
  $self->{data}->{room} = $self->address()->Data('room');
  $self->{data}->{street}||=street($building->Data('street_id'))->Data('name');
  unless (exists $self->{data}->{free_ips}) {
    my $f = $self->GetFreeIPs();
    $self->{data}->{free_ips}=$f ? scalar @$f : 0;
  }
  return $key ? $self->{data}->{$key} : \%{$self->{data}};
}

sub address {
  my $self = shift;
  return openbill::Address::address($self->Data('address_id'));
}

sub CheckHost {
  my $self = shift;
  my $janitor=janitor($self->{data}->{default_janitor_id});
  my $res = $janitor->CheckLink($self,@_);
  return {} unless $res;
  return $res;
}

sub GetNextFreeIP {
  my ($self,$subnet_ip,$client_ip_min,$client_ip_max) = @_;
  my $min = inet_aton($client_ip_min || $self->Data('client_ip_min'));
  my $max = inet_aton($client_ip_max || $self->Data('client_ip_max'));
  if ($subnet_ip) {
    my $list = $self->GetIPs('client');
    foreach (@$list) {
      my $i = inet_aton($subnet_ip) >> $_->{bits};
      if ($i==$_->{mask}) {
        $min=($_->{mask} << $_->{bits}) + 10;
        $max=$min-8+ (1 << $_->{bits});
        last;
      }
    }
  }
  return undef unless $min && $max;
  my $list = table('host')->List(router_id=>$self->Data('id'));
  my %ips;
  foreach (@$list) {
    $ips{$_->{ip}}=1 if !$_->{bits} && $_->{ip}>=$min && $_->{ip}<=$max;
  }
  foreach my $ip ($min..$max) {
    return inet_ntoa($ip) unless exists $ips{$ip};
  }
  return undef;
}

sub GetFreeIPs {
  my $self = shift;
  my $min = inet_aton($self->Data('client_ip_min'));
  my $max = inet_aton($self->Data('client_ip_max'));
  return [] unless $min && $max;
  my $list = table('host')->List(router_id=>$self->Data('id'));
  my %free;

  my $m = $min;
  do {
    $free{$m}=1;
  } while ($m++<=$max);
  my @free;
  foreach (@$list) {
    next if $_->{bits};
    delete $free{$_->{ip}};
  }
  return [map {inet_ntoa($_)} keys %free];
}

sub name {
  my $self = shift;
  my $id = $self->ID();
  my $d = $self->Data();
  return "[$id] $d->{hostname} $d->{ip}";
}

sub List {
  my ($self,$p) = @_;
  if (exists $p->{like}) {
    my $like = $p->{like};
    delete  $p->{like};
    my @a=("hostname like '%$like%' or shortname like '%$like%'");
    unshift @a,$p if %$p;
    $p=\@a;
  }
  return $self->SUPER::List($p);
}

sub Find {
  my ($self,$like) = @_;
  my $list;
  if ($like=~/^\d+\.\d+\.\d+\.\d+$/) {
    $list = $self->List({or=>{real_ip=>$like,
                              ip=>$like}}) || return undef;
  } else {
    $list = $self->List({hostname=>$like}) || return undef;
  }
  return @$list==1 ? $list->[0] : scalar @$list;
}

sub Delete {
  my $self = shift;
  die 'not implemented';
}

sub Create  {
  my ($self,$data) = @_;
  $self->checkParams($data,'hostname','ip','address_id','default_janitor_id');
  return $self->SUPER::Create($data);
}

sub string {
  my ($self,$full) = @_;
  my $id = $self->ID(1);

  my $str = "[$id] ";
  my $d = $self->Data();
  return $d->{hostname};
  $str.="$d->{hostname} / $d->{ip}";
  return $str unless $full;
  $str.=" / $d->{real_ip} ($d->{shortname})\n";
#  $str.="\tАдрес: ".$self->GetAddress()->string()."\n";
#  $str.="\t- $d->{comment}\n"
#    if $d->{comment};
  return "$str";
}

sub GetIPs {
  my ($self,$type) = @_;
  die "Type '$type' is not supported more"
    unless $type eq 'client';
  my $list = table('router_ip')->
    List({router_id=>$self->ID, type=>$type});
  my $l = table('router_ip')->
    List({router_id=>0, type=>$type});
  push @$list,@$l
    if $l && @$l;
  my @a;
  # 1 - ip-адрес роутера
  # 2 - real_ip-адрес роутера
  # 3 - ip адреса всех роутеров
  # 4 - real_ip адреса всех роутеров
  # 5 - ip-адреса всех хостов
  foreach (@$list) {
    if (!$_->{bits} && $_->{mask}==1) {
      push @a,{mask=>inet_aton($self->Data('ip')),bits=>0,mark=>'router'};
    } elsif (!$_->{bits} && $_->{mask}==2) {
      push @a,{mask=>inet_aton($self->Data('real_ip')),bits=>0,mark=>'router_real'};
    } elsif (!$_->{bits} && $_->{mask}==3) {
      foreach (@{table('router')->List()}) {
        push @a, {mask=>inet_aton($_->{ip}),bits=>0,mark=>'routers'};
      }
    } elsif (!$_->{bits} && $_->{mask}==4) {
      foreach (@{table('router')->List()}) {
        push @a, {mask=>inet_aton($_->{real_ip}),bits=>0,mark=>'routers_real'};
      }
    } elsif (!$_->{bits} && $_->{mask}==5) {
      foreach (@{table('host')->List({router_id=>$self->ID()})}) {
        push @a, {mask=>inet_aton($_->{ip}),bits=>0,mark=>'hosts'};
      }
    } else {
      push @a,{mask=>$_->{mask}, bits=>$_->{bits}};
    }
  }
  #  logger()->debug("Адреса типа $type для роутера $self->{id}",
  #                  join('; ',map {"$_->{mask}/$_->{bits}"} @a));
  return \@a;
}

sub MakeSshKey {
  my ($self) = @_;
  #TODO
  # Проверку на наличие ключа чтоы не переписать его
#  unless ($ENV{SSH_AGENT_PID} && $ENV{SSH_AUTH_SOCK}) {
#    fatal("Нетвозможности соедениться с ssh-agent - переменная SSH_AGENT_PID или SSH_AUTH_SOCK неустановлена")
#  }
  my $dir = directory('ssl_keys');
  my $r = $self->Data();
  fatal("Запуск этой функции возможен только в консольном режим.")
    unless setting('terminal');
  my $login=$r->{login} || 'root';
  print "Создаю ssh-ключ для $r->{hostname}: ";
  print `rm -f $dir$r->{hostname} && ssh-keygen -q -t dsa -f $dir$r->{hostname} -N ''`;
  my $cmd="cat $dir$r->{hostname}.pub | ssh $login\@$r->{real_ip} 'cat > .ssh/authorized_keys'";
  print "Ok\nКопирую ключ $cmd: ";
  print `$cmd`;
  my $code=$?;
  if ($code) {
    logger()->error("Ошибка создания публичного ключа для ssh: $code");
  } else {
    logger()->debug("Ключ создан.");
  }
  print "Готово\n";
}

1;
