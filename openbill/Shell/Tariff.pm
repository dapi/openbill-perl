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
    Question('tariff',[{key=>'name',name=>'Тариф',obligated=>1},
#                       {key=>'is_hidden',name=>'Скрытый',obligated=>1,type=>'boolean',pre=>sub {'нет';}},
                       {key=>'price',name=>'Абонплата',obligated=>1},

                       {key=>'traffic_mb0',name=>'Бесплатный трафик (Мб)',obligated=>0},

                       {key=>'price_mb0',name=>'Стоимость интернет (дневной)',obligated=>1},
                       {key=>'price_mb10',name=>'Стоимость интернет (ночной)',obligated=>1},
#                       {key=>'price_mb2',name=>'Стоимость городской',obligated=>0, default=>0.01},
#                       {key=>'price_mb3',name=>'Стоимость почтовый',obligated=>0, default=>1.3},
#                       {key=>'price_mb4',name=>'Стоимость ночного интернет', default=>1.5 ,obligated=>0},

#                        {key=>'service_id',name=>'Служба',obligated=>1,
#                         default=>'iptraff',
#                         post=>sub {
#                           my $params=shift;
#                           return $params->{service_id}=$services{$params->{service_id}}
#                             if exists $services{$params->{service_id}};
#                           print "\nНет такой служба, список возможных:";
#                           openbill::Shell::Service::ListServices($self,$s);
#                           return undef;
#                         }},
                       {
                        key=>'is_hidden',name=>'Скрытый',obligated=>1,type=>'boolean',
                        pre=>sub {
                           return $_[2] ? 'да' : 'нет';
                        }},
                       {key=>'comment',name=>'Коментарий'}],
             $p);
}


sub fields {
  my ($self,$data) = @_;
  my @list = (
              {name=>'name',title=>'Название'},
              {name=>'is_hidden',title=>'Скрытый'},
              #              {name=>'is_active',title=>'Действующий'},
              #              {name=>'is_firm',title

              {name=>'is_unlim',title=>'Безлимитный'},
              {name=>'speed',title=>'Скорость'},
              {name=>'hosts_limit',title=>'Ограничение по хостам'},
              {name=>'night_speed',title=>'Ночная скорость'},

              {name=>'price',title=>'Абонплата'},

              {name=>'comment',title=>'Комментарий'},

              {name=>'traffic_mb0',title=>'Трафик класса 0'},
              {name=>'traffic_mb1',title=>'Трафик класса 1'},
              {name=>'traffic_mb2',title=>'Трафик класса 2'},
              {name=>'traffic_mb3',title=>'Трафик класса 3'},
              {name=>'traffic_mb4',title=>'Трафик класса 4'},
              {name=>'traffic_mb5',title=>'Трафик класса 5'},
              {name=>'traffic_mb6',title=>'Трафик класса 6'},
              {name=>'traffic_mb7',title=>'Трафик класса 7'},
              {name=>'traffic_mb8',title=>'Трафик класса 8'},
              {name=>'traffic_mb9',title=>'Трафик класса 9'},
              {name=>'traffic_mb10',title=>'Трафик класса 10'},
              {name=>'traffic_mb11',title=>'Трафик класса 11'},

              {name=>'price_mb0',title=>'Стоимость класса 0'},
              {name=>'price_mb1',title=>'Стоимость класса 1'},
              {name=>'price_mb2',title=>'Стоимость класса 2'},
              {name=>'price_mb3',title=>'Стоимость класса 3'},
              {name=>'price_mb4',title=>'Стоимость класса 4'},
              {name=>'price_mb5',title=>'Стоимость класса 5'},
              {name=>'price_mb6',title=>'Стоимость класса 6'},
              {name=>'price_mb7',title=>'Стоимость класса 7'},
              {name=>'price_mb8',title=>'Стоимость класса 8'},
              {name=>'price_mb9',title=>'Стоимость класса 9'},
              {name=>'price_mb10',title=>'Стоимость класса 10'},
              {name=>'price_mb10',title=>'Стоимость класса 11'},

#               {
#                name=>'nick',title=>'Псевдоним'},
#               {name=>'reg_date',title=>'Регистрация',
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
    print "Нет такого тарифа.";
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
  print "Список тарифов (".(scalar @$list)."):\n";
  my $table = Text::FormatTable->new('r| l l l l l l ');
  $table->rule('=');
  $table->head('ID', 'Тариф', 'Скорость (день/предел-ночь)', 'Абонплата', 'Трафик', 'Интернет дневной','Интернет ночной');
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

    $table->row($id, $name, $speed, "$d->{price} р.", "$d->{traffic_mb0} Mb", "$d->{price_mb0} р.","$d->{price_mb10} р.");
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
  print "Создание нового тарифа:\n";
  $p=$self->questtariff($p) || return undef;
  $p->{service_id}=1;
  $p->{is_active}=1;
  if (my $id = $self->soap('tariff','create',$p)) {
    print "Создан тариф #$id\n";
    return 1;
  } else {
    print "Тариф не создан\n";
    return 0;
  }
}

sub CMD_delete_tariff {
  my $self = shift;
  if ($self->soap('tariff','delete',@_)) {
    print "Тариф удалён\n";
    return 0;
  } else {
    print "Тариф не удалён\n";
    return 1;
  }
}

sub CMD_modify_tariff {
  my ($self,$id,$p) = @_;
  my $p  = $self->strToHash($p);
  my $data = $self->soap('tariff','get',$id);
  unless ($data) {
    print "Нет такого тарифа\n";
    return 1;
  }
  print "Изменение: ";
  foreach (keys %$data) {
    $data->{$_}=$p->{$_}
      if exists $p->{$_};
  }
  $p=$self->questtariff($data) || return undef;
  if ($self->soap('tariff','modify',$id,$p)) {
    print "OK\n";
    return 0;
  } else {
    print "Ошибка\n";
    return 1;
  }
}

1;
