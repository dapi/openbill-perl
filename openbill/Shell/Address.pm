package openbill::Shell::Address;
use strict;
use dpl::Context;
use openbill::Shell;
use openbill::Shell::Base;
use Exporter;
use vars qw(@ISA
            @EXPORT);
@ISA=qw(Exporter
        openbill::Shell::Base);


registerCommands('openbill::Shell::Address',
                 {
                  show_address=>{},
                  list_addresses=>{},
                  create_address=>{},
                  delete_address=>{},
                  modify_address=>{},
                 });

sub CMD_list_addresses {
  my ($self,$p) = @_;
  my $p  = $self->strToHash($p);
  my $building;
  if (exists $p->{building_id}) {
    if (exists $p->{street_id}) {
      print "Можно указывать только улицу или здание\n";
      return 2;
    }
    $building = $self->soap('building','get',$p->{building_id});
    unless ($building) {
      print "Нет такого здания\n";
      return 1;
    }
  }
  my $street;
  if ($p->{street_id}) {
    $street = $self->soap('street','get',$p->{street_id});
    print "Нет такой улицы\n";
    return 3;
  }
  my $list = $self->soap('address','list',$p);
  if (exists $p->{building_id}) {
    print "Список аресов (".(scalar @$list)."), для дома $building->{num} $building->{street}:\n";
  } elsif (exists $p->{street_id}) {
    print "Список аресов (".(scalar @$list)."), для улицы $street->{name}\n";
  } else {
    print "Список адресов (".(scalar @$list)."):\n";
  }

  my $table = Text::FormatTable->new('r| l l l l');
  $table->rule('=');
  $table->head('ID', 'Улица', 'Дом', 'Квартира/Офис', 'Коментарий');
  $table->rule('-');
  foreach my $d (@$list) {
    my $id = $d->{address_id}+0;
    $id="0$id" if $id<10;
    $table->row($id, $d->{street}, $d->{building}, $d->{room}, $d->{comment});
  }
  $table->rule('=');
  $self->showTable($table);
}

sub CMD_create_address {
  my ($self,$p) = @_;
  print "Создание нового адреса:\n";
  $p=$self->questaddress($p) || return undef;
  if (my $id = $self->soap('address','create',$p)) {
    print "Создан адрес #$id\n";
    return 1;
  } else {
    print "Адрес не создан\n";
    return 0;
  }
}

sub CMD_delete_address {
  my $self = shift;
  if ($self->soap('address','delete',@_)) {
    print "Адрес удалён\n";
    return 0;
  } else {
    print "Адрес не удалён\n";
    return 1;
  }
}

sub CMD_modify_address {
  my ($self,$id,$p) = @_;
  my $p  = $self->strToHash($p);
  my $data = $self->soap('address','get',$id);
  unless ($data) {
    print "Нет такого адреса\n";
    return 1;
  }
  print "Изменение: ";
  foreach (keys %$data) {
    $data->{$_}=$p->{$_}
      if exists $p->{$_};
  }
  $p=$self->questaddress($data) || return undef;
  if ($self->soap('address','modify',$id,$p)) {
    print "OK\n"; return 0;
  } else {
    print "Ошибка\n";  return 1;
  }
}

sub CMD_show_address {
  my ($self,$p) = @_;
  my $data = $self->soap('address','get',$p);
  unless ($data) {
    print "Нет такого адреса.";
    return 1;
  }
  my $table = Text::FormatTable->new('r | l ');
  $table->rule('=');
  $table->row('ID',$data->{address_id});
  $table->row('Улица',$data->{street});
  $table->row('Номер дома',$data->{building});
  $table->row('Квартира/Офис',$data->{room});
  $table->row('Коментарий',$data->{comment})
    if $data->{comment};
  $table->rule('-');
  #TODO Выводить кто использует этот адрес
  $self->showTable($table);
}


sub questaddress {
  my ($self,$p) = @_;
  return $self->{shell}->
    Question('address',[{key=>'street',name=>'Улица',obligated=>1,post=>sub {
                          my $params=shift;
                          my $id = $self->soap('street','find',$params->{street})
                            || return undef;
                          delete $params->{street};
                          $params->{street_id}=$id;
                        }},
                       {key=>'building',name=>'Дом',obligated=>1,post=>sub {
                          my $params=shift;
                          my $id = $self->soap('building','find',
                                               $params->{street_id},
                                               $params->{building})|| return undef;
                          delete $params->{building};
                          delete $params->{street_id};
                          $params->{building_id}=$id;
                        }},
                       {key=>'room',name=>'Квартира/Офис',obligated=>1},
                       { key=>'comment',name=>'Коментарий'}],
             $p);
}


1;
