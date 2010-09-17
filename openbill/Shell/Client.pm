package openbill::Shell::Client;
use strict;
use openbill::Shell;
use openbill::Utils;
use dpl::Context;
use dpl::System;
use dpl::Error;
use Number::Format qw(:subs);
#use Date::Parse;
#use Date::Format;
#use Date::Language;
#use Date::Handler;
use dpl::Log;
use Data::Dumper;
use openbill::Shell::Base;
use Email::Valid;
use Exporter;
use vars qw(@ISA
            @EXPORT);
@ISA=qw(Exporter
        openbill::Shell::Base);

registerCommands('openbill::Shell::Client',
                 {
                  tsb=>{},
                  show_client=>{},
                  redo_balance=>{},
                  redo_balances=>{},
                  do_alert=>{},
                  list_clients=>{},
                  list_invoices=>{},
                  list_charges=>{},
                  create_client=>{},
                  modify_client=>{},
                  modify_charge=>{},
                  recharge_client=>{},
                  #                  list_accounts=>{},
                  list_activations=>{},
                  list_balances=>{},
                  restore_balance=>{},
                  change_tariff=>{},
                  show_account=>{},
                  check_balance=>{},
                  activate_client=>{},
                  deactivate_client=>{},
                  show_check_act=>{},
                  send_mail=>{},
                  set_night_speed=>{},
                  set_daytime=>{},
                 });




sub fields {
  my ($self,$data) = @_;
  my @list = (
              {
               name=>'name',title=>'���'},
              {
               name=>'nick',title=>'���������'},
              {name=>'reg_date',title=>'�����������',
               value=>$data->{reg_date}->TimeFormat('%e %B %Y')},
              {name=>'manager',title=>'������������������ ��������'},
              {
               name=>'telefon',title=>'�������'},
              {
               name=>'email',title=>'�����'},
              {
               name=>'address',title=>'�����'},
              {
               name=>'can_deactivate',title=>'����� ���������',
               value=>$data->{can_deactivate} ? '��' : '���'},
              {name=>'is_active',title=>'������',value=>$data->{is_active} ? '����' : '���'},
              {name=>'firmname',title=>'�����'},
              {name=>'inn',title=>'���'},
              {name=>'bill_delivery',title=>'�������� �ޣ��'},
              {name=>'payment_method',title=>'������� ������ ������'},
              {name=>'minimal_balance',title=>'����������� ������'},
              {name=>'balance',title=>'������',value=>FormatMoney($data->{balance},$data->{currency})},
#              {name=>'start_balance',title=>'������ �� ������'},
              {name=>'do_alert',title=>'���������� ��������'},
              {name=>'balance_to_alert',title=>'������ ��� ����������'},
              {name=>'alert_email',title=>'Email ��� ����������'},

              {name=>'lastwork_time',title=>'��������� ������'},
              {name=>'night_speed',title=>'������ ��������'},

              {name=>'period_month',title=>'������� ������'},
              {name=>'period_traffic_mb',title=>'������ � ������� (Mb)'},
              {name=>'period_limited',title=>'��������� ��������� ������'},
	      {name=>'is_good_month_str',title=>'������ ��������� ����������'},
	      {name=>'good_month_cnt',title=>'������� ��������� ����������'},
	      {name=>'bonus_speed',title=>'������ ��������, Kbps'},

              {name=>'order_connection_summ',title=>'��������� �����������'},
              {name=>'real_connection_summ',title=>'�������� �� �����������'},

              {name=>'payed_to_date',title=>'�������� ��'},
              {name=>'comment',title=>'����������'},
             );
  foreach (@list) {
    unless (exists $_->{value}) {
      $_->{value}=$_->{name} eq 'manager' ? $data->{$_->{name}}->{name} : $data->{$_->{name}};
    }
  }

  return \@list;
}

sub format_account {
  my $cid = shift;
#  return $cid+0;
  while (length($cid)<6) {
    $cid="0$cid";
  }
  return "$cid";
}

sub reformat_account {
  my $cid = shift;
  $cid=~s/._\-//g;
  return $cid+0;
}

