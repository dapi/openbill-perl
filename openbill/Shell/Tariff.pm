package openbill::Shell::Tariff;
use strict;
use Data::Dumper;
use openbill::Shell;
use openbill::Shell::Base;
use dpl::Context;
use Exporter;
use vars qw(@ISA
            @EXPORT);
@ISA=qw(Exporter
        openbill::Shell::Base);

registerCommands('openbill::Shell::Tariff',
                 {
                  show_tariff=>{},
                  list_tariffes=>{},
                  create_tariff=>{},
                  delete_tariff=>{},
                  modify_tariff=>{},
                 });

sub questtariff {
  my ($self,$p) = @_;
  return $self->{shell}->
    Question('tariff',[{key=>'name',name=>'�����',obligated=>1},
#                       {key=>'is_hidden',name=>'�������',obligated=>1,type=>'boolean',pre=>sub {'���';}},
                       {key=>'price',name=>'���������',obligated=>1},

                       {key=>'traffic_mb0',name=>'���������� ������ (��)',obligated=>0},

                       {key=>'price_mb0',name=>'��������� �������� (�������)',obligated=>1},
                       {key=>'price_mb10',name=>'��������� �������� (������)',obligated=>1},
#                       {key=>'price_mb2',name=>'��������� ���������',obligated=>0, default=>0.01},
#                       {key=>'price_mb3',name=>'��������� ��������',obligated=>0, default=>1.3},
#                       {key=>'price_mb4',name=>'��������� ������� ��������', default=>1.5 ,obligated=>0},

#                        {key=>'service_id',name=>'������',obligated=>1,
#                         default=>'iptraff',
#                         post=>sub {
#                           my $params=shift;
#                           return $params->{service_id}=$services{$params->{service_id}}
#                             if exists $services{$params->{service_id}};
#                           print "\n��� ����� ������, ������ ���������:";
#                           openbill::Shell::Service::ListServices($self,$s);
#                           return undef;
#                         }},
                       {
                        key=>'is_hidden',name=>'�������',obligated=>1,type=>'boolean',
                        pre=>sub {
                           return $_[2] ? '��' : '���';
                        }},
                       {key=>'comment',name=>'����������'}],
             $p);
}


sub fields {
  my ($self,$data) = @_;
  my @list = (
              {name=>'name',title=>'��������'},
              {name=>'is_hidden',title=>'�������'},
              #              {name=>'is_active',title=>'�����������'},
              #              {name=>'is_firm',title

              {name=>'is_unlim',title=>'�����������'},
              {name=>'speed',title=>'��������'},
              {name=>'hosts_limit',title=>'����������� �� ������'},
              {name=>'night_speed',title=>'������ ��������'},

              {name=>'price',title=>'���������'},

              {name=>'comment',title=>'�����������'},

              {name=>'traffic_mb0',title=>'������ ������ 0'},
              {name=>'traffic_mb1',title=>'������ ������ 1'},
              {name=>'traffic_mb2',title=>'������ ������ 2'},
              {name=>'traffic_mb3',title=>'������ ������ 3'},
              {name=>'traffic_mb4',title=>'������ ������ 4'},
              {name=>'traffic_mb5',title=>'������ ������ 5'},
              {name=>'traffic_mb6',title=>'������ ������ 6'},
              {name=>'traffic_mb7',title=>'������ ������ 7'},
              {name=>'traffic_mb8',title=>'������ ������ 8'},
              {name=>'traffic_mb9',title=>'������ ������ 9'},
              {name=>'traffic_mb10',title=>'������ ������ 10'},
              {name=>'traffic_mb11',title=>'������ ������ 11'},

              {name=>'price_mb0',title=>'��������� ������ 0'},
              {name=>'price_mb1',title=>'��������� ������ 1'},
              {name=>'price_mb2',title=>'��������� ������ 2'},
              {name=>'price_mb3',title=>'��������� ������ 3'},
              {name=>'price_mb4',title=>'��������� ������ 4'},
              {name=>'price_mb5',title=>'��������� ������ 5'},
              {name=>'price_mb6',title=>'��������� ������ 6'},
              {name=>'price_mb7',title=>'��������� ������ 7'},
              {name=>'price_mb8',title=>'��������� ������ 8'},
              {name=>'price_mb9',title=>'��������� ������ 9'},
              {name=>'price_mb10',title=>'��������� ������ 10'},
              {name=>'price_mb10',title=>'��������� ������ 11'},

#               {
#                name=>'nick',title=>'���������'},
#               {name=>'reg_date',title=>'�����������',
#                value=>$data->{reg_date}->TimeFormat('%e %B %Y')},
             );

  foreach (@list) {
    #    unless (exists $_->{value}) {
    $_->{value}=$data->{$_->{name}};
      #    }
  }

  return \@list;
}


