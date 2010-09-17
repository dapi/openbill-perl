package openbill::Server::Building;
use strict;
use dpl::Log;
use openbill::Building;
use openbill::Server::BaseDb;
use dpl::Db::Database;
use dpl::Db::Table;
use Exporter;
use vars qw(@ISA);
@ISA = qw(Exporter
          openbill::Server::BaseDb);


openbill::Server::Base::addSOAPObject(building=>'openbill::Server::Building');

sub METHOD_areas {
  my $self = shift;
  return table('geo_area')->List();
}

sub METHOD_modify_holder {
  my ($self,$p,$id) = @_;
  return table('building_holder')->Modify($p,$id);
}

sub METHOD_create_holder {
  my ($self,$p) = @_;
  return table('building_holder')->Create($p);
}

sub METHOD_holders {
  my $self = shift;
  return table('building_holder')->List();
}

sub METHOD_holder {
  my $self = shift;
  return table('building_holder')->Load(@_);
}


sub METHOD_connections {
  my $self = shift;
  return table('connection_type')->List();
}


sub METHOD_get {
  my ($self,$id) = @_;
  my $b = building()->Load($id) || return undef;
  return $b->DataFull();
}

sub METHOD_list {
  my ($self,$where) = @_;
  my $list = building()->List($where);
  my @l;
  foreach my $d (@$list) {
    push @l, $d->DataFull();
  }
  return [sort {$a->{name} cmp $b->{name}} @l];
}

sub METHOD_ext_list {
  my ($self,$connected_only) = @_;
  my $db = db();
  my $w = $connected_only ? ' and is_connected=1' : '';
  my $sth = $db->Select(qq(select building.*, street.name as street, geo_area.name as area,
                           building_holder.name as holder, connection_type.name as connection_type
                           from building
                           left join street on street.street_id=building.street_id
                           left join geo_area on building.area_id=geo_area.id
                           left join building_holder on building.building_holder_id=building_holder.id
                           left join connection_type on building.connection_type_id=connection_type.id
                           where city_id=1 $w order by street.name, building.number desc));
  #  my $list = table('building')->List();
  my @list;
  while (my $rec = $db->Fetch($sth)) {
#    print STDERR "comment: $rec->{comment}\n";
#     $rec->{street}=table('street')->Load($rec->{street_id});
#     $rec->{area}=table('geo_area')->Load($rec->{area_id})
#       if $rec->{area_id};
#     $rec->{holder}=table('building_holder')->Load($rec->{building_holder_id})
#       if $rec->{building_holder_id};
#     $rec->{connection}=table('connection_type')->Load($rec->{connection_type_id})
#       if $rec->{connection_type_id};
    push @list,$rec;
  }
  return \@list;
}

sub METHOD_find {
  my ($self,$street_id,$number) = @_;
  my $b = building()->
    List({street_id=>$street_id,
          number=>$number});
  return $b->[0]->ID() if $b && @$b;
}

sub METHOD_find_and_get {
  my ($self,$street_id,$number) = @_;
  my $b = building()->
    List({street_id=>$street_id,
          number=>$number});
  return undef unless $b && @$b;
  return building()->Load($b->[0]->ID())->DataFull();
}

sub METHOD_create {
  my ($self,$data) = @_;
  my $res = building()->Create($data) || return undef;
  return $res->ID();
}

sub METHOD_modify {
  my ($self,$id,$data) = @_;
  return building($id)->Modify($data);
}

sub METHOD_delete {
  my ($self,$id) = @_;
  return building($id)->Delete($id);
}



1;