sub CMD_tsb {
  my $self = shift;
  my ($command,@params) = $self->strToArr(@_);

  if ($command eq 'PING') {
    print "PONG\n";

  } elsif ($command eq 'REQ_INF') {
    my ($cid,$password)=@params;
    $cid = reformat_account($cid);
    my $c = $self->soap('client','get',$cid);
    if (!$c || ($c->{status_id} == 4)) {
      print "ERROR no such client\n";
      return;
    } elsif (!ref($c) && $c>1) {
      print "ERROR such clients are more than one\n";
      return;
    }
    print "USER\n";
    #�������� ������ � ������������  (GROUP ��_������ ���_������)
    #    print "ADDGROUP 0 ���� �����\n";
    print "ADDGROUP 1 ���� �����\n";
    #��������� ����
    #�����������-���������� �������
    print "NAMEORG ��� \"���� �����\"\n";
    #������������ �������
    #    print "NAMESCHET ������ ��������\n";
    #������� ���� �����������
    #��� �����
#    print "NUMSCHET 123456789\n";
    #���
    #    print "BIK 049706750\n";
    print "BIK 049706609\n"; # ��
    #�������� ���� ���������� �������"
    print "SCHET 40702810675020134005\n";
    #��� ���������
    print "INN 2128056642\n";
    #����
    print "BANKNAME ��������� ��������� 8613 �� ��\n"; # (���) � �.���������
    #�������
    #    print "CORSCHET 30101810000000000750\n";
    print "CORSCHET 30101810300000000609\n"; # ��
    #��������
    #print "PERCENT 0\n";
    #����������� ���� ��������
    #    print "AMOUNTMIN 0.0"
    #������������ ����� ��������
    #    print "AMOUNTMAX 0.0"
    #������� ������� ��� ��������
    #    print "DOGOVOR 0"
    my $s = format_account($c->{client_id});
    print "LSCHET $s\n";
    #��� ������� (0 - �������������, 1 - ���������, � ��)
    if ($c->{balance}>0) {
      print "TYPEBILL 1\n";
    } else {
      print "TYPEBILL 0\n";
    }
    #��� �����������
    print "FIO $c->{name}\n";
    #��� �����
    print "STREET $c->{street}\n";
    print "HOUSE $c->{building}\n";
#    print "CORPUS $c->{address}->{room}\n"
    print "KVARTIRA $c->{room}\n"
      if length($c->{room})>0 && length($c->{room})<=5;
    #������

#    print "PERIOD 01.1980\n";
    my $a = -int($c->{balance}-0.5)*100;
    #���������� ���� �������
#    print "AMOUNT $a\n";
    #������������ ��������� �����
    $a=0 if $a<0;
    print "AMOUNTOVER $a\n";
#    print "PERIOD 01.1980"
    #���������� ���� �������
    print "AMOUNT 0\n";
    #������������ ��������� �����
#    print "AMOUNTOVER 0\n";
    #�������� �������������� BLL � ������������ � ������
    print "ADDBILL\n"
  } elsif ($command eq 'REQ_PAY') {
    my ($cid,$filial,$term,$doc,$payment,$tran,$date,$ltime)=@params;
    my $p={};
    $p->{client_id}=reformat_account($cid);

    my $c = $self->soap('client','get',$p->{client_id});
    if (!$c || ($c->{status_id} == 4)) {
      print "ERROR no such client\n";
      return;
    } elsif (!ref($c) && $c>1) {
      print "ERROR such clients are more than one\n";
      return;
    }

    $p->{payment_method_id}=13;
    $p->{type}=1;
    $p->{summa_order}=$payment/100;
    $p->{date}=today()->TimeFormat('%Y-%m-%d');
    $p->{client_ip}='127.0.0.1';
    $p->{comment}="cid:$cid,filial:$filial,term:$term,doc:$doc,payment:$payment,tran:$tran,date:$date,ltime:$ltime";
    $p->{secret_comment}=$p->{comment};
    my $rec =  $self->soap('client','makePayment',$p);
    if ($rec && $rec->{id} && $rec->{summa}) {
      print "OK\n";
      #      print "��������� ".FormatMoney($rec->{summa})." ��� ������� #$rec->{id}\n";
      #      return 0;
    } else {
      print "ERROR no payment\n";
    }

  } else {
    print "ERROR Unknown command $command\n";
  }
}

sub CMD_set_night_speed {
  my $self = shift;
  my ($client,$speed) = $self->strToArr(@_);
  unless ($client) {
    print "�������������: set_night_speed [client_id] [speed]\n";
  }
  my $res = $self->soap('client','set_night_speed',$client,$speed);
  print "����� ���������: $res\n";
  return 1;
}

sub CMD_set_daytime {
  my $self = shift;
  my ($daytime) = $self->strToArr(@_);
  if ($daytime) {
    my $res = $self->soap('client','set_daytime',$daytime);
  } else {
    print "�������������: set_daytime [day|night]\n";
  }

}


sub CMD_check_balance {
  my $self = shift;
  my ($client) = $self->strToArr(@_);
#  my $c = $self->GetClient($client) || return 1;
 # return 1 unless ref($c);
#  my $table = $self->ShowClient($c);
  my $res = $self->soap('client','check_balance',$client);
  if ($res==-1) {
    print "������� ��� ��������\n";
  } elsif ($res==1) {
    print "������� ��������, ���-��� ������ ������ �����ۣ�����\n";
  } elsif ($res==2) {
    print "� �������� ������ ������ �����������, ������� ������, ���-��� ��������� �� ���������\n";
  } elsif ($res==3) {
    print "� �������� �������� ����� �������� ��������, ������������ �������\n";
  } elsif ($res==0) {
    print "� �������� �ӣ � �������\n";
  } else {
    print "����������� �����: $res\n";
  }
}

sub CMD_do_alert {
  my $self = shift;
  my $res = $self->soap('client','do_alert',@_);
  if ($res) {
    print "��������� $res ��������\n";
  } else {
    print "���������� �� ���������";
  }
}

sub CMD_show_client {
  my $self = shift;
  my ($client,$date) = $self->strToArr(@_);
  my $c = $self->GetClient($client) || return 1;
  return 1 unless ref($c);
  my $table = $self->ShowClient($c);

  $date = $date ? ($date=~/\d\d\d\d-\d\d-\d\d/ ? ParseDate($date) : ParseMonth($date)) : ToDate(today());
  fatal("������� ������� ����") unless $date;
  #  die "$date";
  # TODO �������� � ����� ���� �����������, ����� � ���� �����

  my $period = $self->soap('period','get');
  unless ($period) {
    $table->row('������ ����������:',$date);
    next;
  }
  my $charge = $self->soap('client','getChargeRecord',$c->{client_id},$period->{id});
  $table->row('������:','iptraff');
  if ($charge) {
    $table->row('�����:',"[$charge->{tariff_id}] $charge->{tariff}");
    $table->row("�� ������ $charge->{period}: ",
                FormatMoney($charge->{summa},$charge->{currency})
                .' ( ����:'.FormatMoney($charge->{season_summa},$charge->{currency}).
                ' ����:'.FormatMoney($charge->{traffic_summa},$charge->{currency}).')');
    $table->row('��ԣ���� ������:',FormatBytes($charge->{traffic}->{0}+$charge->{traffic}->{10}).", �����: ".FormatBytes($charge->{traffic_free}));
  }
#     my $t = $self->soap('service','traffic',$s->{id},
#                         {client_id=>$c->{client_id},
#                          from=>$period->{start},
#                          to=>$period->{end}},['ip','class']);
#     if (keys %{$t->{traffic}}>1) {
#       foreach (keys %{$t->{traffic}}) {
#         unless ($_ eq 'all') {
#           my $host = $self->soap('host','get',$_);
#           $table->row("���� $host->{hostname}/$host->{ip}:", FormatBytes($t->{traffic}->{$_}->{0}).' / '.FormatBytes($t->{traffic}->{$_}->{1}));
#         }
#       }
#     }
  my $balance = $self->soap('client','getBalance',$c->{client_id},$period->{start});
  $table->row('������ ��� �������� �������:',
              FormatMoney($balance));

  $table->rule('-');
  my $lb = $self->soap('client','getBalance',$c->{client_id},1);
  $table->row('���������� ������:',FormatMoney($lb))
    if abs($lb-$c->{balance})>0.01;
  $self->showTable($table);

}

