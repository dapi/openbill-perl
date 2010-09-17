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

# ������� ����� ������������ ���������� � ��������

$LOCKER_WAIT=1
  ; # TODO � ������
$LOCKER_COUNT=100; # TODO � ������

@EXPORT=qw(Locker);

sub Locker  {
  my ($name,$action,$record) = @_;
  fatal("�� ������� ������� ��� ����������") unless $name;
  my %data = (name=>$name,pid=>getpid());
  #  my $self = ;
  if ($action) {
    fatal("�� ��������� �������� � ����������: $name  -> $action")
      unless $action eq 'write' || $action eq 'read' || $action eq 'all';
    $data{action}=$action;
  }
  $data{record}=$record
    if $record;
  foreach my $i (1..$LOCKER_COUNT) {
    return bless {data=>\%data}, 'openbill::Locker' if trylock(\%data);
    sleep $LOCKER_WAIT;
  }
  fatal("�� ������� ��������� ����������: $data{name} -> $data{action} [$data{record}]");
  return undef;
}

# NOTE
# name - ���������� �������
# action - ��� ��������� ��� ������������ ���������. ��� ���� ������� ������ �� �����������
# record - ����� ������ � ����������� �������

# ������ ���� ��������� ����������
#
# 1. period-write-id � ��������� ������ charge-write-client_id (���  ��������� charge-write ��� ��������)
#    ��� ���ޣ�� ����������� ������� � ��������� ��� ������� � charge
#    ������ ����������� ��������������� ���� ������ (������ ������ � Σ� � �������������� charge)
# 2. account-write-id
#    ��� ��������� ����������� ������� (������)
#    ����� ����������� �� ��������
# 3. charge-write-client_id, ����� account-write-id
#    ��� ��������� ������ ��� ��������� �� ���� ���������� ��������
#    ����� ����� ����������� �� �������� ������
# 4. ulog-write-router_id
#    ��� �������� ulog
#    ����� ����������� �� ����������� ����� ������� ������� (���������� ���� �� ������ id  ������������ ��� �����, ����� �� ���������� ���������� ����� ����"
# 5. ulog-write
#    ��� �������� ������ ������� ��� �����������
#    ����� ����������� �� ����������� ����� ������� ������� (���������� ���� �� ������ id  ������������ ��� �����, ����� �� ���������� ���������� ����� ����"

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
      #      my $delta = today()-$a->[0]->{timestamp}; #TODO today ����� ���� ������
      #      my $sec = $delta->Delta(); #TODO
      #      my $sec;
      #     logger()->debug("����������: ������� $data->{name} ������ ��������� $a->[0]->{pid} $sec ������. ���..");
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
