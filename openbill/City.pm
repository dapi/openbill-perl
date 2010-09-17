package openbill::City;
use strict;
use openbill::Host;
use openbill::Base;
use dpl::Log;
use dpl::Db::Table;
use dpl::Db::Database;
use Error qw(:try);
use Exporter;
use vars qw(@ISA
            $VERSION
            @EXPORT);

@ISA=qw(Exporter
        openbill::Base);

@EXPORT=qw(street);

( $VERSION ) = '$Revision: 1.8 $ ' =~ /\$Revision:\s+([^\s]+)/;


sub street {
  return openbill::Street->instance('street',@_);
}

sub string {
  my $self = shift;
  return $self->Data('name');
}

sub Create  {
  my ($self,$data) = @_;
  $self->checkParams($data,'name');
  return $self->SUPER::Create($data);
}

sub GetBuildingsCount {
  my $self = shift;
  my $a = db()->SelectAndFetchOne('select count(*) as count from building where street_id='.$self->ID());
  return $a->{count};
}

sub GetAddressesCount {
  my $self = shift;
  my $a = db()->SelectAndFetchOne('select count(address_id) as count from address, building where address.building_id=building.building_id and building.street_id='.$self->ID());
  return $a->{count};
}


sub DataFull {
  my ($self,$key) = @_;
  $self->Load() unless $self->isLoaded();
#  $self->{data}->{address}||=$self->GetAddress()->string();
  $self->{data}->{client}||=$self->string();
  $self->{data}->{buildings_count} ||= $self->GetBuildingsCount();
 # $self->{data}->{addresses_count} ||= $self->GetAddressesCount();
  return $key ? $self->{data}->{$key} : $self->{data};
}

sub Delete {
  my ($self) = @_;
  die 'not implemented';
  fatal("Не определён ID для удаления улицы") unless $self->ID();
  my $lock = Locker('street','write',$self->ID());
  if (my $count = $self->GetBuildingsCount()) {
    logger()->error("Немогу удалить улицу - на ней существуют здания ($count)");
    return 2;
  } else {
    $self->{table}->Delete($self->ID());
    return 0;
  }
  return 1;
}

sub List {
  my ($self,$p) = @_;
  if (exists $p->{like}) {
    my $like = $p->{like};
    delete  $p->{like};
    my @a=("name like '%$like%'");
    unshift @a,$p if %$p;
    $p=\@a;
  }
  return $self->SUPER::List($p);
}


1;
