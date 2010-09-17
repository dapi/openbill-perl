package openbill::Shell::Router;
use strict;
use dpl::Error;
use openbill::Shell;
use openbill::Utils;
use dpl::Context;
use openbill::Shell::Base;
use Exporter;
use vars qw(@ISA
            @EXPORT);
@ISA=qw(Exporter
        openbill::Shell::Base);

registerCommands('openbill::Shell::Router',
                 {
                  _copy_hosts=>{},
                  _clean_hosts=>{},
                  show_router=>{},
                  list_routers=>{},
                  create_router=>{},
                  delete_router=>{},
                  modify_router=>{},
                  make_router_sshkey=>{},
                  list_router_ip=>{},
                  delete_router_ip=>{},
                  add_router_ip=>{},
                  check_loyal_hosts=>{},
                  whole_update_router=>{},
                 });


sub CMD_whole_update_router {
  my ($self,$p) = @_;
  my ($router_id)= $self->strToArr($p);
  if ($router_id) {
    my $r = $self->
      soap('router',
           'whole_update',$router_id);
    print "Ok\n";
  } else {
    print "whole_update_router [router_id|all]\n��������� ����� �� ������ ������ ���� ������ � ������������\n";
  }
}

sub CMD_check_loyal_hosts {
  my ($self,$p) = @_;
  my $p  = $self->strToHash($p);
  my $r =
    $self->soap('router',
                'check_loyal_hosts',$p);
  print "���������� ������ $r->{hosts}\n����� �� ����������� � �������� ��� ����������:\n";
  if (@{$r->{list}}) {
    my  $table = Text::FormatTable->new('l | l | l | l');
    $table->head('router', 'host', 'client', "IP");
    $table->rule('=');
    foreach my $h (@{$r->{list}}) {
      $table->row($h->{router_id},$h->{host_id},$h->{client_id},inet_ntoa($h->{ip}));
    }
    $self->showTable($table);
  } else {
    print "��� �����\n";
  }
  print "\n�������������� ���������� ���� (������� ����� delete_not_used=1):\n";
  if (@{$r->{notused}}) {
    my  $table = Text::FormatTable->new('l | l | l | l');
    $table->head('mask', 'router', 'type', 'comment');
    $table->rule('=');
    foreach my $h (@{$r->{notused}}) {
      my $b = 32-$h->{bits};
      $table->row(inet_ntoa($h->{mask}<<$h->{bits})."/$b",$h->{router_id},$h->{type},$h->{comment});
    }
    $self->showTable($table);
  } else {
    print "��� �����\n";
  }

}


sub questrouter {
  my ($self,$p) = @_;
 # die join(',',%$p);
  my $janitors = $self->soap('janitor','list');
  fatal("�������� ������� ������ ������ �����������") unless $janitors && @$janitors;
  return $self->{shell}->
    Question('router',[
                       {key=>'ip',name=>'IP',obligated=>1},
                       {key=>'real_ip',name=>'�������� IP',obligated=>1},
                       {key=>'mac',name=>'MAC-�����',obligated=>1},
                       {key=>'hostname',name=>'��� �����',obligated=>1},
                       {key=>'shortname',name=>'�������� ��� �����',obligated=>1},
                       {key=>'client_ip_min',name=>'����������� ���������� IP'},
                       {key=>'client_ip_max',name=>'������������ ���������� IP'},
                       {key=>'street',name=>'�����',obligated=>1,
                        post=>sub {
                          my $params=shift;
                          my $id = $self->soap('street','find',$params->{street})
                            || return undef;
                          delete $params->{street};
                          $params->{street_id}=$id;
                        }},
                       {key=>'building',name=>'���',obligated=>1,post=>sub {
                          my $params=shift;
                          my $id = $self->soap('building','find',
                                               $params->{street_id},
                                               $params->{building})|| return undef;
                          delete $params->{building};
                          delete $params->{street_id};
                          $params->{building_id}=$id;
                        }},
                       {key=>'room',name=>'��������/����',obligated=>1,post=>sub {
                          my $params=shift;
                          my $id =
                            $self->soap('address','find_or_create',
                                        $params->{building_id},
                                        $params->{room}) || return undef;
                          delete $params->{room};
                          delete $params->{building_id};
                          $params->{address_id}=$id;
                        }},
                       {key=>'altitude',name=>'������',obligated=>0},
                       {key=>'login',name=>'login',obligated=>0},
                       {key=>'default_janitor_id',name=>'����������',obligated=>1,
                        post=>sub {
                          my $params=shift;
                          foreach my $j (@$janitors) {
                            return $params->{default_janitor_id}=$j->{id}
                              if $j->{id} == $params->{default_janitor_id}
                                || $j->{name} == $params->{default_janitor_id};
                          }
                          print  "������ ��������� ������������:\n";
                          foreach my $j (@$janitors) {
                            print "$j->{name}\t$j->{comment}\n";
                          }
                        }},
                       {key=>'use_janitor',name=>'������������ ����������',obligated=>1,type=>'boolean',pre=>sub {'��';}},
                       {key=>'is_active',name=>'����������� ������',obligated=>1,type=>'boolean',pre=>sub {'��';}},
                       {key=>'comment',name=>'����������'}
                      ],$p);
}


