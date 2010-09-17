package openbill::Shell::Manager;
use strict;
use openbill::Shell;
use openbill::Shell::Base;
use openbill::Utils;
use dpl::Context;
use Data::Dumper;
use dpl::System;
use Exporter;
use vars qw(@ISA @EXPORT);
@ISA=qw(Exporter openbill::Shell::Base);

registerCommands('openbill::Shell::Manager',
                 {
                  show_manager=>{},
                  list_managers=>{},
                  finance_report=>{},
                  create_manager=>{},
                  modify_manager=>{},
                  change_password=>{},
                 });


sub questmanager {
  my ($self,$p) = @_;
  return $self->{shell}->
    Question('manager',[{key=>'name',name=>'���',obligated=>1},
                        {key=>'login',name=>'Login',obligated=>1},
                        {key=>'password',name=>'������',obligated=>1},
                        {
                         key=>'mgroup_id',name=>'������',obligated=>1,
                         start=>sub {
                           my ($h,$p,$default) = @_;
                           my $list = $self->soap('mgroup','list');
                           my @s;
#                           die join(',',%$default);
                           foreach (@$list) {
                             push @s,{key=>$_->{id},name=>$_->{name}};
                           }
                           $p->{set}=\@s;
                           return 2;
                         },

                         #                         post=>sub {
                         #                           my $p = shift;
                         #                           $p->{method}=$self->soap('payment','getMethod',$p->{payment_method_id});
                         #return $p->{payment_method_id};
                         #                         }
                         },
                         {key=>'comment',name=>'����������'}],
                        $p);
}

sub CMD_finance_report {
  my ($self,$params)=@_;
  $params=$self->strToHash($params);
  if ($params->{date}) {
    $params->{date}=ParseDate($params->{date}) || fatal("�������� ����");
  } else {
    $params->{date}=ParseDate('yesterday');
  }

  print "\nORIONET.\n\n��ޣ� �� ".$params->{date}->TimeFormat("%A %e %B'%y")."\n\n\n";

  my $p = $self->soap('payment',
                      'ext_list',{date_from=>$params->{date},
                                  date_to=>$params->{date}});

  # ��������� ��� ������� ��������

  my %cp;
  foreach (@{$p->{list}}) {
    $cp{$_->{client_id}}={list=>[]}
      unless exists $cp{$_->{client_id}};
    push @{$cp{$_->{client_id}}->{list}},$_;
    $cp{$_->{client_id}}->{$_->{type}}+=$_->{summa};
  }

  my $res = $self->soap('client',
                        'ext_find',{reg_date=>$params->{date}});

  my $table = Text::FormatTable->new('r | r | r | r | r');
  $table->rule('-');
  $table->head('ID', '������', '�����', '���������', '�����������');
  $table->rule('-');
  my $firms=0;
#  print Dumper($res);
  foreach (@{$res->{list}}) {
    #    die Dumper($_);
    $table->row($_->{client_id},$_->{client},$_->{address},FormatMoney($cp{$_->{client_id}}->{1}), $cp{$_->{client_id}}->{0} ? FormatMoney($cp{$_->{client_id}}->{0}) : '��� ������');
    $firms++ if $_->{is_firm};
  }
  $table->rule('-');
  $table->row("$res->{max} ���",$firms ? "�� ��� $firms ��.���" : '��.��� ���','','','');
  $table->rule('-');
  $self->showTable($table);

  print "\n\n";

  my %a;
  my $table = Text::FormatTable->new('r | r r r r | r');

  $table->rule('-');
  $table->head('�����', '���������', '�����������', '����������', '������', '�����');
  $table->rule('-');
  foreach my $m (sort keys %{$p->{ms}}) {
    $table->row($p->{methods}->{$m}->{name},
                FormatMoney($p->{ms}->{$m}->{1}),
                FormatMoney($p->{ms}->{$m}->{0}),
                FormatMoney($p->{ms}->{$m}->{2}),
                FormatMoney($p->{ms}->{$m}->{3}),
                FormatMoney($p->{ms}->{$m}->{all}),
               );
    foreach (qw(all 0 1 2 3 )) {
      $a{$_}+=$p->{ms}->{$m}->{$_};
    }
  }
  $table->rule('-');
  $table->row('�����',
                FormatMoney($a{1}),
                FormatMoney($a{0}),
                FormatMoney($a{2}),
                FormatMoney($a{3}),
                FormatMoney($a{all}),
               );
  $table->rule('-');
#  $table->rule('=');
  $self->showTable($table);


  return 1;
}



sub CMD_show_manager {
  my $self = shift;
  my $data = $self->soap('manager','get',@_);
  unless ($data) {
    print "��� ������ ���������.";
    return 1;
  }
  my $table = Text::FormatTable->new('r | l ');
  $table->rule('=');
  $table->row('ID',$data->{manager_id});
  $table->row('���',$data->{name});
  $table->row('login',$data->{login});
  $table->row('������',$data->{mgroup});
  $table->row('����������',$data->{comment})
    if $data->{comment};
  $self->showTable($table);
  return 0;
}

sub CMD_change_password {
  my $self = shift;
  my $id = shift;
  my $data = $self->soap('manager','get',$id);
  unless ($data) {
    print "��� ������ ���������.";
    return 1;
  }
  print "��������� ������ ��� ���������: $data->{name}\n";
  my $r = $self->{shell}->
    Question('manager',[{key=>'password',name=>'������',obligated=>1},
                       ],
            );
  my $res = $self->soap('manager','changePassword',$id,$r->{password});
}

sub CMD_list_managers {
  my $self = shift;
  my $list = $self->soap('manager','list',@_);
  $self->ListManagers($list);
}

sub ListManagers {
  my ($self,$list) = @_;
  print "������ ���������� (".(scalar @$list)."):\n";
  my $table = Text::FormatTable->new('r| l l l l');
  $table->rule('=');
  $table->head('ID', '���', 'login', '������', '����������');
  $table->rule('-');
  foreach my $d (@$list) {
    my $id = $d->{manager_id}+0;
    $id="0$id" if $id<10;
    $table->row($id, $d->{name}, $d->{login}, $d->{mgroup}, $d->{comment});
  }
  $table->rule('=');
  $self->showTable($table);
}

sub CMD_create_manager {
  my ($self,$p) = @_;
  print "�������� ������ ���������:\n";
  $p=$self->questmanager($p) || return undef;
  $p->{is_active}=1;
  if (my $id = $self->soap('manager','create',$p)) {
    print "������ �������� #$id\n";
    return 1;
  } else {
    print "�������� �� ������\n";
    return 0;
  }
}


sub CMD_modify_manager {
  my ($self,$id,$p) = @_;
  my $p  = $self->strToHash($p);
  my $data = $self->soap('manager','get',$id);
  unless ($data) {
    print "��� ������ ���������\n";
    return 1;
  }
  print "���������: ";
  foreach (keys %$data) {
    $data->{$_}=$p->{$_}
      if exists $p->{$_};
  }
  $p=$self->questmanager($data) || return undef;
  if ($self->soap('manager','modify',$id,$p)) {
    print "OK\n";
    return 0;
  } else {
    print "������\n";
    return 1;
  }
}

1;
