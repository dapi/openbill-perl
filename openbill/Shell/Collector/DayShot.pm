package openbill::Shell::Collector::DayShot;
use strict;
use openbill::Shell;
use openbill::Host;
use dpl::Context;
use dpl::Db::Table;
use openbill::Collector::DayShot;
use openbill::Shell::Base;
use Exporter;
use vars qw(@ISA
            @EXPORT);
@ISA=qw(Exporter
        openbill::Shell::Base);


registerCommands('openbill::Shell::Collector::DayShot',
                 {
                  delete_shots=>{}
                 });

sub complete {
  my ($self,$method,$param,$value)=@_;
  my @variants;
  if ($param eq 'id') {
    my $list = shot()->List();
    foreach (@$list) {
      push @variants,$_->{shot_id};
    }
    #  } elsif ($param eq 'shot') {
    #    my $shots = shot()->List();
    #    foreach (@$shots) {
    #      push @variants,'#'.$_->{shot_id};
    #      push @variants,$_->{name};
    #    }
  }
  return \@variants;
}


sub CMD_list {
  my $self = shift;
  my $list = table('shot')->List();
   print "Снимки (".(scalar @$list)."):\n";
  foreach (@$list) {
    print "[$_->{shot_id}]\t'$_->{name}' '$_->{comment}'";
  }
}

sub CMD_create {
  my ($self,$p) = @_;
  my $s = shot();
  return print "Невозможно создать улицу. Возможно такая уже есть."
    unless defined $s->Create($p);
  print "Создана улица #".$s->ID();
}

sub CMD_show {
  my ($self,$p) = @_;
  my $s = shot($p->{id}) ||
    print "Нет такой улицы.";
  print "Улица [".$s->ID()."]\t'".$s->string();
}


sub CMD_delete {
  my ($self,$p) = @_;
  my $b = shot($p->{id});
  $b->Delete();
  print "Удалена улица #".$b->ID();
  return 1;
}

sub CMD_delete_shots {
  my ($self,$p) = @_;
  $p  = $self->strToHash($p);
  if ($p->{older_days}>14) {
    dayshot()->DeleteOld($p->{older_days});
  } else {
    print "older_days должен быть более 14 дней\n";
  }
  return 1;
}



1;