sub GetClient {
  my ($self,$id) = @_;
  my $res = $self->soap('client','get',$id);
  fatal("��� ������ �������") unless $res;
  fatal("����� �������� ����� ������ - $res.") if !ref($res) && $res>1;
  return $res;
}

sub ShowClient {
  my ($self,$data) = @_;
  my $table = Text::FormatTable->new('r | l ');
  $table->rule('=');
  $table->row('ID',$data->{client_id});
  foreach (@{$self->fields($data)}) {
    $table->row($_->{title},$_->{value})
      if $_->{value} ne '';
  }
  $table->rule('=');
  #  $self->showTable($table);
  return $table;
}

sub ShowClientM {
  my ($self,$data) = @_;
  my $table = Text::FormatTable->new('r | l ');
  $table->rule('=');
  $table->row('ID',$data->{client_id});
  $table->row('������',"$data->{name} / $data->{firmname}");
  $table->rule('=');
  return $table;
}

sub CMD_create_client {
  my ($self,$p) = @_;
  my $p  = $self->strToHash($p);
  print "�������� ������ �������:\n";
  # TODO ������� ����� ������ ���������� ������������� ���� ��������� ������� �� ������
  $p=$self->questclient($p) || return undef;
  $p->{can_deactivate}=1;
  if ($p->{is_firm}) {
    $p->{balance_to_alert}=-2000;
    $p->{balance_to_off}=-3000;
    $p->{unpayed_days_to_off}=12+31;
    $p->{unpayed_days_to_alert}=9+31;
  } else {
    $p->{balance_to_alert}=100;
  }
  $p->{status_id}=0;
#  $p->{send_alert_days}=5;
#  $p->{alert_balance}=100;
  my $id = $self->soap('client','create',$p);
  unless ($id) {
    print "������ �������� �������.";
    return 1;
  }
  print "������ ������ #$id\n";
}

sub CMD_list_clients {
  my ($self,$params) = @_;
  $params  = $self->strToHash($params);
  $params->{reg_date} = ParseDate($params->{reg_date}) || fatal("������� ������ reg_date")
    if $params->{reg_date};
  $params->{reg_date_from} = ParseDate($params->{reg_date_from}) || fatal("������� ������ reg_date_from")
    if $params->{reg_date_from};
  $params->{reg_date_to} = ParseDate($params->{reg_date_to})  || fatal("������� ������ reg_date_ti")
    if $params->{reg_date_to};
  my $balance_date = ParseDate($params->{balance_date})  || fatal("������� ������ balance_date")
    if $params->{balance_date};

  delete $params->{balance_date};
  my $start = $params->{start}+0; delete $params->{start};
  my $limit = $params->{limit}+0; delete $params->{limit};

  my $res = $self->soap('client','list',$params,'',$start,$limit);
  my $count = @{$res->{list}};
  my $list = $res->{list};
  my $table = Text::FormatTable->new('r| l l r r r l l');
  $table->rule('=');
  $table->head('id', '���������/���', 'A','������','������������','���', '�����/�������', '�����������');
  $table->rule('=');
  foreach my $d (@$list) {
    my $id = $d->{client_id};
#    print "$id";
    $id="0$id" if $id<10;

    my $f;
    my $u;
    my $e;
    if ($d->{firmname}) {
      $f="\n\n$d->{firmname}";
      $e="���:$d->{inn}\n";
      my $u=" (��.����)";
    }
    $d->{balance_ordered}=$self->soap('client','getBalance',$d->{client_id},$balance_date)
	   if $balance_date;
    $table->row($id, "$d->{nick}$u\n$d->{name}$f",
                $d->{is_active} ? '' : '* ',
                FormatMoney($d->{balance}),FormatMoney($d->{balance_ordered}),
                FormatMoney($d->{balance_ordered}*1.18),
                "$d->{telefon}\n$d->{email}\n$d->{street}, $d->{building}, $d->{room}",
                  "$e\n�����������: ".$d->{reg_date}->string());
    $table->rule();


#     if ($id>650) {
#       # ����������� ����� ������
#       my $s = $self->CP($id);
#       if ($s!=$d->{real_connection_summ}) {
#         print "$id: $s<>$d->{real_connection_summ}\n";
#         $self->soap('client','modify',$id,{real_connection_summ=>$s});
#       }
#     }

  }
  $self->showTable($table);
  $res->{start}++;
  print "����� $res->{max} ��������� $count ������� � $res->{start}";
}

sub CMD_list_balances {
  my ($self) = @_;
  my $res = $self->soap('client','list',{},'',0,999999);
  foreach my $d (@{$res->{list}}) {
    my $id = $d->{client_id};
#    my $b = $d->{is_firm} ? round($d->{balance}*1.18,2) : round($d->{balance},2);
    my $b = round($d->{balance},2);
    print "$id\t$b\n";
  }
}

sub CMD_redo_balances {
  my ($self) = @_;
  my $res = $self->soap('client','list',{},'',0,400);
  my $list = $res->{list};
#  my $table = Text::FormatTable->new('r| l l r r r l l');
  my $date = ParseDate('2006-01-01');
#  $table->rule('=');
#  $table->head('id', '���������/���', 'A','������','������������','���', '�����/�������', '�����������');
#  $table->rule('=');
  foreach my $d (@$list) {
    $self->RedoClient($d);
  }

  # $self->showTable($table);
}