sub CMD_add_router_ip {
  my ($self,$p) = @_;
  unless ($p) {
    print "���������: router=0|router_id type=local|client net=10.100.0.0/16 comment=\n";
    return 0;
  }
  my $p = $self->strToHash($p);
  if ($self->soap('router','add_ip',$p)) {
    print "�������\n";
  } else {
    print "������ ��������\n";
  }
}

sub CMD_list_router_ip {
  my ($self,$p) = @_;
  unless ($p) {
    print "���������: type=local|client router_id=0|�����\n";
    return 0;
  }
  my $p = $self->strToHash($p);
  my $res = $self->soap('router','list_router_ip',$p);
  if ($res) {
    my $table = Text::FormatTable->new('r | l | l | l');
    $table->head('������', '����', '���', '�����������');
    $table->rule('=');
    foreach my $h (@$res) {
      my $b = 32-$h->{bits};
      $table->row($h->{router_id},inet_ntoa($h->{mask}<<$h->{bits})."/$b",$h->{type},$h->{comment});
    }
    $self->showTable($table);
    print "OK\n";
  } else {
    print "������ ��������\n";
  }
}


sub CMD_delete_router_ip {
  my ($self,$p) = @_;
  unless ($p) {
    print "���������: router_id=? type=local|client net=10.100.0.0/16\n";
    return 0;
  }
  my $p = $self->strToHash($p);
  my $res = $self->soap('router','delete_ip',$p->{router_id},$p->{type},$p->{net});
  print "�������\n";
}


sub CMD_make {
  my ($self,$p) = @_;
  my $p  = $self->strToArr($p);
  if ($p->{router}) {
    my $r = router()->LoadBy('name',$p->{router});
    $r->MakeSshKey();
  } else {
    map {$_->MakeSshKey()} @{router()->List()};
  }
}

sub CMD_create {
  my ($self,$p) = @_;
  my $s = router();
  return print "���������� ������� ������. �������� ����� ��� ����."
    unless defined $s->Create($p);
  print "������ ������ #".$s->ID();
}

sub GetRouter {
  my ($self,$id) = @_;
  my $res = $self->soap('router','get',$id);
  fatal("��� ������ �������") unless $res;
  fatal("����� �������� ����� ������ - $res.") if !ref($res) && $res>1;
  return $res;
}

sub CMD_make_router_sshkey {
  my ($self,$id) = @_;
  return $self->soap('router','makeSshKey',$id);
}

sub CMD__copy_hosts {
  my ($self,$p) = @_;
  my ($src,$dst)= $self->strToArr($p);
  print "������� ����� � ������� ID:$src �� ID:$dst:\n";
  my $list = $self->soap('router','copy_hosts',$src,$dst);
  foreach (@$list) {
    print "$_->{old}->{host} -> $_->{new}->{host}\n";
  }
  print "������\n";
}

sub CMD__clean_hosts {
  my ($self,$p) = @_;
  my $p = $self->strToHash($p);
  # ������� ����� �� ������������ � ������ ��������� ���
  # ���������� ����� ������
  # ������: _clean_hosts router_id=1 date_from=2005-12-01 date_to=2006-01-30

  $p->{from_date}=ParseDate($p->{from_date}) || fatal("�������� ���� from_date");
  $p->{to_date}=ParseDate($p->{to_date}) || fatal("�������� ���� to_date");
  print "������ ����� � ������� ID:$p->{router_id} �� ������ $p->{from_date} - $p->{to_date}:\n";
  my $res = $self->soap('router','clean_hosts',$p);
  print "������ ($res)\n";
}



