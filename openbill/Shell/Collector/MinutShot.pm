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
  print "Список снимков (".(scalar @$list)."):\n";

  my $table = Text::FormatTable->new('r| l l l l l l');
  $table->head('id', 'Время съёма', 'Начало', 'Конец', 'Учтено байт', 'Потеряно байт', 'Последний снимок');
  $table->rule('=');
  foreach (@$list) {
    my $s = $_->Data('shottime');
#    die ref $s;
    if ($s) {
      $s=$s->TimeFormat('%c');
    } else {
      $s='открыт';
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
    print "Минутный снимок:\t".$m->ID()."\n";
    my $s = $m->Data('shottime');
    if ($s) {
      print "Время создания:\t".$s->TimeFormat('%c')."\n";
    } else {
      print "Снимок не закрыт!\n";
    }
    my $dfrom = $m->Data('dfrom')->TimeFormat('%D');
    my $dto = $m->Data('dto')->TimeFormat('%D');
    print "Временной период с $dfrom по $dto.\n";
    print "Последний учтённый ulog-снимок:\t".$m->Data('last_ushot_id')."\n";
    print "Учтено байт:\t".$m->Data('bytes')."\n";
    print "Потеряно байт:\t".$m->Data('lost_bytes')."\n";
  } else {
    print "Нет такого снимка.";
  }
}

#sub CMD_delete {
#  my ($self,$p) = @_;
#  my $b = client($p->{id});
#  $b->Delete();
#  print "Удален клиент #".$b->ID();
#  return 1;
#}

1;
