package openbill::Shell::Payment;
use strict;
use openbill::Shell;
use openbill::Utils;
use dpl::Context;
use dpl::System;
use dpl::Db::Table;
use Text::FormatTable;
use Number::Format qw(:subs);
use Data::Dumper;
use openbill::Shell::Base;
use Exporter;
use vars qw(@ISA
            @EXPORT);
@ISA=qw(Exporter
        openbill::Shell::Base);


registerCommands('openbill::Shell::Payment',
                 {
                  list_payments=>{},
                  delete_payment=>{},
                  modify_payment=>{},
                  show_payment=>{},
                  make_payment=>{},
                  make_oriopay_payment=>{},
                 });

sub questpayment {
  my ($self,$p,$is_modify) = @_;
#  die join(',',%$p);
  my @a=(
         {key=>'client_id',name=>'�������',obligated=>1,
          post=>sub {
            my $params=shift;
            my $c = $self->soap('client','find',$params->{client_id});

            if (ref($c)) {
              #                             $params->{client}=$c;
              print "������ ������: '$c->{client}'\n";
              return $params->{client_id}=$c->{client_id};
            } elsif ($c) {
              print "����� ��������� ����� ������ - $c.\n";
            } else {
              print "����� ������ �� ������.\n";
            }
            return undef;
          }},
         {key=>'type',name=>'��� �������',obligated=>1,
          pre=>sub {
#            return $_[2] if defined $_[2];
            my $p = shift;
            return $_[1] ? 1 : 2 if defined $_[1];
            return 1;
#            return $self->soap('client','hasPaymentsOfType',$p->{client_id},0)
#            ? 1 : 2
          },
          set=>[{key=>1,name=>'���������'},
                {key=>0,name=>'�����������'},
                {key=>-1,name=>'��������� ��� �����������'},
                {key=>2,name=>'����������'},
                {key=>3,name=>'������'}],
         },
         {
          key=>'payment_method_id',name=>'������ �������',obligated=>1,
          start=>sub {
            my ($h,$p,$default) = @_;
            my $list = $self->soap('payment','methods');
            my @s;
            foreach (@$list) {
              push @s,{key=>$_->{id},name=>$_->{name}};
            }
            $p->{set}=\@s;
          },
          post=>sub {
            my $p = shift;
            $p->{method}=$self->soap('payment','getMethod',$p->{payment_method_id});
            return $p->{payment_method_id};
          }
         },
         {key=>'summa_order',name=>'����� ������',obligated=>1,
          post=>sub {
            my $p = shift;
            return 1 if $p->{summa_order}>0;
            print "����� ������ ���� �������������\n";
            return undef;
          }
         });
  push @a,{key=>'summa',name=>'����� ����������',obligated=>1,
           pre=>sub {
             my ($p,$pp,$d) = @_;
             my $s = round($p->{summa_order}*100/(100+$p->{method}->{tax}),2);
             print "������� ���������� ������ ������: $p->{method}->{tax}% ($s)\n";
             return $d;
           }}
    if $is_modify;
  push @a,({key=>'date',name=>'����',obligated=>1,
           type=>'date',
            pre=>sub { return $p->{date} || today()->TimeFormat('%Y-%m-%d')}
           },
           {key=>'comment',name=>'����������'});
  push @a,{key=>'modify_comment',name=>'������� ���������',obligated=>1}
    if $is_modify;
  return $self->{shell}->
    Question('payment',\@a,$p);
}

sub questpayment_oriopay {
  my ($self,$p) = @_;
  my @a=(
         {key=>'client_id',name=>'�������',obligated=>1,
          post=>sub {
            my $params=shift;
            my $c = $self->soap('client','find',$params->{client_id});

            if (ref($c)) {
              #                             $params->{client}=$c;
              print "������ ������: '$c->{client}'\n";
              return $params->{client_id}=$c->{client_id};
            } elsif ($c) {
              print "����� ��������� ����� ������ - $c.\n";
            } else {
              print "����� ������ �� ������.\n";
            }
            return undef;
          }},
         {key=>'code',name=>'��������� ���',obligated=>1,
         });
  return $self->{shell}->
    Question('payment',\@a,$p);
}



sub CMD_make_payment {
  my ($self,$p) = @_;
  $p=$self->questpayment({client_id=>$p}) || return undef;
#  delete $p->{client};
  # TODO ������ ��������
  delete $p->{method};
  if (my $rec =  $self->soap('client','makePayment',$p)) {
    print "��������� ".FormatMoney($rec->{summa})." ��� ������� #$rec->{id}\n";
    return 0;
  } else {
    print "������ �� �������������.";
    return 1;
  }
}

sub CMD_make_oriopay_payment {
  my ($self,$p) = @_;
  $p  = $self->strToHash($p);
  unless ($p->{client_id} && $p->{code}) {
    $p=$self->questpayment_oriopay($p) || return undef;
  }

#  delete $p->{client};
  # TODO ������ ��������
  delete $p->{method};
  $p->{payment_method_id}=10;
  $p->{type}=1;
  $p->{client_ip}='127.0.0.1';
  my $rec =  $self->soap('client','makePayment',$p);
  if ($rec && $rec->{id} && $rec->{summa}) {
    print "��������� ".FormatMoney($rec->{summa})." ��� ������� #$rec->{id}\n";
    return 0;
  } else {
    print "������ �� �������������.";
    print Dumper($rec);
    return 1;
  }
}


