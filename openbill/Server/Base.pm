package openbill::Server::Base;
use strict;
use dpl::Db::Database;
use dpl::Context;
use dpl::Error;
use dpl::Db::Table;
use openbill::Manager;
use Error qw(:try);
use Exporter;
use vars qw(@ISA
            $AUTOLOAD
            %SOAP_OBJECTS);
@ISA = qw(Exporter);


#our $AUTOLOAD;

sub AUTOLOAD {
  my $self = shift;
  my $today = dpl::System::setToday();
  my ($class, $method) = ($AUTOLOAD =~ /(.*)::([^:]+)/);
  return undef if $method eq 'DESTROY' || $method eq 'unimport';
  $method=~s/ACCESS_// || fatal("Can't access `$method' field in class $class");
  my $object = lc($class);
  $object=~s/openbill::server::// || fatal("internal error 45");
  $self =  bless {method=>$method,class=>$class,object=>$object}, $self;

  my $time = $today->TimeFormat('%D %X');
  my $res = $self->CheckPermission($object,$method);
  my $manager = context('manager');
  my $m = $manager ? $manager->Data('name') : 'ANON';
  unless ($res) {
    print "$time: [$m] $object->$method(".join(',',map {mydump($_)} @_)."): ACCESS DENIED\n";
    fatal("No access to `$method' in object $object for you");
  }
  print "$time: [$m] $object->$method(".join(',',map {mydump($_)} @_)."): ";
  my @params=@_;
  my $res;
  try {
    $res = $self->Execute($method,@params);
    db()->Commit();
    print "OK\n";
  } catch dpl::Error with {
    my $e = shift;
    db()->Rollback();
    print "ERROR:".$e->stringify()."\n";
    $e->throw();
  } otherwise {
    my $e = shift;
    print "UNKNOWN ERROR: $e\n";
    db()->Rollback();
    dpl::Error->throw(-text=>$e);
  };
  return $res;
}

sub mydump {
  my $a= shift;
  return "'".$a->string()."'" if UNIVERSAL::isa($a,'openbill::DataType::DateObject');
  return join(',',map {"$_=>".(defined $a->{$_}  ? ($a->{$_}=~/^[0-9.,\-]+$/ ? "$a->{$_}" : "'$a->{$_}'") : undef)} keys %$a) if  ref($a)=~/hash/i;
  return join(',',@$a) if  ref($a)=~/array/i;
  return ref($a).$a;
}

sub CheckPermission {
  my ($self,$class,$method) = @_;
  return 1
    if $class eq 'system' && $method eq 'login';
  my $som = context('som');
  my $h = $som->headerof('//session');
  unless ($h) {
    fatal("No session's header");
  }
  my $session = $h->value();
  my $table = table('manager_session')->Load({session_id=>$session})
    || fatal("No such session: $session.");

  setContext('manager',$self->{manager}=manager($table->{manager_id}));

  # TODO
  #  $openbill::Server::MANAGER_SESSIONS{$session}->{last_time}=today();
  return $self->{access}=$self->{manager}->HasAccess($class,$method);
}


sub Execute {
  my ($self,$method) = (shift,shift);
  my $ref = $self->can("METHOD_$method") || fatal("No such method: $method in object $self");
  return &$ref($self,@_);
}

sub addSOAPObject {
  my ($object, $module) = (shift,shift);
  die("Такой объект уже есть: $object")
    if defined $SOAP_OBJECTS{$object};
  $SOAP_OBJECTS{$object}=$module;
}



1;
