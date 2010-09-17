package openbill::Shell::Janitor;
use strict;
use openbill::Shell;
use openbill::Utils;
use dpl::Context;
use Text::FormatTable;
use Error qw(:try);
use openbill::Shell::Base;
use Exporter;
use vars qw(@ISA
            @EXPORT);
@ISA=qw(Exporter
        openbill::Shell::Base);


registerCommands('openbill::Shell::Janitor',
                 {
                  list_janitors=>{},
                  show_janitor=>{},
                  create_janitor=>{},
                  modify_janitor=>{},
                  delete_janitor=>{},
                  update_janitors_fake=>{},
                 });

# sub CMD_monthlimit {
#   my $self = shift;
#   my $sth = db()->
#     Select(qq(select client_id, class, sum(bytes) as bytes
#               from day_traffic where shot_id<=$ds_id
#               and date>='$start' and date<='$end'
#               and client_id=$cid group by class));
#   my %bytes;
#   while (my $rec=$sth->fetchrow_hashref()) {
#     $bytes{$rec->{class}}+=$rec->{bytes};
#   }
#
# }

sub CMD_list_janitors {
  my $self = shift;
  my $list = $self->soap('janitor','list',@_);
  my ($em,$modules) = $self->ListJanitors($list);
  if (%$em) {
    print "\n������ �������������� ������������ (".(keys %$modules)."):\n\n";
    my $table = Text::FormatTable->new('l | l');
    $table->head('������', '�����������');
    $table->rule('=');
    foreach (keys %$em) {
      $table->row($_,$modules->{$_}->{desc});
    }
    $self->showTable($table);
  }
}

sub questjanitor {
  my ($self,$p) = @_;
  my $modules = $self->soap('system','modules','janitor');
  return $self->{shell}->
    Question('janitor',
             [{key=>'name',name=>'��������',obligated=>1},
              {key=>'module',name=>'������',obligated=>1,
               post=>sub {
                 my $params=shift;
                 return 1 if exists $modules->{$params->{module}};
                 print "��� ������ ������. ������ ������������:\n";
                 foreach (sort keys %$modules) {
                   print "$_\t$modules->{$_}->{desc}\n";
                 }
                 return 0;
               }},
              {key=>'comment',name=>'����������'}
             ],$p);
}


sub ListJanitors {
  my ($self,$list) = @_;
  print "������ ������� �ߣ������ (".(scalar @$list)."):\n\n";
  my $table = Text::FormatTable->new('r| l| l| l');
  $table->head('id', '��������', '������', '�����������');
  $table->rule('=');
  my $modules = $self->soap('system','modules','janitor');
  my %em=%$modules;
  foreach (@$list) {
    my $c = $modules->{$_->{module}}->{desc};
    delete $em{$_->{module}};
    $c=" ($c)" if $c;
    $table->row($_->{id},
                $_->{name},
                $_->{module}.$c,
                $_->{comment});
    $table->rule();
  }
  $self->showTable($table);
  return (\%em,$modules);
}


sub CMD_create_janitor {
  my ($self,$p) = @_;
  print "�������� ������ �������:\n";
  $p=$self->questjanitor($p) || return undef;
  if (my $id = $self->soap('janitor','create',$p)) {
    print "������ ������ #$id\n";
    return 1;
  } else {
    print "������ �� �������\n";
    return 0;
  }
}

sub CMD_delete_janitor {
  my $self = shift;
  if ($self->soap('janitor','delete',@_)) {
    print "������ ���̣�\n";
    return 0;
  } else {
    print "������ �� ���̣�\n";
    return 1;
  }
}

sub CMD_modify_janitor {
  my ($self,$id,$p) = @_;
  my $p  = $self->strToHash($p);
  my $data = $self->soap('janitor','get',$id);
  unless ($data) {
    print "��� ������ �������\n";
    return 1;
  }
  print "���������: ";
  foreach (keys %$data) {
    $data->{$_}=$p->{$_}
      if exists $p->{$_};
  }
  $p=$self->questjanitor($data) || return undef;
  if ($self->soap('janitor','modify',$id,$p)) {
    print "OK\n";
    return 0;
  } else {
    print "������\n";
    return 1;
  }
}

sub GetJanitor {
  my ($self,$id) = @_;
  my $res = $self->soap('janitor','find',$id);
  fatal("��� ������ �����������") unless $res;
  fatal("����� ������������ ����� ������ - $res.") if !ref($res) && $res>1;
  return $res;
}

sub CMD_show_janitor {
  my $self = shift;
  my $janitor = $self->GetJanitor(@_);

  my $table = Text::FormatTable->new('r | l');
  $table->head('��������','��������');
  $table->rule('=');
  $table->row("ID",$janitor->{id});
  $table->row("��������",$janitor->{name});
  $table->row("������",$janitor->{module});
  $table->row("��������",$janitor->{module_desc});
  $table->row("����������",$janitor->{comment});
  $table->rule('-');
  $self->showTable($table);
}

sub CMD_update_janitors_fake {
  my $self = shift;
  }

1;
