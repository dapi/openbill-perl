package openbill::Shell;
use strict;
use openbill::SOAP::Error;
use openbill::Utils;
use Number::Format qw(:subs);
use SOAP::Lite;
use openbill::SOAP::Serializer;
use openbill::SOAP::Deserializer;
use Data::Dumper;
use openbill::Shell::ReadLine;
use dpl::Error;
use dpl::Log;
use dpl::Context;
use Error qw(:try);
use dpl::Error::Interrupt;
use Term::ReadLine;
use Term::ReadLine::Gnu;
use openbill::Shell::Base;
use Exporter;
use vars qw(@ISA
            $suppress_print
            @EXPORT
            $VERSION
            %COMMANDS);

( $VERSION ) = '$Revision: 1.21 $ ' =~ /\$Revision:\s+([^\s]+)/;

@ISA=qw(Exporter
        openbill::Shell::Base);
$suppress_print=0;

my $history_file = glob('~/.openbill_history');

@EXPORT=qw(registerCommands
           escape);

registerCommands('',
                 {
                  quit=>{},
                  exit=>{},
                  call=>{},
                  help=>{}});

sub registerCommands {
  my ($module,$hr) = @_;
  foreach my $cmd (keys %$hr) {
    die "Такая команда ($cmd) уже есть" if exists $COMMANDS{$cmd};
    $hr->{$cmd}->{module}||=$module;
    $COMMANDS{$cmd}=$hr->{$cmd};
  }
}

sub escape {
  my $str = shift;
  $str=~s/ /\\ /g;
  return $str;
}

sub Question {
  my ($self,$name,$a,$params) = @_;
  $params={} unless  $params;
  my $attribs = $self->{term}->Attribs();
  # my @history = $self->{term}->GetHistory();
  $self->{term}->clear_history();
  return try {
    #    $attribs->{catch_signals}=1;
    #   local $SIG{INT} = sub { throw dpl::Error::Interrupt(); };
    my %h;
    foreach my $p (@$a) {
      $self->quest($name,$p,\%h,$params->{$p->{key}},$params);
    }
    return \%h;
  } catch dpl::Error::Interrupt with {
    my $e  = shift;
    return undef;
  } finally {
    $self->{term}->clear_history();
    $self->{term}->ReadHistory($history_file);
    $self->{term}->{line_buffer}=undef;
    #    $attribs->{catch_signals}=0;
    ClearInterrupted();
    #    $SIG{INT}='IGNORE';
  };
}

sub AskPassword {
  my ($self,$login) = @_;
  my $attribs = $self->{term}->Attribs;
  my $save = $attribs->{redisplay_function};
  $attribs->{redisplay_function} = $attribs->{shadow_redisplay};
  my $pwd=$self->{term}->readline("Password for $login:");
  $attribs->{redisplay_function} = $save;
  return $pwd;
}

sub quest {
  my ($self,$name,$p,$h,$default,$params)=@_;
  return if $p->{request} && !$p->{request}->($h);
  my $value;
  my $repeat=0;
  $p->{start}->($h,$p,$default) if $p->{start};
  do {
    my $prev=$p->{pre} ? $p->{pre}->($h,$p,$default,$params) : $default;
    $prev=$h->{$p->{key}} unless defined $prev;
    #    print "ob: $p->{obligated}\n";
    $p->{type}='set' if !$p->{type} && $p->{set};
#    die join(',',%$p) if $p->{key} eq 'payment_method_id';
    my $z = $p->{obligated} ? '' :  ' *';
    $self->setQuestHistory($name,$p);
    $z="$z (YYYY.MM.DD)" if $p->{type} eq 'date';
    $self->printPreline($p);
    $value = $self->{term}->readline("$p->{name}$z: ", $prev);
    if ($p->{obligated} && $value eq  '') {
      print "Параметер обязателен, повторите ввод\n";
      $repeat=1;
    } else {
      ($h->{$p->{key}},$repeat)=$self->setValueByType($p,$value);
    }
    if (!$repeat && $p->{post} && !$p->{post}->($h,$p,$default,$params)) {
      print "Неверное значение параметра\n";
      $repeat=1;
    }
    $self->{term}->append_history(1,"$history_file.$name.$p->{key}")
      unless $repeat;
  } while ($repeat);
  $self->{term}->WriteHistory("$history_file.$name.$p->{key}");
  $self->{term}->clear_history();
}

