package openbill::Shell::Period;
use strict;
use openbill::Shell;
use openbill::Utils;
use dpl::Context;
use dpl::Db::Table;
use Text::FormatTable;

use openbill::Shell::Base;
use Exporter;
use vars qw(@ISA
            @EXPORT);
@ISA=qw(Exporter
        openbill::Shell::Base);


registerCommands('openbill::Shell::Period',
                 {recharge=>{},
                  charge=>{},
                  close_period=>{},
                  list_periods=>{},
                 });

sub CMD_list {
  my $self = shift;
  my $list = period()->List();
  print "������ �������� (".(scalar @$list)."):\n";
  my $table = Text::FormatTable->new('r | l | l l l ');
  $table->head('id', '������', '������', '����������', '����������');
  $table->rule('=');
  foreach (@$list) {
    $table->row($_->ID(1),,$_->string(),
                $_->IsOpen() ? '��' : '���',
                $_->IsCorrupted() ? '���' : '��',
                $_->Data('comment'));
  }
  $table->rule();
  $self->showTable($table);
}

sub CMD_charge {
  my ($self,$p) = @_;
  my $summa = $self->soap('period','charge');
  print "����� �����ޣ��: ".FormatMoney($summa,'�.')."\n";
}

sub CMD_close_period {
  my ($self,$p) = @_;
  my $summa = $self->soap('period','close');
  print "����� �� ������: ".FormatMoney($summa,'�.')."\n";
}

sub CMD_recharge {
  my ($self,$p) = @_;
  my $summa = $self->soap('period','recharge');
  print "����� �����ޣ��: ".FormatMoney($summa,'�.')."\n";
}



1;
