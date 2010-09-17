package openbill::Shell::Host;
use strict;
use openbill::Shell;
use openbill::Utils;
use dpl::Context;
use dpl::Db::Table;
use dpl::Error;
use openbill::Shell::Base;
use Date::Parse;
use Data::Dumper;
use Exporter;
use vars qw(@ISA
            @EXPORT);

@ISA=qw(Exporter
        openbill::Shell::Base);

registerCommands('openbill::Shell::Host',
                 {
                  'show_host'=>{},
                  'deactivate_host'=>{},
                  'activate_host'=>{},
                  'move_host'=>{},
                  'delete_host'=>{},
                  'check_host'=>{},
                  'attach_host'=>{},
                  'list_hosts'=>{},
                  'list_all_hosts'=>{},
                  'create_vpn_host'=>{},
                  'create_host'=>{},
                  'modify_host'=>{},

                 });


# delete_unused

sub CMD_list_hosts {
  my ($self,$p) = @_;
  $p  = $self->strToHash($p);
  if ($p->{router}) {
    my $r = $self->soap('router','find',$p->{router});
    unless ($r) {
      print "��� ������ �������: $p->{router}\n";
      return undef;
    }
    delete $p->{router};
    $p->{router_id}=$r->{router_id};
  }
  my $list = $self->soap('host','list',$p);
  my $table;
  $table = Text::FormatTable->new('l | l | l | l | l | l | l ');
  $table->head('ID', 'HOST', 'Hostname', "������\n��� �����������", "������\n�����", "�����", '����������');
  $table->rule('=');
  foreach my $h (@$list) {
    my $client = $h->{client_id} ? "[$h->{client_id}] $h->{client}\n" : "���������\n";
    $table->row($h->{host_id}, "$h->{host}\n$h->{mac}", $h->{is_vpn} ? "$h->{hostname}\nVPN" : $h->{hostname},
                "$h->{router}\n$h->{am_type}/$h->{am_name}",
                "$client$h->{address}",
                $h->{lastwork_time},
                $h->{is_active} ? "������: $h->{comment}" : "��������: $h->{comment}");
  }
  $self->showTable($table);
}


sub CMD_list_all_hosts {
  my ($self,$p) = @_;
  $p  = $self->strToHash($p);
  my $list = $self->soap('host','list_all',$p->{month});
  print "month: $p->{month}\n";
  print join("\t",qw(host is_vpn last_time tariff_id is_unlim speed)),"\n";
  foreach my $h (@$list) {
    my $l = $h->{lastwork_time} || $h->{createtime};
    print "$h->{host}\t$h->{is_vpn}\t$l\t$h->{tariff_id}\t$h->{tariff}->{is_unlim}\t$h->{tariff}->{speed}\n";
  }
}



sub CMD_check_host {
  my ($self,$pp) = @_;
  my $p  = $self->strToHash($pp);
  my $data;
  if ($p->{host_id}) {
    $data = $self->soap('host','check_link',$p->{host_id});
    unless ($data) {
      print "��� ������ �����\n";
      return 1;
    }
  } elsif ($p->{router_id}) {
    $data = $self->soap('router','check_host',$p->{router_id},3,$p->{ip});
  } elsif ($p->{client_id}) {
    #    $data = $self->soap('router','check_host',$p->{router_id},$p->{ip});
    my $list = $self->soap('host','list',$p);
    my %r;
    foreach (@$list) {
      next unless $_->{is_active};
      $r{$_->{router_id}}=[] unless $r{$_->{router_id}};
      push @{$r{$_->{router_id}}},$_;
    }
    foreach (keys %r) {
      my $rid = $_;
      # TODO hack
      next if $rid==36;

#      print "������: $rid\n";

      $data = $self->soap('router','check_host',$rid,3,map {$_->{host}} @{$r{$rid}});
      foreach (keys %$data) {
        print "����: $_: ";
        $self->ShowCheckHostResult($data->{$_})
      }
      print "\n";
    }
  } elsif ($p->{ip}) {
    my $list = $self->soap('host','list',$p);
    unless (@$list) {
      print "����� ���� �� ������\n";
      return 1;
    }
    $data = $self->soap('host','check_link',$list->[0]->{host_id});
  } elsif ($pp=~/(\d+).(\d+).(\d+).(\d+)/) {
    my $list = $self->soap('host','list',{ip=>$pp});
    unless (@$list) {
      print "����� ���� �� ������\n";
      return 1;
    }
    $data = $self->soap('host','check_link',$list->[0]->{host_id});
  } else {
    print "�� ��������� ������ ���� ($p)\n";
  }
  $self->ShowCheckHostResult($data);
}