sub CMD_redo_balance {
  my ($self,$id) = @_;
  my $res = $self->soap('client','get',$id);
  $self->RedoClient($res);
  # $self->showTable($table);
}


sub RedoClient {
  my ($self,$d) = @_;
  my $date = ParseDate('2006-01-01');
  my $old_balance = $d->{balance};
#  $self->soap('client','recharge',$d->{client_id});
  my $start_balance = $self->soap('client','getStartBalance',$d->{client_id},$d->{is_firm});
  my $balance_2006 = $self->soap('client','getBalance2006',$d->{client_id},$d->{is_firm});
  my $new_balance = $start_balance+$balance_2006;
  my $b = round($new_balance,2);
#  print "$d->{client_id}\t$b\n";
  $self->soap('client','modify',$d->{client_id},{start_balance=>$start_balance,
                                                 old_balance=>$old_balance,
                                                 balance=>$new_balance});
  my $diff = $d->{is_firm} ? $old_balance - $new_balance/1.18 :$old_balance-$new_balance;

  if ($diff>1 || $diff>1) {
    print "# $d->{client_id}\t(start:$start_balance)\t$new_balance<>$old_balance\n";
  }
  return 1;


}


# sub CMD_list_invoices {
#   my ($self,$params) = @_;
#   $params  = $self->strToHash($params);
#   $params->{date} = ParseMonth($params->{month}) || fatal("������� ������ �����");
#   delete $params->{month};
#   $params->{reg_date} = ParseDate($params->{reg_date}) || fatal("������� ������ reg_date")
#     if $params->{reg_date};
#   $params->{reg_date_from} = ParseDate($params->{reg_date_from}) || fatal("������� ������ reg_date_from")
#     if $params->{reg_date_from};
#   $params->{reg_date_to} = ParseDate($params->{reg_date_to})  || fatal("������� ������ reg_date_ti")
#     if $params->{reg_date_to};
#
#   my $start = $params->{start}+0; delete $params->{start};
#   my $limit = $params->{limit}+0; delete $params->{limit};
#
#   my $res = $self->soap('client','list',$params,'',$start,$limit);
#   my $count = @{$res->{list}};
#   my $list = $res->{list};
#   my $table = Text::FormatTable->new('r | r | r r r | r ');
#   $table->rule('=');
#   $table->head('�������', '���', '������', "���������\n��������������", "���.������\nMb", "�����");
#   $table->rule('=');
#   my $nalog = 1.18;             # TODO � ������
#   my $summa=0;
#   my $currency='�.';
#   my %services;
#   foreach my $client (@$list) {
#     #    print join(',',%{$client->{charges}})."\n";
#     my $was=0;
#     foreach my $sid (keys %{$client->{charges}}) {
#       my $charge = $client->{charges}->{$sid};
#       $services{$sid} = $self->soap('service','get',$sid)
#         unless exists $services{$sid};
#       if ($charge) {
#         my $t = $charge->{traffic_free};
#         $t=$charge->{traffic}->{0} if $charge->{traffic}->{0}<$t;
#         $t=$t ? FormatBytes($t) : '-';
#         my $td = $charge->{traffic}->{0}-$charge->{traffic_free};
#         $td=$td>0 ? FormatBytes($td) : '-';
#         $summa+=$charge->{summa};
#         $table->row("$client->{name}\n$client->{firmname}",
#                     $client->{is_firm} ? '��.����' : '�������',
#                     $services{$sid}->{name},  $charge->{season_summa}+$charge->{traffic_free}>0 ?
#                     FormatMoney($charge->{season_summa},$currency)."\n$t" : '-',
#                     FormatMoney($charge->{traffic_summa},$currency)."\n$td",
#                     FormatMoney($charge->{summa},$currency));
#         $was=1;
#       }
#     }
#     $table->rule()
#       if $was;
#   }
#   $self->showTable($table);
#   $res->{start}++;
#   print "����� $res->{max} ��������� $count ������� � $res->{start}, �����:".FormatMoney($summa);
# }



