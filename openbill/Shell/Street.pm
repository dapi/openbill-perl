package openbill::Shell::Street;
use strict;
use openbill::Shell;
use openbill::Shell::Base;
use dpl::Context;
use Exporter;
use vars qw(@ISA
            @EXPORT);
@ISA=qw(Exporter
        openbill::Shell::Base);

registerCommands('openbill::Shell::Street',
                 {
                  show_street=>{},
                  list_streets=>{},
                  create_street=>{},
                  delete_street=>{},
                  modify_street=>{},
                 });

sub queststreet {
  my ($self,$p) = @_;
  return $self->{shell}->
    Question('street',[
                       {key=>'city_id',name=>'Город',obligated=>1},
                       {key=>'name',name=>'Улица',obligated=>1},
                       {key=>'comment',name=>'Коментарий'}],
             $p);
}

sub CMD_show_street {
  my $self = shift;
  my $data = $self->soap('street','get',@_);
  unless ($data) {
    print "Нет такой улицы.";
    return 1;
  }
  my $table = Text::FormatTable->new('r | l ');
  $table->rule('=');
  $table->row('ID',$data->{street_id});
  $table->row('Улица',$data->{name});
  $table->row('Коментарий',$data->{comment})
    if $data->{comment};
  $table->rule('-');
  $table->row('Домов',$data->{buildings_count}+0);
  $table->row('Адресов',$data->{addresses_count}+0);
  $self->showTable($table);
  return 0;
}

sub CMD_list_streets {
  my $self = shift;
  my $p  = $self->strToHash(@_);
  my $w;
  if ($p->{like}) {
    $w="name like '%$p->{like}%'";
  }
  my $list = $self->soap('street','list',$w);
  $self->ListStreets($list);
}

sub ListStreets {
  my ($self,$list) = @_;
  print "Список улиц (".(scalar @$list)."):\n";
  my $table = Text::FormatTable->new('r| l l l');
  $table->rule('=');
  $table->head('ID', 'Улица', 'Город', 'Коментарий');
  $table->rule('-');
  foreach my $d (@$list) {
    my $id = $d->{street_id}+0;
    $id="0$id" if $id<10;
    $table->row($id, $d->{name}, $d->{city}, $d->{comment});
  }
  $table->rule('=');
  $self->showTable($table);
}

sub CMD_create_street {
  my ($self,$p) = @_;
  print "Создание новой улицы:\n";
  $p=$self->queststreet($p) || return undef;
  # TODO
  $p->{city_id}=1;
  if (my $id = $self->soap('street','create',$p)) {
    print "Создана улица #$id\n";
    return 1;
  } else {
    print "Улица не создана\n";
    return 0;
  }
}

sub CMD_delete_street {
  my $self = shift;
  if ($self->soap('street','delete',@_)) {
    print "Улица удалена\n";
    return 0;
  } else {
    print "Улица не удалена\n";
    return 1;
  }
}

sub CMD_modify_street {
  my ($self,$id,$p) = @_;
  my $p  = $self->strToHash($p);
  my $data = $self->soap('street','get',$id);
  unless ($data) {
    print "Нет такой улицы\n";
    return 1;
  }
  print "Изменение: ";
  foreach (keys %$data) {
    $data->{$_}=$p->{$_}
      if exists $p->{$_};
  }
  $p=$self->queststreet($data) || return undef;
  if ($self->soap('street','modify',$id,$p)) {
    print "OK\n";
    return 0;
  } else {
    print "Ошибка\n";
    return 1;
  }
}

1;
