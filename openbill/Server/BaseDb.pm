package openbill::Server::BaseDb;
use strict;
use dpl::Db::Database;
use openbill::Server::Base;
use Exporter;
use vars qw(@ISA);
@ISA = qw(Exporter
          openbill::Server::Base);

sub Execute {
  my ($self,$code,@p) = @_;
  return try {
    my $res=$self->SUPER::Execute($code,@p);
    db()->Commit();
    return $res;
  } otherwise {
    my $e = shift;
    db()->Rollback();
    $e->throw();
  };
}

1;