sub printPreline {
  my ($self,$p) = @_;
  return unless $p->{set};
  my $i=0;
  print "\nВыберите вариант:\n";
  my ($h,$w) = $self->{term}->get_screen_size();
  my $length;
  foreach (@{$p->{set}}) {
    my $l=length($_);
    $length=$l if $length<$l;
  }
  $length+=6;
  my $col=$w/$length;
  $col=~s/[,.].*//;
  my $c=1;
  foreach (@{$p->{set}}) {
    $i++;
    showColumn($i,$_->{name},$length);
    if (++$c>$col) {
      print "\n";
      $c=1;
    }
  }
  print "\n" if $c>1;
  print "\n";
}

sub showColumn {
  my ($num,$str,$length)=@_;
  $num=" $num" if $num<10;
  $num=" $num" if $num<100;
  print " $num) $str; ";
}

sub setValueByType {
  my ($self,$p,$value) = @_;
  return ($value,0) unless $p->{type};
  if ($p->{type} eq 'boolean') {
    if ($value=~/да/i || $value=~/yes/i) {
      return (1,0);
    } elsif ($value=~/нет/i || $value=~/no/i) {
      return (0,0);
    } else {
      print "Неизвестное значение. Должно быть 'да' или 'нет'\n";
      return (undef,1);
    }
  } elsif ($p->{type} eq 'date') {
    return undef unless $value;
    $value = ParseDate($value) || return (undef,1);
    return ($value,0);
  } elsif ($p->{type} eq 'set') {
    $value-=1;
    if ($value<0 || $value>=@{$p->{set}}) {
       print "Неверное значение, повторите ввод!\n";
      return (undef,1);
    }
    return ($p->{set}->[$value]->{key},0);
  } else {
    die 'неизвестный тип';
  }
}

sub setQuestHistory {
  my ($self,$name,$p) = @_;
  return $self->{term}->ReadHistory("$history_file.$name.$p->{key}");
}

sub complete {
  my ($self, $text, $line, $start, $end) = @_;
  my $attribs = $self->{term}->Attribs;
  $attribs->{completion_append_character} = ' ';
  #  $attribs->{completion_word}=$l;
  return $self->{term}->completion_matches($text,
                                           $attribs->{list_completion_function});
}

sub init {
  my ($self) = @_;
  try {
    $self->{term} =  new Term::ReadLine 'OpenBill';
    unless ($self->{term}->ReadLine eq 'Term::ReadLine::Gnu') {
      fatal("Package name should be \`Term::ReadLine::Gnu\', but it is \`",
            $self->{term}->ReadLine, "\'\n");
    }
    $self->{term}->ornaments(0);
    #  $self->{term}->bind_key(ord "c", 'self-insert');
    #  $self->{term}->invoking_keyseqs('abort', 'emacs-ctlx');
    # TODO
    # history file не появляется сам собой - его надо touch-ить
    #  $self->{history}=$self->loadHistory();
    my $attribs = $self->{term}->Attribs;
    #    $attribs->{catch_sigwinch}=1;
    $attribs->{completion_word}=[keys %COMMANDS];
    #  undef $attribs->{completion_display_matches_hook};
    $attribs->{completion_append_character} = ' ';
    $attribs->{completion_entry_function} = undef;
    $attribs->{attempted_completion_function}= sub {$self->complete(@_)};
  } otherwise {
    $self->{term} = openbill::Shell::ReadLine->new();
    #    logger()->debug("Инициализирован openbill::Shell::ReadLine");
  };
  return 1;
}

sub Connect {
  my ($self,$proxy,$login,$password) = @_;
  print "Connect to $login\@$proxy" unless $suppress_print;
  if ($proxy eq 'local') {
    openbill::Server::InitLocalConnection(1);
    $self->{soap}='local';
  } else {
    my $soap = SOAP::Lite
      -> new() -> proxy($proxy)
        -> serializer(openbill::SOAP::Serializer->new())
          -> deserializer(openbill::SOAP::Deserializer->new())

            #        -> encoding('koi8-r')
            -> on_fault( sub {
                           my $soap = shift;
                           my $res = shift;
                           if (ref($res)) {
                             openbill::SOAP::Error->throw($res);
                           } else {
                             #  print "$res\n";
                             warn(join " ", "TRANSPORT ERROR:", $soap->transport->status, "\n");
                             openbill::SOAP::Error->throw($soap->transport->status);
                           }
                           return undef;
                         }
                       );
    $self->{soap}=$soap;
  }
  my $result = $self->soap('system', 'login', {login=>"$login",
                                               password=>"$password",
                                               soft=>'openbill shell',
                                               version=>$VERSION});
  $self->{session}=$result->{session};

  # Былопочему-то закоментировано
  #  setContext('manager',$self->{manager}=$result->{manager});

  print " -  $result->{system} ($result->{soft} v$result->{version}).\n\n"
     unless $suppress_print;
}

