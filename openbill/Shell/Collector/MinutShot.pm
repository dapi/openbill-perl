package openbill::Shell::Collector::MinutShot;
use strict;
use openbill::Shell;
use openbill::Host;
use openbill::Collector::MinutShot;
use dpl::Context;
use dpl::Db::Table;

use openbill::Shell::Base;
use Exporter;
use vars qw(@ISA
            @EXPORT);
@ISA=qw(Exporter
        openbill::Shell::Base);


registerCommands('openbill::Shell::Collector::MinutShot',
                 {
                  'show minut_shot'=>{id=>1,
                                      #                                _complete=>{id=>'openbill::Shell::Collector::MinutShot->Complete_shot'}
                                     },
                  # 'delete shots'=>{_method=>'delete_shots',
                  # _params=>{older_days=>1}},
                  'list minut_shots'=>{},
                 });


sub Complete_shot {
  my ($self,$param)=@_;
  my ($k,$v)=%$param;
  if ($k eq 'id') {
    my $list = minutshot()->List();
    my @a;
    foreach (@$list) {
      #      my $s = '#'.$_->ID();
      my $s = $_->ID();
      push @a,$s if $s=~/^$v/;
      #      $s = escape($_->Data('name'));
      #      push @a,$s if $s=~/^$v/;
    }
    return \@a;
  }
}

sub CMD_list {
  my $self = shift;

  my $list = minutshot()->List();
  print "������ ������� (".(scalar @$list)."):\n";

  my $table = Text::FormatTable->new('r| l l l l l l');
  $table->head('id', '����� �ߣ��', '������', '�����', '������ ����', '�������� ����', '��������� ������');
  $table->rule('=');
  foreach (@$list) {
    my $s = $_->Data('shottime');
#    die ref $s;
    if ($s) {
      $s=$s->TimeFormat('%c');
    } else {
      $s='������';
    }
    $table->row($_->ID(), $s ,
                $_->Data('dfrom')->TimeFormat('%D'), $_->Data('dto')->TimeFormat('%D'),
                $_->Data('bytes'), $_->Data('lost_bytes'),
                $_->Data('last_ushot_id')
               );
 #   $table->rule();
  }
  $self->showTable($table);
}


sub CMD_show {
  my ($self,$p) = @_;
  my $m = minutshot($p->{id});
  if ($m) {
    print "�������� ������:\t".$m->ID()."\n";
    my $s = $m->Data('shottime');
    if ($s) {
      print "����� ��������:\t".$s->TimeFormat('%c')."\n";
    } else {
      print "������ �� ������!\n";
    }
    my $dfrom = $m->Data('dfrom')->TimeFormat('%D');
    my $dto = $m->Data('dto')->TimeFormat('%D');
    print "��������� ������ � $dfrom �� $dto.\n";
    print "��������� ��ԣ���� ulog-������:\t".$m->Data('last_ushot_id')."\n";
    print "������ ����:\t".$m->Data('bytes')."\n";
    print "�������� ����:\t".$m->Data('lost_bytes')."\n";
  } else {
    print "��� ������ ������.";
  }
}

#sub CMD_delete {
#  my ($self,$p) = @_;
#  my $b = client($p->{id});
#  $b->Delete();
#  print "������ ������ #".$b->ID();
#  return 1;
#}

1;
