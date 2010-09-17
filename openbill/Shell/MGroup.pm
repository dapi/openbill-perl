package openbill::Shell::MGroup;
use strict;
use openbill::Shell;
use openbill::Shell::Base;
use dpl::Context;
use Exporter;
use vars qw(@ISA @EXPORT);
@ISA=qw(Exporter openbill::Shell::Base);

registerCommands('openbill::Shell::MGroup',
                 {
                  show_mgroup=>{},
                  list_mgroups=>{},
                  list_mgroups_methods=>{},
                  add_mgroup_method=>{},
                  delete_mgroup_method=>{},
                  create_mgroup=>{},
                  modify_mgroup=>{},
                 });

sub questmgroup {
  my ($self,$p) = @_;
  return $self->{shell}->
    Question('mgroup',[{key=>'name',name=>'Имя',obligated=>1},
                        {key=>'is_admin',type=>'boolean',name=>'Администратор',obligated=>1,
                         pre=>sub {
                           return $_[2] ? 'да' : 'нет';
                         }},
                        {key=>'comment',name=>'Коментарий'}],
             $p);
}

sub CMD_add_mgroup_method {
  my $self = shift;
  my $mgroup_id = shift;
  my $data = $self->soap('mgroup','get',$mgroup_id);
  unless ($data) {
    print "Нет такой группы.";
    return 1;
  }
  print "Добавление в группу $data->{name} доступа:\n\n";
  my $p = $self->{shell}->
    Question('mgroup_method',
             [{key=>'object',name=>'Объект',obligated=>1},
              {key=>'method',name=>'Метод',obligated=>1},
              {key=>'params',name=>'Параметры'},
              {key=>'comment',name=>'Коментарий'}],
            );
  $p->{method}=undef if $p->{method} eq '*';
  return $self->soap('mgroup','addMethod',$mgroup_id,$p);
}

sub CMD_delete_mgroup_method {
  my $self = shift;
  my ($mgroup_id,$object,$method,$params) = $self->strToArr(@_);
  my $data = $self->soap('mgroup','get',$mgroup_id);
  unless ($data) {
    print "Нет такой группы.";
    return 1;
  }
  print "Удаление метода из группы '$data->{name}'\n";
  return $self->soap('mgroup','deleteMethod',
                     $mgroup_id,{object=>$object,
                                 method=>$method,
                                 params=>"$params"});
}

sub CMD_list_mgroups_methods {
  my $self = shift;
  my $data = $self->soap('mgroup','get',@_);
  unless ($data) {
    print "Нет такой группы.";
    return 1;
  }
  print "Доступные функции группы '$data->{name}'\n\n";
  my $list = $self->soap('mgroup','listMethods',@_);
  my $table = Text::FormatTable->new('rl l l');
  $table->head('Объект->', 'Метод', 'Параметры', 'Коментарий');
  $table->rule('=');
  foreach (@$list) {
    my $m = $_->{method} || '*';
    $table->row("$_->{object}->",$m,$_->{params},$_->{comment});
  }
  $self->showTable($table);
  return 0;
}


sub CMD_show_mgroup {
  my $self = shift;
  my $data = $self->soap('mgroup','get',@_);
  unless ($data) {
    print "Нет такой группы.";
    return 1;
  }
  my $table = Text::FormatTable->new('r | l ');
  $table->rule('=');
  $table->row('ID',$data->{id});
  $table->row('Имя',$data->{name});
  $table->row('login',$data->{login});
  $table->row('Администратор',$data->{is_admin} ? 'ДА' : 'no');
  $table->row('Коментарий',$data->{comment})
    if $data->{comment};
  $self->showTable($table);
  return 0;
}

sub CMD_list_mgroups {
  my $self = shift;
  my $list = $self->soap('mgroup','list',@_);
  $self->ListMgroups($list);
}

sub ListMgroups {
  my ($self,$list) = @_;
  print "Список менеджеров (".(scalar @$list)."):\n";
  my $table = Text::FormatTable->new('r| l l l');
  $table->rule('=');
  $table->head('ID', 'Название', 'Администратор', 'Коментарий');
  $table->rule('-');
  foreach my $d (@$list) {
    my $id = $d->{id}+0;
    $id="0$id" if $id<10;
    $table->row($id, $d->{name}, $d->{is_admin} ? 'ДА' : 'no', $d->{comment});
  }
  $table->rule('=');
  $self->showTable($table);
}

sub CMD_create_mgroup {
  my ($self,$p) = @_;
  print "Создание новой группы:\n";
  $p=$self->questmgroup($p) || return undef;
  if (my $id = $self->soap('mgroup','create',$p)) {
    print "Создана группа #$id\n";
    return 1;
  } else {
    print "Группа не создан\n";
    return 0;
  }
}

sub CMD_delete_mgroup {
  my $self = shift;
  if ($self->soap('mgroup','delete',@_)) {
    print "Группа удалён\n";
    return 0;
  } else {
    print "Группа не удалён\n";
    return 1;
  }
}

sub CMD_modify_mgroup {
  my ($self,$id,$p) = @_;
  my $p  = $self->strToHash($p);
  my $data = $self->soap('mgroup','get',$id);
  unless ($data) {
    print "Нет такой группы\n";
    return 1;
  }
  print "Изменение: ";
  foreach (keys %$data) {
    $data->{$_}=$p->{$_}
      if exists $p->{$_};
  }
  $p=$self->questmgroup($data) || return undef;
  if ($self->soap('mgroup','modify',$id,$p)) {
    print "OK\n";
    return 0;
  } else {
    print "Ошибка\n";
    return 1;
  }
}

1;