sub Run {
  my ($self) = @_;
  $self->{term}->clear_history();
  $self->{term}->WriteHistory($history_file)
    unless $self->{term}->ReadHistory($history_file);
  #$SIG{INT} = 'IGNORE';         # ignore Control-C
  while ( defined ($_ = $self->{term}->readline('> ')) ) {
    s/^\s+//g; s/\s+$//g;
    next unless /\S/;
    $self->{term}->addhistory($_);
    $self->{term}->append_history(1,$history_file);
    $self->ExecuteLine($_);
  }
}

sub ExecuteLine {
  my ($self,$line) = @_;
  $line=~s/^\s+//;  $line=~s/\s+$//;
  my (@cmd,$res,$prev);
  return try {
    #    foreach ($self->{term}->history_tokenize($line)) {
    #      if ($_ eq '&&' || $_ eq '||' || $_ eq ';') {
    #        die("Синтаксическая ошибка $_") unless @cmd;
    #        my $last=$res;
    #        $res=$self->ExecuteCommand(@cmd);
    #        return 0 if $_ eq '&&' && !$res;
    #        return 0 if $prev eq '&&' && !($res && $last);
    #        return 0 if $prev eq '||' && !($res || $last);
    #        $prev=$_; @cmd=();
    #      } elsif ($_ eq '|' || $_  eq '&') {
    #        die("Такая команда '$_' неподдерживаертся");
    #      } else {
    #        push @cmd,$_;
    #      }
    #    }
    #    return $res unless @cmd;
    my ($cmd,$params)=($line=~/^(\w+)\s*(.*)$/);
    return $self->ExecuteCommand($cmd,$params);
    #     $res=$self->ExecuteCommand($cmd,$params);
    #     return $prev eq '&&' && !$res ? 0 : $res;
  } catch openbill::SOAP::Error with {
    my $err = shift;
    if ($suppress_print) {
      print "ERROR SOAP\n";
    } else {
      print "SOAP ERROR: ".$err->stringify();
    }
    return undef;
  } catch Error with {
    my $err = shift;
    print "ERROR(1) ".$err->stringify();
    return undef;
  } except {
    my $e = shift;
    #openbill::SOAP::Error->throw($som);
    #    $som->fault
    if ($suppress_print) {
      print "ERROR aga $@\n";
    } else {
      print ref($e)."\n";
    }
    die "Some strange error $e '$@'";
  } otherwise {
    my $e  = shift;
    if ($suppress_print) {
      print "ERROR aga2 $@\n";
    };
    die "Some strange error $e '$@'";
  } finally {
    print "\n" unless $suppress_print;
    return undef;
  };
}

sub CMD_quit {
  my ($self,$params)=@_;
  print "Прощай..\n";
  exit 1;
}

sub CMD_exit {
  my $self = shift;
  return $self->CMD_quit(@_);
}

sub CMD_call {
  my $self = shift;
  print Dumper($self->soap($self->strToArr(@_)));
}

sub CMD_help {
  my ($self,$params)=@_;
  print "Список команд:\n";
  foreach (sort keys %COMMANDS) {
    print "$_\n";
  }
}

sub ExecuteCommand {
  my ($self,$command) = (shift,shift);
  die("Нет такой команды: $command")
    unless exists $COMMANDS{$command};
  my $cmd = $COMMANDS{$command};
  $self->execute($cmd->{module},"CMD_$command",@_);
}

sub execute {
  my ($self,$module,$method)=(shift,shift,shift);
  my $object = $module ? $module->new(term=>$self->{term},
                                      session=>$self->{session},
                                      shell=>$self,
                                      soap=>$self->{soap}) : $self;
  my $ref = $object->can($method) ||
    fatal("Нет заявленного метода $method в модуле $module");
  return &$ref($object,@_);
}

1;
