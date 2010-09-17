package openbill::SOAP::Server;
use strict;
use vars qw(@ISA);
use SOAP::Transport::HTTP;
@ISA = qw(SOAP::Transport::HTTP::Daemon);

#use SOAP::Transport::TCP;
#@ISA = qw(SOAP::Transport::TCP::Server);

sub find_target {
  my $self = shift;

  my($class, $method_uri, $method_name) = $self->SUPER::find_target(@_);
  $method_name="ACCESS_$method_name";
  return ($class, $method_uri, $method_name);

}

sub handle {
  my $self = shift->new;

 CLIENT:
  while (my $c = $self->accept) {
    my $pid = fork();

    # We are going to close the new connection on one of two conditions
    #  1. The fork failed ($pid is undefined)
    #  2. We are the parent ($pid != 0)
    unless( defined $pid && $pid == 0 ) {
      $c->close;
      next;
    }
    # From this point on, we are the child.

    $self->close;               # Close the listening socket (always done in children)

    # Handle requests as they come in
    while (my $r = $c->get_request) {
      $self->request($r);
      $self->SOAP::Transport::HTTP::Server::handle;
      $c->send_response($self->response);
    }
    $c->close;
    return;
  }
}

sub handle_fake {
  my $self = shift->new;
 CLIENT:
  while (my $c = $self->accept) {
    my $first = 1;
    while (my $r = $c->get_request) {
      $self->request($r);
      $self->SOAP::Transport::HTTP::Server::handle;
      if ($first && fork) { $first=0; $c->close; next CLIENT }
      $c->send_response($self->response)
    }
    $c->close;
    undef $c;
    return;
  }
}


1;