sub questclient {
  my ($self,$p) = @_;
  return $self->{shell}->
    Question('client',[
                       {
                        key=>'name',name=>'���',obligated=>1},
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
                       {
                        key=>'telefon',name=>'��������',obligated=>1},
                       {key=>'email',name=>'������ (none ���� ���)',obligated=>1,
                        post=>sub {
                          my $params=shift;
                          return 1 if $params->{email} eq 'none';
                          my @e = split(/[ ;,]+/,$params->{email});
                          foreach (@e) {
                            return undef unless Email::Valid->address($_);
                          }
                          return 1;
                        }},
                       {
                        key=>'is_firm',name=>'��.����',obligated=>1,type=>'boolean',
                        pre=>sub {
                           return $_[2] ? '��' : '���';
                        }},
                       {
                        key=>'firmname',name=>'�����',pre=>sub {
                          my ($h,$p,$d) = @_;
                          $p->{obligated}=$h->{is_firm};
                          return $d if $d;
                          return $h->{firmname} unless $d==undef;
                          return $h->{is_firm} ? '��� ' : '';
                        }
                       },
                       {
                        key=>'inn',name=>"���",request=>sub { $_[0]->{is_firm} }},
                       {
                        key=>'nick',obligated=>1,name=>'���������'},
                       {
                        key=>'bill_delivery_id',obligated=>0,name=>'������ �ޣ��'},
                       {
                        key=>'payment_method_id',obligated=>0,name=>'������� ������ ������',
                        pre=>sub {
                          my ($h,$p,$d) = @_;
                          return $h->{payment_method_id} if exists $h->{payment_method_id};
                          return $h->{is_firm} ? 1 : 2;
                        }},
                       {
                        key=>'reg_date',name=>'���� �����������',obligated=>1,
                        type=>'date',
                        pre=>sub { $_[2] || today()->TimeFormat('%Y-%m-%d')}
                       },
                       {
                        key=>'new_contract_date',name=>'���� �������������� ������ ���������',
                        type=>'date',
#                        pre=>sub { $_[2] || today()->TimeFormat('%Y-%m-%d')}
                       },

                       {
                        key=>'months',name=>'����������� ���� ������������ �� ������ (���.)',
                        obligated=>1,
                        pre=>sub { 1; }
                       },

                       {key=>'minimal_balance',
                        obligated=>1,
                        name=>'���������� ���������� ������ �� �ޣ��',
                        pre=>sub {$_[2] || 0;}},

#                         {key=>'start_balance',
#                          obligated=>1,
#                          name=>'������ �� ������',
#                          pre=>sub {$_[2] || 0;}},

                       {key=>'do_alert',type=>'boolean',obligated=>0,
                        name=>'������ ��������������',
                        pre=>sub {
                          return $_[2] ? '��' : '���';
                        }},

                       {key=>'balance_to_alert',
                        obligated=>0,
                        name=>'������ ��� ��������������',
                        pre=>sub {$_[2] || 0;}},

                       {key=>'alert_email',
                        obligated=>0,
                        name=>'Email ��� �������� ��������������',
                        pre=>sub {
                          my ($h,$p,$d) = @_;
#                          $p->{obligated}=$h->{is_firm};
                          return $d if $d;
                          return $h->{email};
                          #                          return $h->{is_firm} ? '��� ' : '';
                        },
                        post=>sub {
                          my $params=shift;
                          return 1 if $params->{alert_email} eq 'none';
                          return Email::Valid->address($params->{alert_email});
                        }},

                       {key=>'order_connection_summ',obligated=>0,
                        name=>'��������� �����������',
                       },


                       {key=>'has_connection_credit',type=>'boolean',obligated=>0,
                        name=>'����������� � ������',
                        pre=>sub {
                          return $_[2] ? '��' : '���';
                        }},

#                        {key=>'balance_to_off',
#                         obligated=>0,
#                         name=>'������ ��� ����������',
#                         pre=>sub {$_[2] || 0;}},
#
#                        {key=>'unpayed_days_to_off',
#                         obligated=>0,
#                         name=>'���� ��� ������ ��� ����������',
#                         pre=>sub {$_[2] || 0;}},
#
#                        {key=>'unpayed_days_to_alert',
#                         obligated=>0,
#                         name=>'���� ��� ������ ��� �������������� ',
#                         pre=>sub {$_[2] || 0;}},
#
                       {key=>'is_good_month',
                        obligated=>1,
                        name=>'������ ��������� ���������� (-100/0/100)',
                        pre=>sub {$_[2] || 0;}},
                       {key=>'good_month_cnt',
                        obligated=>1,
                        name=>'���-�� ������� ��������� ����������',
                        pre=>sub {$_[2] || 0;}},

                       {key=>'comment',name=>'����������'}
                      ],$p);
}

sub questcharge {
  my ($self,$p) = @_;
  return $self->{shell}->
    Question('client',[
                       {key=>'tariff_id',name=>'�����',obligated=>1},
                       {key=>'t0',name=>'������� �������� ������� (����)',obligated=>1},
                       {key=>'t10',name=>'������ �������� ������� (����)',obligated=>1},
                       {key=>'traffic_free',name=>'�� ���� ���������� ������ (����)',obligated=>1},
                       {key=>'season_summa',name=>'���������',obligated=>1},
                       {key=>'season_order',name=>'��������� � ���',obligated=>1},
                       {key=>'traffic_summa',name=>'����� �� ������',obligated=>1},
                       {key=>'traffic_order',name=>'����� �� ������ � ���',obligated=>1},

                       {key=>'summa',name=>'����� �� �����',obligated=>1,
                        pre=>sub {
                          my ($h,$p,$d) = @_;
                          return $h->{traffic_summa}+$h->{season_summa};
                        }},
                       {key=>'summa_order',name=>'����� �ޣ��',obligated=>1},
                       ],$p);
}


sub CMD_modify_client {
  my ($self,$p) = @_;
  my $p  = $self->strToHash($p,'client');
  my $id = $p->{client}; delete $p->{client};
  my $data = $self->soap('client','get',$id);
  unless ($data) {
    print "��� ������ �������\n";
    return 1;
  }
  my $table = $self->ShowClientM($data);
  print "��������� �������:\n";
  $self->showTable($table);
  my $new=%$p ? $p : $self->questclient($data) || return undef;
  if ($self->soap('client','modify',$id,$new)) {
    print "OK\n";
    return 0;
  } else {
    print "������\n";
    return 1;
  }
}

sub CMD_modify_charge {
  my ($self,$p) = @_;
  my $p  = $self->strToHash($p);
  fatal("�� ������ client_id") unless $p->{client_id};
  fatal("�� ������ month (YYYY-MM)") unless $p->{month};
  my $data = $self->soap('client','get',$p->{client_id});
  unless ($data) {
    print "��� ������ �������\n";
    return 1;
  }
  my $period = $self->soap('period','get',ParseMonth($p->{month}) || fatal("������� ������ ����� $p->{month}"));
  unless ($period) {
    print "������ ����������: $p->{month}\n";
    exit;
  }
  my $charge = $self->soap('client','getChargeRecord',$p->{client_id},$period->{id});
  my $table = $self->ShowClientM($data);
  print "��������� charge ($p->{month}) ��� �������:\n";
  $self->showTable($table);
  unless ($charge) {
    print "��� ����� charge\n";
#    return;
  }
  $charge->{t0}=$charge->{traffic}->{0};
  $charge->{t10}=$charge->{traffic}->{10};
  my $new=$self->questcharge($charge) || return undef;
  $new->{traffic}->{0}=$new->{t0};
  $new->{traffic}->{10}=$new->{t10};
  delete $new->{t0};
  delete $new->{t10};
  my $charge = $self->soap('client','modifyChargeRecord',$p->{client_id},$period->{id},$new);
  return "���������: $charge\n";
#  if ($self->soap('client','modify',$id,$new)) {
#    print "OK\n";
#    return 0;
#  } else {
#    print "������\n";
#    return 1;
#  }
}

