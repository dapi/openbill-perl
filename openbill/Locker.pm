package openbill::Locker;
use strict;
use POSIX;
use openbill::Utils;
#use openbill::Base;
#use dpl::Context;
use dpl::Log;
use dpl::Error;
use dpl::Db::Database;
use dpl::Db::Table;
use Error qw(:try);
use Exporter;
use vars qw(@ISA
            $LOCKER_WAIT
            $LOCKER_COUNT
            @EXPORT);

@ISA=qw(Exporter);

# Сколько ждать освобождения блокировки в секундах

$LOCKER_WAIT=1
  ; # TODO с конфиг
$LOCKER_COUNT=100; # TODO с конфиг

@EXPORT=qw(Locker);

sub Locker  {
  my ($name,$action,$record) = @_;
  fatal("Не указана таблица для блокировки") unless $name;
  my %data = (name=>$name,pid=>getpid());
  #  my $self = ;
  if ($action) {
    fatal("Не известное дейстиве в блокировке: $name  -> $action")
      unless $action eq 'write' || $action eq 'read' || $action eq 'all';
    $data{action}=$action;
  }
  $data{record}=$record
    if $record;
  foreach my $i (1..$LOCKER_COUNT) {
    return bless {data=>\%data}, 'openbill::Locker' if trylock(\%data);
    sleep $LOCKER_WAIT;
  }
  fatal("Не удалось поставить блокировку: $data{name} -> $data{action} [$data{record}]");
  return undef;
}

# NOTE
# name - блокиуемая таблица
# action - что блокируем для параллельных процессов. Для себя никогда ничего не блокируется
# record - номер записи в блокируемой таблице

# СПИСОК ВСЕХ ВОЗМОЖНЫХ БЛОКИРОВОК
#
# 1. period-write-id и постоянно менять charge-write-client_id (или  установть charge-write для скорости)
#    При расчёте конкретного периода и изменении его записей в charge
#    Нельзя параллельно перерасчитывать этот период (менять записи в нём и соответсвующих charge)
# 2. account-write-id
#    При изменении клиентского баланса (оплате)
#    Чтобы параллельно не поменяли
# 3. charge-write-client_id, затем account-write-id
#    При изменении тарифа или активации во всех изменяемых периодах
#    Чтобы никто параллельно не посчитал нитого
# 4. ulog-write-router_id
#    При загрузке ulog
#    Чтобы параллельно не загружались файлы этогоже роутера (правильнее было бы вместо id  использовать имя файла, чтобы не загружался парллельно тотже файл"
# 5. ulog-write
#    При удалении старых записей или неисправных
#    Чтобы параллельно не загружались файлы этогоже роутера (правильнее было бы вместо id  использовать имя файла, чтобы не загружался парллельно тотже файл"

sub trylock {
  my $data = shift;
  return 1;
  my $db = db();
  return try {
    $db->LockTables('write',qw(locker));
    #    die 1;
    my $a=table('locker')->List({name=>$data->{name}});
    if (@$a) {
      if ($data->{record}) {

      }
      #      my $delta = today()-$a->[0]->{timestamp}; #TODO today может быть старым
      #      my $sec = $delta->Delta(); #TODO
      #      my $sec;
      #     logger()->debug("БЛОКИРОВКА: Таблица $data->{name} занята процессом $a->[0]->{pid} $sec секунд. Жду..");
      return undef;
    }
#    table('locker')->Create($data);
  } otherwise {
    $_[0]->throw();
  } finally {
    $db->UnlockTables();
  };
  return undef;
}

sub Unlock {
  my $self = shift;
  return undef unless $self->{data};
#  table('locker')->Delete($self->{data});
  delete $self->{data};
}

sub DESTROY {
  my $self = shift;
#  print "DESTROY: $self, $self->{data}\n";
  $self->Unlock();
}


1;