sub CMD_show_router {
  my $self = shift;
  my $r = $self->GetRouter(@_);
  my $table = Text::FormatTable->new('r | l');
  $table->rule('=');
  $table->row('ID',$r->{router_id});
  $table->row('IP',"$r->{ip} / $r->{real_ip} / $r->{mac}");
  $table->row('MAC',"$r->{mac}");
  $table->row('hostname',"$r->{hostname} / $r->{shortname}");
  $table->row('���������� IP',"�� $r->{client_ip_min} - $r->{client_ip_max}, �������� $r->{free_ips}")
    if $r->{client_ip_min} || $r->{client_ip_max};
  $table->row('login',"$r->{login}")
    if $r->{login};
  $table->row('�������',$r->{is_active} ? '��' : '���');
  $table->row('�����',$r->{address});
  $table->row('������',"$r->{altitude} �.")
    if $r->{altitude};
  $table->row('������ ������',$r->{firstwork_time});
  $table->row('����� ������ ������ �����������',$r->{need_whole_update} ? '��' : '���');
  $table->row('����������',$r->{comment})
    if $r->{comment};
  $table->rule('-');

  # TODO ������� ���� �� ���� ��������
  #my $period = period()->LoadByDate($service,today());
  #  my ($t,$g) = openbill::Service::IPTraff->GetTraffic({router_id=>$r->ID(),
  #                                                       from=>$period->Data('start'),
  #                                                       to=>$period->Data('end'),
  #                                                      },'class');
  #  $table->row('������ �� �����',FormatBytes($t->{0}).' / '.FormatBytes($t->{1}));
  #  ($t,$g) = openbill::Service::IPTraff->GetTraffic({router_id=>$r->ID(),
  #                                                    date=>today()},'class');
  #  $table->row('������ �� ������� ('.today()->string().')',FormatBytes($t->{0}).' / '.FormatBytes($t->{1}));
  $table->row('��������� ������',$r->{lastwork_time});
  #  $table->rule('-');
  #
  #  $table->row('��������� ������',join(', ',inet_bmtoa(@{$r->GetIPs('local')})));
  #  $table->row('���������� ������',join(', ',inet_bmtoa(@{$r->GetIPs('client')})));
  $self->showTable($table);
  return 0;
}

sub CMD_list_routers {
  my $self = shift;
  my $list = $self->soap('router','list');
  print "������ �������� (".(scalar @$list)."):\n";
  my $table = Text::FormatTable->new('r| l l l l');
  $table->head('id', '����', 'IP', '�����', '�����������');
  $table->rule('=');
  foreach my $d (@$list) {
    my $id = $d->{router_id};
    $id="0$id" if $id<10;
    my $alt;
    $alt="\n������: $d->{altitude} �." if $d->{altitude};
    $table->row($id, "$d->{hostname}\n$d->{shortname}",
                "$d->{ip}\n$d->{real_ip}\n$d->{mac}" ,
                "$d->{address}$alt",
                $d->{comment});
    $table->rule();
  }

  $self->showTable($table);
}

sub CMD_create_router {
  my ($self,$p) = @_;
  print "�������� ������ �������:\n";

  $p=$self->questrouter($p) || return undef;
  if (my $id = $self->soap('router','create',$p)) {
    print "������ ������ #$id\n";
    return 1;
  } else {
    print "������ �� ������\n";
    return 0;
  }
}

sub CMD_delete_router {
  my $self = shift;
  if ($self->soap('router','delete',@_)) {
    print "������ ���̣�\n";
    return 0;
  } else {
    print "������ �� ���̣�\n";
    return 1;
  }
}

sub CMD_modify_router {
  my ($self,$id,$p) = @_;
  my $p  = $self->strToHash($p);
  my $data = $self->soap('router','get',$id);
  unless ($data) {
    print "��� ������ �������\n";
    return 1;
  }
  foreach (keys %$data) {
    $data->{$_}=$p->{$_}
      if exists $p->{$_};
  }
  print "��������� �������:\n";
  $p=$self->questrouter($data) || return undef;
  if ($self->soap('router','modify',$id,$p)) {
    print "OK\n"; return 0;
  } else {
    print "������\n";  return 1;
  }
}


1;