# sub CMD_list_accounts {
#   my ($self,$p) = @_;
#   $p  = $self->strToHash($p);
#   my $start = $p->{start}+0; delete $p->{start};
#   my $limit = $p->{limit}+0; delete $p->{limit};
#   my $nalog=$p->{nalog};
#   my $show_log=$p->{show_log};
#   delete $p->{nalog};
#   delete $p->{show_log};
#   if ($nalog) {
#     print "\n�����: $nalog\n";
#   } else {
#     $nalog=1;
#   }
#   my $res = $self->soap('client','list',$p,'',$start,$limit);
#   my $count = @{$res->{list}};
#
#   print "����� �������� ($count):\n";
#   my $date = ToDate(PeriodFromDate(today()));
#   foreach my $c (@{$res->{list}}) {
#     my $balance = $self->soap('client','getBalance',$c->{client_id},$date);
#     print "\n***\n������:\t$c->{name},$c->{firmname}\n";
#     print "������:\t".FormatMoney($c->{balance}).", �� ������� ������: ".FormatMoney($balance->{balance},$balance->{currency})."\n";
#     if ($show_log) {
#
#       my $charges = $self->soap('client','charges',$c->{client_id});
#       my $payments = $self->soap('client','payments',$c->{client_id});
#
#       my $table = Text::FormatTable->new(' r r r l | r l l ');
#       $table->rule('=');
#       $table->head('���� ������', '�����', '���������', '��� ������', '������', '�����', '�����');
#       $table->rule('-');
#       my @c = reverse @$charges;
#       my @p = reverse @$payments;
#       my ($summa,$summa_p,$summa_po);
#       while (@c || @p) {
#         my $c = shift @c;
#         my $p = shift @p;
#         my @a;
#         if ($p) {
#           $summa_p+=$p->{summa};
#           $summa_po+=$p->{summa_order};
#           push @a, $p->{date}->TimeFormat('%Y-%m-%d');
#           push @a, FormatMoney($p->{summa_order});
#           push @a, FormatMoney($p->{summa});
#           push @a, ($p->{type} ? '���������' : '�����������').','.($p->{form} eq 'order' ?  '��������' : '�����');
#         } else {
#           push @a,('-','','','');
#         }
#         if ($c) {
#           my $s=$c->{summa}*$nalog;
#           $summa+=$s;
#           push @a, $c->{service};
#           push @a, $c->{month};
#           push @a, FormatMoney($s);
#         } else {
#           push @a, ('-','','');
#         }
#         $table->row(@a);
#       }
#       $table->rule('-');
#       $table->row('����� ������',FormatMoney($summa_po),FormatMoney($summa_p),'',
#                   '����� �������','',FormatMoney($summa));
#       $table->rule('=');
#       $self->showTable($table);
#     }
#   }
# }
#
# sub CMD_list_accounts_old {
#   my ($self,$p) = @_;
#   $p=$self->strToHash($p);
#   my %p;
#   $p{is_firm}=$p->{is_firm} ?  1 : 0 if exists $p->{is_firm};
#   $p{date} = ParseDate("$p->{month}-01")  || fatal("������� ������ �����")
#     if $p->{month};
#   my ($list,$services) = @{$self->soap('client','list',\%p)};
#   print "����� �������� (".(scalar @$list)."):\n";
#   my $table = Text::FormatTable->new('l l | r '.join('',map {' | l '} @$services));
#
#   $table->head('ID','���������/���','������',map {$_->{name}} @$services);
#   $table->rule('=');
#   my $balance=0;
#   my %charged;
#   my %traff;
#   foreach my $client (@$list) {
#     my $id = $client->{client_id};
#     $id="0$id" if $id<10;
#     $balance+=$client->{balance};
#     my @a=("[$id]","$client->{client}\n�. $client->{telefon}",
#            FormatMoney($client->{balance},$client->{currency}));
#
#     foreach my $s (@{$services}) {
#       $client->{charges}={} unless $client->{charges};
#       my $c = $client->{charges}->{$s->{id}};
#       $traff{$s->{id}}={} unless exists $traff{$s->{id}};
#       my $t  = $traff{$s->{id}};
#       if ($c) {
#         $charged{$s->{id}}+=$c->{summa};
#         $charged{all}+=$c->{summa};
#         push @a,FormatMoney($c->{summa},$client->{currency})."\n".FormatBytes($c->{traffic}->{0})."/".FormatBytes($c->{traffic}->{1});
#         $t->{0}+=$c->{traffic}->{0};   $t->{1}+=$c->{traffic}->{1};
#       } else {
#         push @a,'-';
#       }
#     }
#     $table->row(@a);
#   }
#   $table->rule();
#   $table->row('*',FormatMoney($balance,'�.'), FormatMoney($charged{all},'�.'),
#               map {FormatMoney($charged{$_->{id}},'�.')."\n".
#                      FormatBytes($traff{$_->{id}}->{0}).'/'.FormatBytes($traff{$_->{id}}->{1})}
#               @$services
#              );
#   $self->showTable($table);
# }

sub CMD_restore_balance {
  my ($self,$client) = @_;
  print "�����ޣ� ����������� �������: ";
  my $res = $self->soap('client','restore_balance',$client);
  if (defined  $res) {
    print abs($res)>0.01 ? "�������� ������� � $res ������" : "������� ���";
  } else {
    print "������";
  }
  print "\n";
}


sub CMD_recharge_client {
  my $self = shift;
  my ($client,$date) = $self->strToArr(@_);
  my $res = $self->soap('client','recharge',$client);
  print "����������� ��������: $res\n";
}


