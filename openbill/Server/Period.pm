package openbill::Server::Period;
use strict;
#use openbill::Server::Base;
use openbill::Server::BaseDb;
use openbill::Period;
use Exporter;
use vars qw(@ISA);
@ISA = qw(Exporter
          openbill::Server::BaseDb);

openbill::Server::Base::addSOAPObject(period=>'openbill::Server::Period');

sub METHOD_list {
  my ($class,$module,$from,$to,$is_closed)=@_;
  my $list = openbill::Period::period()->List($module,$from,$to,$is_closed);
  return  [map {$_->DataFull()} @$list];
}

sub METHOD_get {
  my ($class,$date) = @_;
  my $c = openbill::Period::period()->LoadByDate($date);
  return $c ? $c->DataFull() : undef;
}

sub METHOD_create {
  my ($self,$data) = @_;
  my $res = period()->Create($data) || return undef;
  return $res->ID();
}

sub METHOD_delete {
  my ($self,$id) = @_;
  return period($id)->Delete($id);
}

sub METHOD_modify {
  my ($self,$id,$data) = @_;
  return period($id)->Modify($data);
}

sub METHOD_recharge {
  my ($self) = @_;
  my $summa=0;
  my $periods = period()->GetOpenList();
  foreach (@$periods) {
    $summa+=$_->Recharge();
  }
  return $summa;
}

sub METHOD_charge {
  my ($self) = @_;
  my $periods = period()->GetOpenList();
  my $summa;
  foreach (@$periods) {
    $summa+=$_->Charge();
  }
  return $summa;
}

sub METHOD_close {
  my ($self) = @_;
  my $periods = period()->GetOpenList();
  #  die "TODO проверять все ли закрыты subscriber_charge";
  my $summa=0;
  foreach my $p (@$periods) {
    $summa+=$p->Close();
  }
  return $summa;
}


1;