sub CMD_show_tariff {
  my $self = shift;
  my $data = $self->soap('tariff','get',@_);
  unless ($data) {
    print "��� ������ ������.";
    return 1;
  }

  my $table = Text::FormatTable->new('r | l ');
  $table->rule('=');
  $table->row('ID',$data->{id});
  my $l = $self->fields($data);
  foreach (@$l) {
    $table->row($_->{title},$_->{value})
    if $_->{value} ne '';
  }
  $table->rule('=');
  $self->showTable($table);
  return 0;
}

sub CMD_list_tariffes {
  my ($self,$p) = @_;
  $p  = $self->strToHash($p);
  my $list = $self->soap('tariff','list');
  $self->ListTariffs($list,$p);
}

sub ListTariffs {
  my ($self,$list,$p) = @_;
  print "������ ������� (".(scalar @$list)."):\n";
  my $table = Text::FormatTable->new('r| l l l l l l ');
  $table->rule('=');
  $table->head('ID', '�����', '�������� (����/������-����)', '���������', '������', '�������� �������','�������� ������');
  $table->rule('-');
  foreach my $d (@$list) {
    if (exists $p->{is_hidden}) {
      next if $d->{is_hidden}!=$p->{is_hidden};
 #   } else {
#      next if $d->{is_hidden};
    }
    if (exists $p->{is_active}) {
      next unless $d->{is_active}==$p->{is_active};
    } else {
      next unless $d->{is_active};
    }
    my $id = $d->{id}+0;
    $id="0$id" if $id<10;
    my $c = $d->{is_hidden} ? '* ' : '';
    my $name = $c.$d->{name};
    my $speed='*';
    if ($d->{speed}) {
      $speed = $d->{speed};
      $speed.="/$d->{limit_speed}"
        unless $d->{limit_speed}==$d->{speed};
      $speed.="-$d->{night_speed}"
        unless $d->{speed}==$d->{night_speed};
    }

    $table->row($id, $name, $speed, "$d->{price} �.", "$d->{traffic_mb0} Mb", "$d->{price_mb0} �.","$d->{price_mb10} �.");
#     if ($p->{change}) {
#       $self->soap('tariff','modify',$d->{id},{price=>$d->{season_price},
#                                               traffic_mb0=>$d->{season_mb},
#                                               price_mb0=>$d->{mb_price},
#                                               price_mb1=>0,
#                                               price_mb2=>0,
#                                               price_mb3=>1.3,
#                                              });
#     }
  }
  $table->rule('=');
  $self->showTable($table);
}

sub CMD_create_tariff {
  my ($self,$p) = @_;
  print "�������� ������ ������:\n";
  $p=$self->questtariff($p) || return undef;
  $p->{service_id}=1;
  $p->{is_active}=1;
  if (my $id = $self->soap('tariff','create',$p)) {
    print "������ ����� #$id\n";
    return 1;
  } else {
    print "����� �� ������\n";
    return 0;
  }
}

sub CMD_delete_tariff {
  my $self = shift;
  if ($self->soap('tariff','delete',@_)) {
    print "����� ���̣�\n";
    return 0;
  } else {
    print "����� �� ���̣�\n";
    return 1;
  }
}

sub CMD_modify_tariff {
  my ($self,$id,$p) = @_;
  my $p  = $self->strToHash($p);
  my $data = $self->soap('tariff','get',$id);
  unless ($data) {
    print "��� ������ ������\n";
    return 1;
  }
  print "���������: ";
  foreach (keys %$data) {
    $data->{$_}=$p->{$_}
      if exists $p->{$_};
  }
  $p=$self->questtariff($data) || return undef;
  if ($self->soap('tariff','modify',$id,$p)) {
    print "OK\n";
    return 0;
  } else {
    print "������\n";
    return 1;
  }
}

1;