sub CMD_send_mail {
  my ($self,$p) = @_;
  my $options;
  $p  = $self->strToHash($p);
  fatal("�� ������ ������")  unless $p->{client_id};
  fatal("�� ������ ������")  unless $p->{template};
  $options->{use_main_email}=$p->{use_main_email};
  $options->{from_client_id}=$p->{from_client_id};
  my $res = $self->soap('client','send_mail',$p->{client_id},$p->{template}, 0, $options);
}


sub CMD_change_tariff {
  my ($self,$p) = @_;
  $p  = $self->strToHash($p);
#  $p->{date} = $p->{month} ? ParseMonth($p->{month}) :  ToDate(today());
 # fatal("������� ������ �����") unless $p->{date};
  fatal("�� ������ �����") unless $p->{tariff_id};
  fatal("�� ������ ������") unless $p->{client_id};
  print "����� ������: ";
  $p->{date}=$p->{month} if $p->{month};
  $p->{no_check}=1;
  my $res = $self->soap('client','change_tariff',$p);
  print $res ? "OK\n" : "������, ����� ����� ����� ��� ����������\n";
  return !$res;
}

sub CMD_show_history {
  my ($self,$p) = @_;
  my ($client) = $self->strToArr($p);
  my $res = $self->soap('client','history',$client);
  unless ($res) {
    print "��� ������ �������\n";
  }
  foreach (@$res) {
  }
}



sub CMD_activate_client {
  my ($self,$p) = @_;
  my ($client,$date,$comment) = $self->strToArr($p);
  my $date  = $date ? ParseDate($date) : ToDate(today());
  print "��������� �������: ";
  my $res = $self->soap('client','activate',$client,$date,$comment);
  print $res ? "OK\n" : "������\n";
  return !$res;
}

sub CMD_deactivate_client {
  my ($self,$p) = @_;
  my ($client,$date,$type,$comment) = $self->strToArr($p);
  my $date  = $date ? ParseDate($date) : ToDate(today());
  print "���������� �������: ";
  my $res = $self->soap('client','deactivate',$client,$date,$comment,$type);
  print $res ? "OK\n" : "������\n";
  return !$res;
}

sub CMD_show_account {
  my $self = shift;
  # TODO �������� � ����� ���� �����������, ����� � ���� �����
  my $res = $self->soap('client','account',@_);

  print "��� ������ �������." unless $res;
  fatal("����� �������� ����� ������ - $res.") if !ref($res) && $res>1;
  return 1 unless ref($res);
  my $table = $self->ShowClient($res->{client});
  print "���������� ������:\n";
  $self->showTable($table);
  foreach my $service (@{$res->{services}}) {
    $table = Text::FormatTable->new('r | l | l | l ');
    $table->rule('=');
    $table->head('�����', '�����', '���� ���������', '����������');
    $table->rule('-');
    print "\n������ ��������� ������� ��� '$service->{service}':\n";
    foreach (@{$service->{tariffes}}) {
      $table->row(DateToMonth($_->{from_ym}),$_->{tariff}, $_->{changetime}->TimeFormat('%x %T'), $_->{comment});
    }
    $table->rule('-');
    $self->showTable($table);
  }
  my $table = Text::FormatTable->new('l | r | '.join(' | ',map {"r"} @{$res->{services}}));
  $table->rule('=');
  $table->head('������', '���������', @{$res->{services}});
  $table->rule('-');
  $self->showTable($table);
  return 0;
}

sub CMD_show_check_act {
  my $self = shift;
  # TODO ������ �������� year=
  my $res = $self->soap('client','check_act',@_);

  print "��� ������ �������." unless $res;
  fatal("����� �������� ����� ������ - $res.") if !ref($res) && $res>1;
  return 1 unless ref($res);
  my $table = $self->ShowClientM($res->{client},1);
  print "���������� ������:\n";
  $self->showTable($table);
  print "��� ������:\n";
  my $table = Text::FormatTable->new(' r | r | r | r | l ');
  $table->rule('=');
  $table->head('����', '�����/���������', '������/������', '������', '��������');
  $table->rule('-');
  my $balance;
  my ($summa_charges,$summa_payments);
  foreach my $m (@{$res->{motions}}) {
    if ($m->{payments}) {
      foreach my $p (@{$m->{payments}}) {
        my $n = $p->{method}->{name};
        $n="$n (�����)" unless $p->{type};
        $n="$n #".$p->{id};
        $summa_payments+=$p->{summa_order}
          if $p->{type};
        $table->row($p->{date},'',
                    FormatMoney($p->{summa_order}),FormatMoney($summa_payments-$summa_charges),$n);
      }

    } else {

      my $date = $m->{charge}->{date};
      $date="* $date" unless $m->{charge}->{is_closed};
      $table->row($date,FormatMoney($m->{charge}->{summa_order}),'',
                  FormatMoney($summa_payments-$summa_charges),
                  "$m->{charge}->{service}, $m->{charge}->{tariff}");
      $summa_charges+=$m->{charge}->{summa_order};
    }
  }
  $table->rule('-');
  $table->row('����� (���������):',FormatMoney($summa_charges),FormatMoney($summa_payments),
              FormatMoney($summa_payments-$summa_charges),'',);
  $self->showTable($table);
  return 0;
}

sub CP {
  my $self = shift;
  my $cid = shift;
  my $p = $self->soap('client','payments',$cid);
  my $s = 0;
  foreach (@$p) {
    $s+=$_->{summa_order} if $_->{type}==0;
  }
  return $s;
}