sub CMD_list_payments {
  my ($self,$p) = @_;
  $p  = $self->strToHash($p);
  my $res;
  my $show_client;
  my $table;
  my $cc;
#  if ($p->{client_id}) {
#    my $client = $self->soap('client','find',$p->{client_id}) ||
#      fatal("����� ������ �� ������");
#    $res = $self->soap('client','payments',$client->{client_id});
#    print "������ �������� (".(scalar @$list).") ������� '$client->{client}'\n";
#    $table = Text::FormatTable->new('r| l | l | r | r | r | l | l ');
#    $table->head('id', '����', '�����', 'Manager' ,'���ԣ�', '���������', '������ �����', '�� ���', 'N �ޣ��, �����������');
#  } else {
  $cc=1;
  my $start = $p->{start}+0; delete $p->{start};
  my $limit = $p->{limit}+0; delete $p->{limit};

  $res = $self->soap('payment','list',$p,'',$start,$limit);

#  }
  my $count = @{$res->{list}};
  my $list = $res->{list};
  print "������ �������� (".(scalar @$list)."):\n";
  $table = Text::FormatTable->new('r| l | l | r | r | r | r | l | l | l ');
  $table->head('id', '����', '�����', 'Manager'  ,'���ԣ�', '���������', '������ ��', '������', '�� ���' , 'N �ޣ��, �����������');
  $show_client=1;
  $table->rule('=');
  my $summa;
  my $summa_order;
  foreach my $d (@$list) {
    my $id = $d->{id};
    $id="0$id" if $id<10;
    if ($d->{type}==1 || $d->{type}==-11 || $cc) {
      $summa+=$d->{summa};
      $summa_order+=$d->{summa_order};
    }
    my @a = ($id, $d->{date}->TimeFormat('%Y-%m-%d'),
             $d->{method},
             $d->{manager},
             FormatMoney($d->{summa_order}),FormatMoney($d->{summa}),defined $d->{balance} ? FormatMoney($d->{balance}) : '???');
    push @a,$d->{client};
    if ($d->{type}==1) {
      push @a,'���������';
    } elsif ($d->{type}==-1) {
      push @a,'��������� ��� �����������';
    } elsif (!$d->{type}) {
      push @a,'�����������';
    } elsif ($d->{type}==2) {
      push @a,'����������';
    } else {
      push @a,'������';
    }

    push @a,"$d->{invoice_id} $d->{comment}";
    $table->row(@a);
  }
  $table->rule('=');
  $self->showTable($table);
  $res->{start}++;
  print "����� �������� $res->{max}, ��������� $count ������� � $res->{start}\n\n";

  $table = Text::FormatTable->new('r| l | l | r | r | r ');
  $table->head('id', '�����', '�����', '�����' ,'����� ����������','��������');
  $table->rule('=');
  my $pm = $res->{payment_methods};
  foreach my $k (sort keys %$pm) {
    $table->row($k,$pm->{$k}->{name},"$pm->{$k}->{tax}%",
                FormatMoney($pm->{$k}->{summa_order}),FormatMoney($pm->{$k}->{summa}),
                $pm->{$k}->{count})
      if $pm->{$k}->{count};
  }
  $table->rule('=');
  $self->showTable($table);
  print "�� ���������: ".FormatMoney($summa_order)." ��������� ��� ".FormatMoney($summa)."\n";
}

sub CMD_delete_payment {
  my $self = shift;
  if ($self->soap('payment','delete',@_)) {
    print "���ԣ� ������\n";
    return 0;
  } else {
    print "���ԣ� �� ���̣�\n";
    return 1;
  }
}

sub CMD_modify_payment {
  my ($self,$id,$p) = @_;
  my $p  = $self->strToHash($p);
  my $data = $self->soap('payment','get',$id);
  unless ($data) {
    print "��� ������ �������\n";
    return 1;
  }
  print "���������: ";
  foreach (keys %$data) {
    $data->{$_}=$p->{$_}
      if exists $p->{$_};
  }
  #  $data->{client}=$date->{client_id};
  $p=$self->questpayment($data,1) || return undef;
  if ($self->soap('payment','modify',$id,$p)) {
    print "OK\n";
    return 0;
  } else {
    print "������\n";
    return 1;
  }
}

sub CMD_show_payment {
  my ($self,$id,$p) = @_;
  my $p  = $self->strToHash($p);
  my $data = $self->soap('payment','get',$id);
  unless ($data) {
    print "��� ������ �������\n";
    return 1;
  }
  my $table = Text::FormatTable->new('r | l');
  $table->head('����', '��������');
  $table->rule('-');
  $table->row('ID',$data->{id});
  $table->row('���� ����������',$data->{timestamp});
  $table->row('��������',"$data->{manager}->{name}");
  $table->rule('-');
  $table->row('������',"[$data->{client_id}] $data->{client}");

  $table->row('���� �������',$data->{date});
  $table->row('����� �������',FormatMoney($data->{summa_order}));
  $table->row('����� ����������',FormatMoney($data->{summa}));
  $table->row('������ ����������',$data->{method}->{name});
  $table->row('��� �������',$data->{description});
  $table->row('������ �� �������',FormatMoney($data->{balance}));
  $table->row('����������',$data->{comment})
    if $data->{comment};

  $table->rule('=');
  $self->showTable($table);

  if (@{$data->{log}}) {
    print "\n������ ��������� �������:\n";
    foreach my $l (@{$data->{log}}) {
      print "------------------------------------\n";
      print "���ԣ� ������� ��������: #$l->{manager_id}\n";
      print "����� ���������: $l->{timestamp}\n";
      print "�������: $l->{modify_comment}\n";
      print "�������� ������:\n";
      foreach (qw(client_id summa summa_order payment_method_id type date comment)) {
        my $old = $l->{$_};
        my $new = $l->{"new_$_"};
        print "\t$_: $old -> $new\n"
          if $old ne $new;
      }
    }
  }

}


1;
