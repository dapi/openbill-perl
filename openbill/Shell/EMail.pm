package openbill::Shell::EMail;
use strict;
use openbill::Shell;
use openbill::Utils;
use dpl::Context;
use dpl::Error;
use openbill::Shell::Base;
use Date::Parse;
use Exporter;
use vars qw(@ISA
            @EXPORT);

@ISA=qw(Exporter
        openbill::Shell::Base);

registerCommands('openbill::Shell::EMail',
                 {
                  'list_emails'=>{},
                  'add_email'=>{},
                  'modify_email'=>{},
                 });


sub CMD_list_emails {
  my ($self,$p) = @_;
  $p  = $self->strToHash($p);
#  if ($p->{no_work_since}) {
#    $p->{no_work_since}=~s/_/ /g;
#    $p->{no_work_since} = ParseDateTime($p->{no_work_since}) || fatal("Неверно указано время");
#    print "Список хостов, неработающих с $p->{no_work_since}\n";
#  }
  my $list = $self->soap('email','list',$p,1);
  my $table;
  $table = Text::FormatTable->new('l | l | l | l ');
  $table->head('EMAIL', 'Клиент', "Время присоединения", 'Коментарий');
  $table->rule('=');
  foreach my $h (@$list) {
    my $client = $h->{client_id} ? "[$h->{client_id}] $h->{client}\n" : "БЕЗХОЗНЫЙ\n";
    $table->row($h->{email}, $client, $h->{createtime},
                $h->{comment} );
  }
  $self->showTable($table);
}

sub questemail {
  my ($self,$p) = @_;
  return $self->{shell}->
    Question('email',[
                      {key=>'client_id',name=>'Абонент',obligated=>1,
                       post=>sub {
                         my $params=shift;
                         my $c = $self->soap('client','find',$params->{client_id});
                         if (ref($c)) {
                           #                             $params->{client}=$c;
                           print "Выбран клиент: '$c->{client}'\n";
                           return $params->{client_id}=$c->{client_id};
                         } elsif ($c) {
                           print "Таких абонентов более одного - $c.\n";
                         } else {
                           print "Такой клиент не найден.\n";
                         }
                         return undef;
                       }},
                      {key=>'email',name=>'E-Mail',obligated=>1},
                      {key=>'comment',name=>'Коментарий'}
                    ],$p);
}

sub CMD_add_email {
  my ($self,$p) = @_;
  my @p  = $self->strToArr($p);
  my %h;
  $h{client_id}=$p[0];
  $h{email}=$p[1];
  print "Создание email-а:\n";
  my $r;
  if (@p<2) {
    $r=$self->questemail(\%h) || return undef;
  } else {
    print "Клиент: $h{client_id}, email: $h{email}\n";
    $r=\%h;
  }
  my $id = $self->soap('email','create',$r);
  unless ($id) {
    print "Ошибка создания email-а.";
    return 1;
  }
  print "Создан email\n";
}

sub CMD_modify_email {
  my ($self,$id,$p) = @_;
  my $p  = $self->strToHash($p);
  my $data = $self->soap('email','get',$id);
  unless ($data) {
    print "Нет такого хоста\n";
    return 1;
  }
  foreach (keys %$data) {
    $data->{$_}=$p->{$_}
      if exists $p->{$_};
  }
  print "Изменение хоста:\n";
  $p=$self->questemail($data) || return undef;
  if ($self->soap('email','modify',$id,$p)) {
    print "OK\n"; return 0;
  } else {
    print "Ошибка\n";  return 1;
  }
}


1;