sub ShowCheckHostResult {
  my ($self,$data) = @_;
  if ($data->{result} eq 'OK') {
    print "\t+ �ӣ � �������. MAC: $data->{mac}, ��������: $data->{time}, ������: $data->{loss}%, �������: $data->{count}";
  } elsif ($data->{result} eq 'NO') {
    print "\t- ���: ";
    if ($data->{mac} eq 'ARP') {
      print "������ ����� �� �����������";
    } elsif ($data->{mac} eq 'UNKNOWN') {
      print "����������� ������ ��� ���������� arping";
    } else {
      print "������ ������� arping ($data->{mac})";
    }

  }
#     print "ping: $data->{ping}, " if $data->{ping};
#     print "arping: $data->{arping}, " if $data->{arping};
#     print "� dhcp ��� " if $data->{dhcp};
#   } else {
#     print "��� �����";
#   }
  print "\n";
}

sub questhost {
  my ($self,$p,$is_new) = @_;
  my $at = $self->soap('host','access_types');
  my @a = (
           {key=>'router',name=>'������',obligated=>1,
            pre=>sub {return $_[2];},
            post=>sub {
              my $params=shift;
              if ($params->{router}=~/^\d+$/) {
                $params->{router_id}=$params->{router};
                delete $params->{router};
              } else {
                my $router = $self->soap('router','find',$params->{router})
                  || return undef;
                unless (ref($router)) {
                  print "������ ������ �������, �������: $router\n";
                  return undef;
                }
                $params->{janitor_id}=$router->{default_janitor_id}
                  unless $params->{janitor_id};
                delete $params->{router};
                $params->{router_id}=$router->{router_id};
              }
            }},

           {key=>'mac',name=>'MAC (��� IP � �������� ����� ��� none)',obligated=>1,
            post=>sub {
              my $params = shift;
              return $params->{mac} eq 'none'
                || CheckMac($params->{mac})
                  unless $params->{mac}=~/\./;
              $params->{_ip}=$params->{mac};
              print "��� MAC ����� �� IP ($params->{mac}) - ";
              my $data = $self->soap('router','check_host',
                                     $params->{router_id},1,$params->{mac});
              
              if ($data && $data->{$params->{mac}}->{result} eq 'OK') {
                $params->{mac}=$data->{$params->{mac}}->{mac};
                print "���������� MAC $params->{mac}\n";
                return 1;
              } else {
                print "����� ���� �� ������\n";
                return undef;
              }
            }
           },
           {key=>'host',name=>'���� ��� ���� (�������)',obligated=>1,
            pre=>sub {
                         my $params = shift;
                         if ($params->{_ip}) {
                           return $self->soap('router','get_next_free_ip',$params->{router_id},$params->{_ip});
                         } else {
                           return $_[2]->{host};
                         }
                       },
            post=>sub {
              my $params = shift;
              delete $params->{_ip};
              if (!$params->{host} || $params->{host}=~/^\d+$/) {
                return $params->{host}=$self->soap('router','get_next_free_ip',$params->{router_id},"10.100.$params->{host}.10");
                # return $self->soap('router','get_next_free_ip',$params->{router_id},"10.100.$params->{host}.10");
              } else {
                return $params->{host};
              }
            }
           },
           {key=>'hostname',name=>'hostname',obligated=>1,
            pre=>sub { return $_[2] if defined $_[2];
                       my $h = $_[0]->{host};
                       $h=~s/10.100.//;
                       $h=~s/\./_/g;
                       return "host_$h";
                     },
           },
           {key=>'am_type',name=>'��� ����������� ('.join(',',@$at).')',obligated=>1,
            pre=>sub {return $_[2] if defined $_[2]; return 'vpn_only';},
            post=>sub {
              my $params=shift;
              foreach (@$at) {
                return $_ if $params->{am_type} eq $_;
              }
              return undef;
            }
           },
           {key=>'street',name=>'�����',obligated=>1,post=>sub {
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
           {
            key=>'is_active',name=>'�������',obligated=>1,type=>'boolean',
            pre=>sub {
              return $_[2] ? '��' : '���';
            }},
           {key=>'janitor',name=>'����������',obligated=>0,
            pre=>sub {
              my $params = shift;
              return $params->{janitor_id};
            },
            post=>sub {
              my $params=shift;
              unless ($params->{janitor}) {
                delete $params->{janitor};
                return 1;
              }
              my $j = $self->soap('janitor','find',$params->{janitor})
                || return undef;
              delete $params->{janitor};
              $params->{janitor_id}=$j->{id};
            }},
           {key=>'comment',name=>'����������'}
          );
  if ($is_new) {
    unshift @a,{key=>'client_id',name=>'������',obligate=>'1',
                post=>sub {
                  my $params = shift;
                  my $p = shift;
                  return 1 unless $params->{client_id};
                  print "��� ������� - ";
                  my $data = $self->soap('client','get',$params->{client_id});
                  if ($data) {
                    $params->{room}=$data->{room};
                    $params->{building}=$data->{building};
                    $params->{street_id}=$data->{street_id};
                    $params->{street}=$data->{street};
                    print "$data->{name}\n";
                    return 1;
                  } else {
                    print "��� ������ �������\n";
                    return undef;
                  }
                }
               };
  }
  return $self->{shell}->
    Question('host',\@a,$p);
}

sub CMD_attach_host {
  my ($self,$p)=@_;
  my $p  = $self->strToHash($p);
  fatal("�� ������ ���� (host_id)") unless $p->{host_id};
  fatal("�� ������ ������ (client_id)") unless $p->{client_id};
  my $res = $self->soap('host','attach',$p->{host_id},$p->{client_id},$p->{date},$p->{comment});
#  print join(',',%$res);
#  print "���������: $res\n"
#    if $res;
  return $res;
}

sub CMD_create_host {
  my ($self,$p) = @_;
  my $p  = $self->strToHash($p);
  print "�������� ������ �����:\n";
  # TODO ������� ����� ������ ���������� ������������� ���� ��������� ������� �� ������
  $p=$self->questhost($p,1) || return undef;
  $p->{am_name}='deactive';
  my $id = $self->soap('host','create',$p);
  unless ($id) {
    print "������ �������� �����.";
    return 1;
  }
#   if ($client_id) {
#     print "����������� � ��������: $client_id\n";
#     my $res = $self->soap('host','attach',$id,$client_id);
#   }
  print "������ ���� $id\n";
}


sub questvpnhost {
  my ($self,$p,$is_new) = @_;
  my @a = (
                     # TODO ��������� ����� �� ������������
                     {key=>'hostname',name=>'�����',obligated=>1,
                      pre=>sub {return $_[2];},
                      _pre=>sub { return $_[2] if defined $_[2];}
                     },
                     {key=>'password',name=>'������',obligated=>1},
                     {key=>'host',name=>'IP',obligated=>1,
                      pre=>sub {
                        my $params = shift;
                        return $_[2]->{host} if $_[2]->{host};
                        return $self->soap('router','get_next_free_ip',36); # TODO router_id
                      }},
                     #                     {key=>'mac',name=>'MAC',obligated=>0},
#                     {key=>'hostname',name=>'hostname',obligated=>1},
                      {key=>'am_name',name=>'���������',obligated=>1,
                       pre=>sub { return $_[2] if defined $_[2]; return 'deactive';},
                       post=>sub {
                         my $params=shift;
                         return $params->{am_name}
                           if $params->{am_name} eq 'active'
                             || $params->{am_name} eq 'deactive';
                         return undef;
                       }
                      },
                     {key=>'comment',name=>'����������'}
          );
  if ($is_new) {
    unshift @a,{key=>'client_id',name=>'������',obligate=>'1',
                post=>sub {
                  my $params = shift;
                  return 1 unless $params->{client_id};
                  print "��� ������� - ";
                  my $data = $self->soap('client','get',$params->{client_id});
                  if ($data) {
                    print "$data->{name}\n";
                    return 1;
                  } else {
                    print "��� ������ �������\n";
                    return undef;
                  }
                }
               };
  }
  return $self->{shell}->
    Question('host',\@a,$p);
}


sub CMD_create_vpn_host {
  my ($self,$p) = @_;
  my $p  = $self->strToHash($p);
  print "�������� ������ �����:\n";
  # TODO ������� ����� ������ ���������� ������������� ���� ��������� ������� �� ������
  $p=$self->questvpnhost($p,1) || return undef;
  $p->{router_id}=36;
  $p->{mac}=$p->{hostname};
  $p->{am_type}='common';
#  $p->{am_name}='deactive';
  $p->{janitor_id}=3;
  $p->{is_vpn}=1;
  $p->{am_name}='deactive';
  my $id = $self->soap('host','create',$p);
  unless ($id) {
    print "������ �������� �����.";
    return 1;
  }
#   if ($p->{client_id}) {
#     print "����������� � ��������: $p->{client_id}\n";
#     my $res = $self->soap('host','attach',$id,$p->{client_id});
#   }
  print "������ ���� $id\n";
}


sub CMD_modify_host {
  my ($self,$id,$p) = @_;
  my $p  = $self->strToHash($p);
  my $data = $self->soap('host','get',$id);
  unless ($data) {
    print "��� ������ �����\n";
    return 1;
  }
  foreach (keys %$data) {
    $data->{$_}=$p->{$_}
      if exists $p->{$_};
  }

  if ($data->{is_vpn}) {
    print "��������� VPN ����������:\n";
    $p=$self->questvpnhost($data) || return undef;
    delete $p->{password} unless $p->{password};
    $p->{router_id}=36;
    $p->{mac}=$p->{hostname};
    $p->{am_type}='common';
    #  $p->{am_name}='deactive';
    $p->{janitor_id}=3;
    $p->{is_vpn}=1;
  } else {
    print "��������� �����:\n";
    $p=$self->questhost($data) || return undef;

  }


  if ($self->soap('host','modify',$id,$p)) {
    print "OK\n"; return 0;
  } else {
    print "������\n";  return 1;
  }
}


sub quest_delete_host {
  my ($self,$p) = @_;
  my @a = (
           {
            key=>'quest',name=>'�� ������� ��� ������ ������� ���� ����? (������)',obligated=>1,
           },
          );
  return $self->{shell}->Question('delete_host',\@a,{});
}


sub CMD_delete_host {
  my ($self,$id,$p) = @_;
  my $p  = $self->strToHash($p);
  my $data = $self->soap('host','get',$id);
  unless ($data) {
    print "��� ������ �����\n";
    return 1;
  }
  $self->ShowHost($data);
  my $p = $self->quest_delete_host($data) || return undef;
  if ($p->{quest} eq '������') {
    if ($self->soap('host','delete',$id)) {
      print "���� ������\n"; return 0;
    } else {
      print "������ ��������\n";  return 1;
    }
  }
}


sub ShowHost {
  my ($self,$res) = @_;
  my $table = Text::FormatTable->new('r | l');
  $table->rule('=');

  if ($res->{is_vpn}) {
    $table->row('VPN CONNECTION',$res->{host});
    $table->row('Login',$res->{mac});
  } else {
    $table->row('HOST',$res->{host});
    $table->row('MAC',$res->{mac});
    $table->row('hostname',$res->{hostname});
    $table->row('�����',$res->{address});
  }

  $table->row('������',$res->{router});
  $table->row('��������������� ��������',ref($res->{manager}) ? $res->{manager}->{name} : '�� ����������');
  $table->row('������',$res->{is_active} ? '����' : '���');
  $table->row('����������',$res->{janitor});
  $table->row('���������� ��������',$res->{am_time} || '������� ����������');
  if ($res->{current_speed}) {
    $table->row('��������',$res->{current_speed});
    $table->row('������ �����',$res->{is_night_mode} ? '�������' : '���');
    $table->row('��������� �����������',$res->{is_limited} ? '����������' : '�� ����������');
  } else {
    $table->row('��������','������������');
  }

  $table->row('�������',"[$res->{client_id}] $res->{client}")
    if $res->{client};
  $table->rule('-');
  $table->row('������',$res->{createtime});
#  $table->row('������ ������',$res->{firstwork_time});
  $table->row('��������� ������',$res->{lastwork_time});
  $table->rule('-');
  $table->row('����������',$res->{comment})
    if $res->{comment};
  $self->showTable($table);

}

sub CMD_show_host {
  my ($self,$p) = @_;
  # TODO ���� �� ����� ��������� ��������� ��������� ������ - �������� �� ���� �� �������
  my $res = $self->soap('host','get',$p);
  $self->ShowHost($res);
  if ($res->{attaches} && @{$res->{attaches}}>1) {
    print "\n������ �������������\n";
    my $table = Text::FormatTable->new('r | l');
    $table->rule('=');
    $table->row('����','������');
    $table->rule('=');
    foreach (@{$res->{attaches}}) {
      $table->row($_->{changetime},"#$_->{client_id}");
    }

    $self->showTable($table);
  }

  if ($res->{log} && @{$res->{log}}) {
    print "\n������ ���������\n";
    my $table = Text::FormatTable->new('r | l | l');
    $table->rule('=');
    $table->row('����','��������','���������');
    $table->rule('=');
    foreach (@{$res->{log}}) {
      $table->row($_->{timestamp},$_->{manager}->{name},$_->{text});
    }

    $self->showTable($table);
  }

  return 0;
}

sub CMD_activate_host {
  my ($self,$id) = @_;
  my $res = $self->soap('host','get',$id);
  unless ($res) {
    print "��� ������ �����\n";
    return;
  }
  print "������� ���� $res->{hostname} ($res->{host}):";
  $self->soap('host','modify',$id,{is_active=>1});
  print "ok\n";
  return 0;
}

sub CMD_deactivate_host {
  my ($self,$id) = @_;
  my $res = $self->soap('host','get',$id);
  unless ($res) {
    print "��� ������ �����\n";
    return;
  }
  print "�������� ���� $res->{hostname} ($res->{host}):";
  $self->soap('host','modify',$id,{is_active=>0});
  print "ok\n";
  return 0;
}



sub CMD_move_host {
  my $self = shift;
  my $p = $self->strToHash(@_);
  unless ($p->{building_id} && $p->{net}) {
    print "������������ ����������. ������ ���� > move_host building_id=?? net=??\n.��� [net] - ����� ���� �� 10.100.net.*\n";
    return 0;
  }

  my $list = $self->soap('host','list',{building_id=>$p->{building_id}});
  print "����� ������:",scalar @$list,"\n";
  foreach my $data (@$list) {
    #,"10.100.$p->{net}.10","10.100.$p->{net}.250"
    print "����� � ����� [$data->{host_id}] $data->{host} ������� ($p->{net}) ";
    if ($data->{router_id}==36) {
      print "�� ������ ����� �� VPN ����������\n";
      next;
    }
    unless ($data->{host}=~/^10\.100\./) {
      print "�� �������� ������ - ���������� �����: $data->{host}\n";
      next;
    }
    my $new_ip = $self->soap('router','get_next_free_ip',$data->{router_id},"10.100.$p->{net}.10");
    $data->{host}=$new_ip;
    if ($data->{hostname}=~/host_/) {
      $new_ip=~/\.(\d+)\.(\d+)$/;
      $data->{hostname}="host_$1_$2";
    }
    print "-> $data->{host} ($data->{hostname}) ";
    if ($self->soap('host','modify',
                    $data->{host_id},
                    {host=>$data->{host},
                     hostname=>$data->{hostname}})) {
      print "OK\n";
    } else {
      print "������\n";
    }
  }

}


1;
