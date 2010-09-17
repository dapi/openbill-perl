package openbill::Shell::Building;
use strict;
use openbill::Shell;
use openbill::Shell::Base;
use dpl::Context;
use Exporter;
use vars qw(@ISA
            @EXPORT);
@ISA=qw(Exporter
        openbill::Shell::Base);


registerCommands('openbill::Shell::Building',
                 {
                  create_building=>{},
                  show_building=>{},
                  list_buildings=>{},
                  modify_building=>{},
                  delete_building=>{},
                 });

sub questbuilding {
  my ($self,$p) = @_;
#  my $streets = $self->soap('street','list');
#  my %streets;
#  foreach (@$streets) {
#    $streets{$_->{name}}=$_->{street_id};
#    $streets{"#$_->{street_id}"}=$_->{street_id};
#  }
  return $self->{shell}->
    Question('street',[{key=>'street',name=>'Улица',obligated=>1,post=>sub {
                          my $params=shift;
                          my $id = $self->soap('street','find',$params->{street})
                            || return undef;
                          delete $params->{street};
                          $params->{street_id}=$id;
                        }},
                       {key=>'number',name=>'Номер дома',obligated=>1},
                       {key=>'comment',name=>'Коментарий'}],
             $p);
}

sub CMD_list_buildings {
  my $self = shift;
  my $p  = $self->strToHash(@_);
  my $list = $self->soap('building','list',$p);
  if ($p->{street_id}) {
    my $street  = $self->soap('street','get',$p->{street_id});
    print "Список зданий (".(scalar @$list)."), для улицы $street->{name}:\n";
  } else {
    print "Список зданий (".(scalar @$list)."):\n";
  }
  $self->ListBuildings($list);
}

sub ListBuildings {
  my ($self,$list) = @_;
  my $table = Text::FormatTable->new('r | l | l | l | l');
  $table->row('#','Балансодержатель','Улица','Дом','Комментарий');
  $table->rule('-');
  foreach (@$list) {
    $table->row($_->{building_id},$_->{holder}->{name},$_->{street},$_->{number},$_->{comment});
  }
  $self->showTable($table);

}

sub CMD_show_building {
  my ($self,$p) = @_;
  my $data = $self->soap('building','get',$p);
  unless ($data) {
    print "Нет такого здания.";
    return 1;
  }
  my $table = Text::FormatTable->new('r | l ');
  $table->rule('=');
  $table->row('ID',$data->{building_id});
  $table->row('Номер дома',$data->{number});
  $table->row('Улица',$data->{street});
  $table->row('Балансодержатель',$data->{holder}->{name});
  $table->row('Коментарий',$data->{comment})
    if $data->{comment};
  $table->rule('-');
  $table->row('Адресов',$data->{addresses_count}+0);
  $self->showTable($table);
}

sub CMD_create_building {
  my ($self,$p) = @_;
  print "Создание нового здания:\n";
  $p=$self->questbuilding($p) || return undef;
  if (my $id = $self->soap('building','create',$p)) {
    print "Создано здание #$id\n";
    return 1;
  } else {
    print "Здание не создано\n";
    return 0;
  }
}

sub CMD_delete_building {
  my $self = shift;
  if ($self->soap('buiding','delete',@_)) {
    print "Здание удалено\n";
    return 0;
  } else {
    print "Здание не удалено\n";
    return 1;
  }
}

sub CMD_modify_building {
  my ($self,$id,$p) = @_;
  my $p  = $self->strToHash($p);
  my $data = $self->soap('building','get',$id);
  unless ($data) {
    print "Нет такого здания\n";
    return 1;
  }
  print "Изменение: ";
  foreach (keys %$data) {
    $data->{$_}=$p->{$_}
      if exists $p->{$_};
  }
  $p=$self->questbuilding($data) || return undef;
  if ($self->soap('building','modify',$id,$p)) {
    print "OK\n"; return 0;
  } else {
    print "Ошибка\n";  return 1;
  }
}

1;
