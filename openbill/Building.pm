package openbill::Building;
use strict;
use openbill::Host;
use openbill::Base;
use openbill::Street;
use dpl::Db::Table;
use dpl::Db::Database;
use Exporter;
use vars qw(@ISA
            @EXPORT);

@ISA=qw(Exporter
        openbill::Base);

@EXPORT=qw(building);

sub building {
  return openbill::Building->instance('building',@_);
}

sub GetAddressesCount {
  my $self = shift;
  my $a = db()->SelectAndFetchOne('select count(address_id) as count from address, building where address.building_id=building.building_id and building.building_id='.$self->ID());
  return $a->{count};
}


sub street {
  my $self = shift;
  my $sid =$self->Data('street_id');
  return openbill::Street::street($sid) || $self->fatal("Улица #$sid ненайдена");
}

sub DataFull {
  my ($self,$key) = @_;
  $self->Load() unless $self->isLoaded();
  $self->{data}->{addresses_count} ||= $self->GetAddressesCount();
  $self->{data}->{street} ||= $self->street()->string();
  $self->{data}->{holder} ||=  table('building_holder')->Load($self->Data('building_holder_id'));
  $self->{data}->{connection_type} ||=table('connection_type')->Load($self->Data('connection_type_id'))
       if $self->Data('connection_type_id');
  return $key ? $self->{data}->{$key} : $self->{data};
}

sub string {
  my $self = shift;
  my $d = $self->Data();
  my $str = $self->street()->Data('name').", $d->{number}";
#  $str.=" ($d->{comment})" if $d->{comment};
  return $str;
}

sub Load {
  my ($self,$id,$data) = @_;
  return $self->SUPER::Load($id,$data) unless ref($id)=~/HASH/;
  if (exists $id->{building}) {
    fatal("Неверное значение building: $id->{building}")
      unless $id=~/^(.*)\s*\,\s*(.*)$/;
    my ($street,$number)=($1,$2);
    my $res = db()->
      SelectAndFetchOne(qq(select * from building, street
                           where building.street_id=street.id
                           and name='$street' and number='$number'));
    return undef
      unless $self->SetData($res);
    $self->SetID($res->{$self->{idname}});
  } else {
    return $self->SUPER::Load($id);
  }
}

sub Create  {
  my ($self,$data) = @_;
  $self->checkParams($data,'street_id','number');
  return $self->SUPER::Create($data);
}



1;
