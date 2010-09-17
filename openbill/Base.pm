package openbill::Base;
use strict;
use Data::Dumper;
use dpl::Context;
use dpl::Db::Table;
use dpl::Log;
use dpl::Error;
use dpl::Base;
use Exporter;
use vars qw(@ISA);
@ISA = qw(Exporter
          dpl::Base);
#@EXPORT = qw();

sub new {
  my ($class,$name) = (shift,shift);
  my $self = $class->SUPER::new($name,@_);
  $self->{table} = table($self->{name});
  $self->{idname}= $self->{table}->idname();
  my ($id,$data)  = @_;
  if ($data) {
    $self->SetID($id) if defined $id;
    $self->SetData($data);
  } elsif ($id) {
    $self->Load($id);
  }
  return $self;
}

sub checkParams {
  my ($self,$data) = (shift,shift);
  foreach (@_) {
    $self->fatal("Не указан параметр $_")
      unless exists $data->{$_};
  }
}

sub Delete {
  my ($self) = @_;
  $self->fatal("Нет ID для удаления") unless defined $self->{ID};
  $self->{table}->Delete($self->{ID});
}

sub Create  {
  my ($self,$data) = @_;
  $self->{id}=undef;
  my $res =
    $self->{table}->
      Create($data);
  return undef unless $res;
  $self->SetData($data);
  my $id = $self->SetID($data->{$self->{idname}}=$res->{$self->{idname}} || $data->{$self->{idname}});
  $self->{is_created}=1;
  return $self;
}


sub string {
  my $self = shift;
  my $d = $self->Data();
  return join(' ,',map {"$_:$d->{$_}"} keys %$d);
}

sub Clear {
  my $self = shift;
  $self->{data}=undef;
  $self->{extdata}=undef;
  $self->{id}=undef;
  $self->{is_loaded}=undef;
}

sub Load {
  my ($self,$id,$data) = @_;
#  print STDERR "Load $self->{name}: '$id' '$data'\n";
  return $self if $self->isLoaded() && !$id && !$data;
  if (ref($id)=~/HASH/) {
    fatal("data for setting exists")
      if $data;
    #    $self->error("no object $self->{name} by parameters: ".join(',',%$id))
    return undef
      unless $self->{table}->Load($id);
    $self->SetData($self->{table}->get());
    $self->SetID($self->Data($self->{idname}));
  } elsif (defined $id) {
    if ($data) {
      $self->SetData($data);
    } else {
      unless ($self->{table}->Load($id)) {
        logger()->debug("Объект $self->{name} с ID=$id ненайден");
        return undef;
      }
      $self->SetData($self->{table}->get());
    }
    $self->SetID($id);
  } elsif ($data) {
    $self->SetData($data);
    if (defined $id) {
      $self->SetID($id);
    }
  } else {
    #    $self->SetData();
#    $self->SetID(undef);
  }
  return $self->init();
}

sub isLoaded {
  my $self = shift;
  return $self->{is_loaded};
}

sub List {
  my ($self,$where,$count) = @_;
  my $list = $self->{table}->List($where,$count);
  my @l;
  my $module = ref($self);
  foreach (@$list) {
    push @l, $module->instance($self->{name},
                               $_->{$self->{idname}},
                               $_);
  }
  return wantarray ? @l : \@l;
}

sub DataList {
  my ($self,$where) = @_;
  return $self->{table}->List($where);
}

sub DataFullList {
  my ($self,$where) = @_;
  my $list = $self->{table}->List($where);
  my @l;
  foreach (@$list) {
    my $h = ref($self)->instance($self->{name},
                               $_->{$self->{idname}},
                               $_);
    push @l,$h->DataFull();
  }
  return \@l;
}

sub Delete {
  my $self = shift;
  fatal("Нет ID") unless defined $self->{id};
  $self->{is_loaded}=0;
  $self->{data}=undef;
  return $self->{table}->Delete($self->{id});
}

sub SetID {
  my ($self,$id) = @_;
  fatal("ID уже определён") if defined $self->{id} && $self->{id}!=$id;
  return $self->{id} = $id || fatal("Устанавливается нулевой или пустой ID для $self->{name}");
}

sub ID {
  my ($self,$zz) = @_;
  # ЗЛОЙ ХАК TODO HACK
  #$self->{id}='id' if $self->{name} eq 'mgroup';
  fatal("ID для $self->{name} $self не определён")
    unless defined $self->{id};
  my $id = $self->{id};
  $id="0$id" if $zz && $id<10;
  $id="0$id" if $zz>=2 && $id<100;
  $id="00$id" if $zz>=3 && $id<1000;
  return $id;
}

sub SetData {
  my ($self,$data) = @_;
#  print STDERR "set_data $self->{name} '$data'\n";
  $self->{is_loaded}=1;
  return $self->{data} = $data;
}

sub DataFull {
  my $self = shift;
  return $self->Data(@_);
}

sub Data {
  my ($self,$key) = @_;
  $self->Load() unless $self->isLoaded();
  return $key ? $self->{data}->{$key} : $self->{data};
}

sub Modify {
  my ($self,$p) = @_;
  $self->fatal("Нет ID")
    unless $self->{id};
  $self->fatal("Нет данных")
    unless $p || %$p;
  my $res = $self->{table}->Modify($p,
                                   $self->{id});
  $self->SetData($self->{data}={%{$self->{data}},%$p})
    if $self->isLoaded();
  return $res;
}

sub execute {
  my ($self,$term,$command)=(shift,shift,shift);
  $self->{term}=$term;
  $command='default' unless $command;
  my $ref = $self->can("CMD_$command");
  unless ($ref) {
    $term->result("Unknown command parameter: '$command'");
    return undef;
  }
  $self->{result}=&$ref($self,@_);
  return 1;
}


#sub formatData {
#  my $self = shift;
#  my %d=@_;
#  my $str;
#  foreach (keys %d) {
#    $str.="$d{$_}:\t".$self->Data($_)."\n";
#  }
#  return $str;
#}


sub changeClass {
  my ($self,$file,$module) = @_;
  #  logger()->debug("Загружен collector $module из ".ref($self).". Инициализирую");
  require $file
    if $file;
  return bless $self, $module;
}

sub Find {
  my ($self,$like) = @_;
  if ($like=~/^(\d+)$/) {
    return $self->Load($like);
  } else {
    # TODO переделать через DataList
    my $list = $self->List({like=>$like}) || return undef;
    return @$list==1 ? $list->[0] : scalar @$list;
  }
}

1;
