package openbill::Shell::ReadLine;
use strict;
use openbill::Shell;
use dpl::Context;
use dpl::Db::Table;
use Text::Shellwords;

sub new {
  my $class = shift;
  return bless {@_}, $class;
}

sub Attribs {
  return {};
}

#sub get_screen_size { return (25,120); }
sub get_screen_size { return (25,200); }

sub history_tokenize {
  my ($self,$line) = @_;
  # TODO Сделать чтобы ;, &&, || были отдельным словом, если они прикрепленны сзади
  return shellwords($line);
}

1;
