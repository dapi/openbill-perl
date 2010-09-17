package openbill::Collector::DayShot;
use strict;
use openbill::Host;
use openbill::Base;
use openbill::Locker;
use openbill::System;
use openbill::Utils;
use openbill::Collector::MinutShot;
use dpl::Context;
use dpl::System;
use dpl::Log;
use dpl::Db::Table;
use dpl::Db::Database;
use dpl::Db::Filter;
use Error qw(:try);
use Exporter;
use vars qw(@ISA
            @EXPORT);

@ISA=qw(Exporter
        openbill::Base);

@EXPORT=qw(dayshot);

sub dayshot {
  return openbill::Collector::DayShot->instance('day_shot',@_);
}

sub GetMinShotFromMinutShot {
  my ($self,$shot_id) = @_;
  return db()->SelectAndFetchOne("select min(id) as id from day_shot where to_mshot_id>=$shot_id")->{id};
}

sub GetMinShotSinceDate {
  my ($self,$date) = @_;
  $date=filter('date')->ToSQL($date);
  my $res = db()->SelectAndFetchOne("select min(id) as id from day_shot where dfrom>='$date'");
  return $res ? $res->{id} : undef;
}



sub string {
  my $self = shift;
  return "'".$self->Data('name')."',  '".$self->Data('comment')."'";
}

sub GetLastProcessedMshotID  {
  my $self = shift;
  my $h = db()->SelectAndFetchOne('select max(to_mshot_id) as last from day_shot');
  return $h->{last};
}

sub CheckDatabase {
  my $self = shift;
  my $db = db();
  my $count = $db->SelectAndFetchOne('select count(*) as count, max(id) as max from day_shot');
  print "Проверка дневной базы ($count->{count}/$count->{max})\n" if setting('terminal');
  my $m_sth = $db->Select('select * from day_shot order by id desc');
  my $i;
  while (my $a=$db->Fetch($m_sth)) {
    my $res = $db->SelectAndFetchOne("select sum(bytes) as bytes, count(*) as count from minut_shot where id>$a->{from_mshot_id} and id<=$a->{to_mshot_id}");
    $i++;
    print "\r$i" if setting('terminal');
    unless ($res->{bytes}==$a->{bytes}) {
      print "\nСнимок $a->{id} ($res->{count}) ($a->{dfrom} - $a->{dto}/$a->{shottime}, $a->{from_mshot_id} - $a->{to_mshot_id}) имеет неверный трафик - $a->{bytes} <> $res->{bytes}\n";
    }
  }
  print "\n";
  $m_sth->finish();
  return 1;
}


sub GetLastID {
  my ($self,$period) = @_;
  my $start = filter('date')->ToSQL($period->Data('start'));
  my $end   = filter('date')->ToSQL($period->Data('end'));
  my $h = db()->SelectAndFetchOne("select min(id) as id from day_shot where shottime is null and dto>='$start' and dfrom<='$end'");
  my $w = " and id<$h->{id}" if  $h->{id};
  my $h = db()->SelectAndFetchOne("select max(id) as id from day_shot where shottime is not null and dto>='$start' and dfrom<='$end' $w");
  return $h ? $h->{id} : undef;
}

#TODO Сделать чтобы from_mshot_id отображал не ппоследний id, а реально первы id в этом снимке
# тоже для minusthot

sub Create {
  my ($self,$max) = @_;
  # TODO max
  my $from_mshot_id=$self->GetLastProcessedMshotID() || -1;
  my ($to_mshot_id,$count)=minutshot()->GetShotsInfo($from_mshot_id);
  return undef unless $count;
  if ($max && $count>$max) {
    print "Ограничение дневного трафика ($max) $to_mshot_id" if setting('terminal');
    $to_mshot_id=$from_mshot_id+$max;
  }

  $self = $self->SUPER::Create({shottime=>undef,
                                from_mshot_id=>$from_mshot_id,
                                to_mshot_id=>$to_mshot_id});
  return undef unless $self;
  $self->{is_open}=1;
  return $self;
}

sub Close {
  my ($self,$bytes) = @_;
  my $h = db()->SelectAndFetchOne("select min(date) as dfrom, max(date) as dto, sum(bytes) as bytes from day_traffic where shot_id=$self->{id}");
  db()->
    Query('update day_shot set shottime=now(),bytes=?,dfrom=?,dto=? where id=?',
          ,$h->{bytes},$h->{dfrom},$h->{dto},$self->ID());

  #  minutshot()->DeleteOldLogs($self->Data('from_mshot_id'),today()-7*24*60*60); # TODO days
  $self->{is_open}=0;
}

sub DeleteIfBroken {
  my $self = shift;
  if ($self->{is_open}) {
    db()->Query("delete day_traffic from day_traffic, day_shot where day_shot.id=day_traffic.shot_id and day_shot.id=".$self->ID());
    db()->Query("delete day_shot from day_shot where id=".$self->ID());
  }
}

sub DeleteBroken {
  my ($self)=@_;
  db()->Query('delete day_traffic from day_traffic, day_shot where day_shot.id=day_traffic.shot_id and shottime is null');
  db()->Query('delete day_shot from day_shot where shottime is null');
}

sub UpdateTraffic {
  my ($self,$max) = @_;
  my $db = db();
  my $dayshot = dayshot()->Create($max) || return undef;
  try {
    my ($from,$to)=($dayshot->Data('from_mshot_id'),$dayshot->Data('to_mshot_id'));
    print "Дневной трафик ($from-$to): " if setting('terminal');
    db()->Query(qq(insert into day_traffic
                   select ?, date, router_id, ip, class, sum(bytes), client_id from minut_traffic
                   where shot_id>? and shot_id<=? group by date, router_id, ip, class, client_id),
                $dayshot->ID(),$from,$to);
    $dayshot->Close();
    print " Готово\n"  if setting('terminal');
  } otherwise {
    $dayshot->DeleteIfBroken();
    my $e = shift;
    $e->throw();
  };
}

=pod

  select sum(bytes) from traflog where shot_id>1153968 and shot_id<1154968;

  select log_shot.router_id, @t:=from_unixtime(logtime-mod(logtime,300)),
  @t, @t, dst_ip, src_ip,
  (49320 = src_ip >> 16 or 2660 = src_ip >> 16 or src_ip=169090605 or src_ip=169090607 or src_ip=3647713723 or src_ip=3647713543 or src_ip=3647713716 or src_ip=3647713732 or src_ip=169090608 or src_ip=169090606 or src_ip=3647713609 or src_ip=174326282 or src_ip=169090569 or src_ip=169090576 or src_ip=3647713548 or src_ip=169090580 or src_ip=3577432786 or src_ip=169090566 or src_ip=169090587 or src_ip=169090590 or src_ip=169090597 or src_ip=169090619 or src_ip=169090603 or src_ip=169093129 or src_ip=169090575 or src_ip=169093138 or src_ip=169093140 or src_ip=169093141 or src_ip=169093143 or src_ip=174327324 or src_ip=169093144 or src_ip=169090618),
  sum(traflog.bytes), client_id
  from log_shot, traflog left join host on host.ip=traflog.dst_ip >> host.bits and host.router_id=log_shot.router_id where traflog.shot_id=log_shot.shot_id
  and log_shot.shot_id>1153968 and log_shot.shot_id<=1154968
  and log_shot.router_id=1 and (dst_ip=3577432806 or 680962 = dst_ip >> 8 or dst_ip=169090605 or dst_ip=174326273)
  group by log_shot.router_id, from_unixtime(logtime-mod(logtime,300)), dst_ip, src_ip

=cut


1;