sub CMD_list_activations {
  my $self = shift;
  my $res = $self->soap('client','list_activations',$self->strToArr(@_));
  unless ($res) {
    print "��� ������ �������\n";
    return;
  }
  my $table = $self->ShowClientM($res->{client});
  print "���������� ������:\n";
  $self->showTable($table);

  $table = Text::FormatTable->new('r | l | l | l ');
  $table->rule('=');
  $table->head('����', '��������', '���������', '����������');
  $table->rule('-');
  my $a = {0=>'�������',1=>'������������� ������',2=>'��������� ��������',3=>'����������� ���������',4=>'����� �������',5=>'������ �������',6=>'������ ������',7=>'��� ������. ���� � �����.'};
  foreach (@{$res->{activations}}) {
    $table->row($_->{date}->TimeFormat('%x'),
                $_->{is_active} ? '�����������' : "�������������: $a->{$_->{type}}",
                $_->{done_time},$_->{comment});
  }
  $table->rule('-');
  $self->showTable($table);
  return 0;
}

sub CMD_list_charges {
  my ($self,$p) = @_;

  # TODO �������� � ����� ���� �����������, ����� � ���� �����
  my %h;
  if ($p=~/^(\d+)$/) {
    $h{client_id}=$1;
  } else {
    %h=%{$self->strToHash($p)};
  }
  if ($h{month}) {
    $h{month} = ParseMonth($h{month}) || fatal("������� ������ �����")
  } elsif (!$h{client_id}) {
    $h{month} = today();
  }
  my $res = $self->soap('client','charges',$h{client_id},\%h);
  my $traffic_all=0;
  if ($h{month}) {
    if ($h{tab}) {

      my @fields = qw(client_id iptraff_summa iptraff_summa_order other_summa other_summa_order summa summa_order total_days act_log traffic_summa traffic_free season_summa tariff_id);
      my @client_fields = qw(name firmname is_firm reg_date balance is_active deactivation_type activation_time is_removed status_id real_connection_summ is_good_month good_month_cnt);
      my @tariff_fields = qw(name is_active is_unlim speed hosts_limit night_speed price);
      my @address_fields = qw(street_id building_id room building street);
      my @traffic_fields = qw(0 1 10);

      print join("\t",
                 @fields,
                 (map {"client.$_"} @client_fields),
                 (map {"tariff.$_"} @tariff_fields),
                 (map {"traffic.$_"} @traffic_fields),
                 (map {"address.$_"} @address_fields),
                )."\n";
      foreach my $charge (@$res) {
        my @a1 = map {"$charge->{$_}"} @fields;
        my @a2 = map {"$charge->{client}->{$_}"} @client_fields;
        my @a3 = map {"$charge->{tariff}->{$_}"} @tariff_fields;
        my @a4 = map {"$charge->{traffic}->{$_}"} @traffic_fields;
        my @a5 = map {"$charge->{address}->{$_}"} @address_fields;

        print join("\t",@a1,@a2,@a3,@a4,@a5);
        print "\n";
       }
    } else {
       my $table = Text::FormatTable->new('r | l | l | l | l | l | l | l | r');
       $table->rule('=');
       $table->head('�������', '������, �����', "��������� (���)", "�� ������ (���)",
                    "������ �������/������/�����", '�� ����','���������', "���������", '�ޣ�');
       $table->rule('-');
       print "\n������ �ߣ��:\n";
       my ($summa,$summa_order,$traffic_day,$traffic_night);
       foreach my $charge (@$res) {
         $traffic_day+=$charge->{traffic}->{0};
         $traffic_night+=$charge->{traffic}->{10};
         $summa+=$charge->{summa};
         $summa_order+=$charge->{summa_order};
         ShowCharge($table,"[$charge->{client_id}] $charge->{client}->{name}",$charge);
         $table->rule('-');
       }
       $table->row('����� ������ �� ','','','',FormatBytes($traffic_day).'/'.FormatBytes($traffic_night).'/'.FormatBytes($traffic_day+$traffic_night),'','',FormatMoney($summa),FormatMoney($summa_order));#FormatBytes($traffic_all)
       $table->rule('=');
       $self->showTable($table);
     }
  } else {
    my $client = $self->soap('client','get',$h{client_id});
    my $table = $self->ShowClientM($client);
    print "���������� ������:\n";
    $self->showTable($table);
    my $summa = $self->ShowCharges($res);
    print "����� ������� ����� ��: ".FormatMoney($summa)."\n";
  }
  return 0;
}

sub ShowCharges {
  my ($self,$charges) = @_;
  my $table = Text::FormatTable->new('r | l | l | l | l | l | l | l | r');
  $table->rule('=');
  $table->head('�����', '����� (������� ����)', "��������� (���)",
               "�� ������ (���)",
               "������ �����\n����/����/�����", '�� ����', '���������', "���������", '�ޣ�');
  $table->rule('-');
  print "\n������ �ߣ��:\n";
  my ($summa,$summa_order);
  foreach my $charge (reverse @$charges) {
    $summa+=$charge->{summa};
    $summa_order+=$charge->{summa_order};
    ShowCharge($table,$charge->{month},$charge);
  }
  $table->rule('=');
  $self->showTable($table);
  return ($summa,$summa_order);
}

sub ShowCharge {
  my ($table,$name,$charge)=@_;
  my $t = $charge->{traffic}->{0}+$charge->{traffic}->{10};
  my $t = $t-$charge->{traffic_free}>0 ? $t-$charge->{traffic_free} : 0;
  my $tariff = "#$charge->{tariff_id}:$charge->{tariff}->{name}";
  $table->row($name,
              "$tariff ($charge->{total_days}/$charge->{month_days})",
              FormatMoney($charge->{season_summa}).' ('.FormatBytes($charge->{traffic_free}).')',
              FormatMoney($charge->{traffic_summa}).' ('.FormatBytes($t).')',
              FormatBytes($charge->{traffic}->{0}).'/'.FormatBytes($charge->{traffic}->{10}).'/'.FormatBytes($charge->{traffic}->{0}+$charge->{traffic}->{10}),
              FormatMoney($charge->{iptraff_summa}),
              FormatMoney($charge->{other_summa}),
              FormatMoney($charge->{summa}),
              FormatMoney($charge->{summa_order})
             );
}


1;
