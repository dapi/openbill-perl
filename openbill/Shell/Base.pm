package openbill::Shell::Base;
use strict;
use Text::FormatTable;

sub new {
  my $class = shift;
  return bless {@_}, $class;
}

sub strToHash {
  my ($self,$str,$field) = @_;
  my %h;
  $str=~s/^\s+//;
  $str="$field=$str" unless [split(' ',$str)]->[0]=~/=/;
  return {split(/=|\s+/,$str)};
}

sub strToArr {
  my ($self,$str) = @_;
  return split(/\s+/,$str);
}


sub showTable {
  my ($self,$table) = @_;
  my ($h,$w) = $self->{term}->get_screen_size();
  my $is = $table->render($w);
  print $is;
  return 0;
}



sub soap {
  my ($self,$object,$method)=(shift,shift,shift);
  if ( $self->{soap} eq 'local') {
    openbill::Server::LocalExecute($object,$method,@_);
  } else {
    unshift @_,SOAP::Header
      ->name(session => $self->{session})
        #      ->mustUnderstand(1)
        if $self->{session};
    my $som = $self->{soap}
      -> uri($object)
        ->call($method=>@_);
    if (!$som) {
      print "Нет ответа от сервера!\n";
    } elsif ($som->fault) {
      openbill::SOAP::Error->throw($som);
    } else {
      return $som->result();
    }
    return undef;
  }
}


1;
