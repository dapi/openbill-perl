package openbill::Shell::Collector;
use strict;
use openbill::Shell;
use openbill::Utils;
use dpl::Context;
use openbill::Shell::Base;
use Exporter;
use vars qw(@ISA
            @EXPORT);
@ISA=qw(Exporter
        openbill::Shell::Base);


registerCommands('openbill::Shell::Collector',
                 {
                  show_collector=>{},
                  list_collectors=>{},
                  create_collector=>{},
                  delete_collector=>{},
                  modify_collector=>{},
                  collect=>{}
                 });

sub fields {
  my ($self,$data) = @_;
  my $modules = $self->soap('system','modules','collector');
  my @list = (
              {name=>'name',title=>'Название'},
              {name=>'module',title=>'Модуль',
               value=>"$data->{module} ($modules->{$data->{module}}->{desc})"},
              {name=>'arc_dir',title=>'Архивный каталог'},
              {name=>'work_dir',title=>'Рабочий каталог'},
              {name=>'comment',title=>'Коментарий'},
             );
  foreach (@list) {
    $_->{value}=$data->{$_->{name}}
      unless exists $_->{value};
  }
  return \@list;
}

sub questcollector {
  my ($self,$p) = @_;
  my $modules = $self->soap('system','modules','collector');
  return $self->{shell}->
    Question('collector',[
                          {key=>'name',name=>'Название',obligated=>1},
                          {key=>'module',name=>'Модуль',obligated=>1,post=>sub {
                             my $params=shift;
                             return 1 if exists $modules->{$params->{module}};
                             print "\n!!! Нет такого модуля, список возможных:\n";
                             $self->ListModules($modules);
                             return undef;
                           }},
                          {key=>'comment',name=>'Коментарий'}
                         ],$p);
}



sub CMD_show_collector {
  my $self = shift;
  my $data = $self->soap('collector','get',@_);
  unless ($data) {
    print "Нет такого коллектора.";
    return 1;
  }
  my $table = Text::FormatTable->new('r | l ');
  $table->rule('=');
  $table->row('ID',$data->{collector_id});
  foreach (@{$self->fields($data)}) {
    $table->row($_->{title},$_->{value})
      if $_->{value} ne '';
  }
#  $table->row('Модуль,$_->{value})
  $self->showTable($table);
  return 0;
}


sub CMD_list_collectors {
  my $self = shift;
  my $list = $self->soap('collector','list',@_);
  my $modules = $self->soap('system','modules','collector');
  print("Список рабочих сборщиков (".(scalar @$list)."):\n");
  my $table = Text::FormatTable->new('r| l | l | l');
  $table->head('id', 'Название', 'Модуль', 'Комментарий');
  $table->rule('=');

  my %em=%$modules;
  foreach (@$list) {
    my $c = $modules->{$_->{module}}->{desc};
    delete $em{$_->{module}};
    $c=" ($c)" if $c;
    $table->row($_->{collector_id},$_->{name},
                $_->{module}.$c,$_->{comment});
    $table->rule();
  }
  $self->showTable($table);
  $self->ListModules(\%em) if %em;

}

sub ListModules {
  my ($self,$modules) = @_;
  my $table = Text::FormatTable->new('l | l');
  $table->head('Модуль', 'Комментарий');
  $table->rule('=');
  foreach (keys %$modules) {
    $table->row($_,$modules->{$_}->{desc});
  }
  $self->showTable($table);
}

sub CMD_create_collector {
  my ($self,$p) = @_;
  my $p  = $self->strToHash($p);
  print "Создание коллектора:\n";
  $p=$self->questcollector($p) || return undef;
  if (my $id = $self->soap('collector','create',$p)) {
    print "Создан коллектор #$id\n";
    return 1;
  } else {
    print "Коллектор\n";
    return 0;
  }
}

sub CMD_delete_collector {
  my $self = shift;
  if ($self->soap('collector','delete',@_)) {
    print "Коллектор удалёе\n";
    return 0;
  } else {
    print "Коллектор не удалён\n";
    return 1;
  }
}

sub CMD_modify_collector {
  my ($self,$id,$p) = @_;
  my $p  = $self->strToHash($p);
  my $data = $self->soap('collector','get',$id);
  unless ($data) {
    print "Нет такого коллектора\n";
    return 1;
  }
  print "Изменение: ";
  foreach (keys %$data) {
    $data->{$_}=$p->{$_}
      if exists $p->{$_};
  }
  $p=$self->questcollector($data) || return undef;
  if ($self->soap('collector','modify',$id,$p)) {
    print "OK\n";
    return 0;
  } else {
    print "Ошибка\n";
    return 1;
  }
}

sub CMD_collect {
  my $self = shift;
  print "Собираю статистику с коллекторов: ";
  $self->soap('collector','collect',$self->strToHash(@_));
  print "Готово\n";
}


1;
