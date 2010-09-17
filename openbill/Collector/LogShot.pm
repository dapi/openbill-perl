package openbill::Collector::LogShot;
use strict;
use openbill::Host;
use openbill::Base;
use openbill::System;
use openbill::Utils;
use openbill::Collector::MinutShot;
use dpl::Context;
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

@EXPORT=qw(logshot);

sub logshot {
  return openbill::Collector::LogShot->instance('log_shot',@_);
}

sub string {
  my $self = shift;
  return "'".$self->Data('name')."',  '".$self->Data('comment')."'";
}

sub GetMinShotSinceDate {
  my ($self,$date) = @_;
  $date=filter('date')->ToSQL($date);
  return db()->SelectAndFetchOne("select min(shot_id) as shot_id, min(filetime) as filetime from log_shot where minlogtime>='$date' or maxlogtime>='$date' or filetime>='$date'");
}

sub CheckDatabase {
  my $self = shift;
  my $db = db();
  my $count = $db->SelectAndFetchOne('select count(*) as count, max(shot_id) as max from log_shot');
  print "Проверка снимков базы ($count->{count}/$count->{max})\n" if setting('terminal');
  my $m_sth = $db->Select('select * from log_shot order by shot_id desc');
  my $i;
  while (my $a=$db->Fetch($m_sth)) {
    my $res = $db->SelectAndFetchOne("select sum(bytes) as bytes from traflog where shot_id=$a->{shot_id}");
    $i++;
    print "\r$i [$a->{router_id}] $a->{filetime}" if setting('terminal');
    unless ($res->{bytes}==$a->{bytes}) {
      print "\nСнимок $a->{shot_id} имеет неверный трафик - $a->{bytes} <> $res->{bytes}\n";
    }
  }
  $m_sth->finish();
  print "\n";
  return 1;
}

sub List {
  my ($self,$p) = @_;
  my $start=$p->{start}+0;
  my $limit=$p->{limit} || 20;
  #  db()
  my @cw;
  push @cw,"shot_id<=$p->{from_id}" if $p->{from_id};
  push @cw,"shot_id>=$p->{to_id}" if $p->{to_id};
  push @cw,"router_id=$p->{router_id}" if $p->{router_id};
  push @cw,"is_removed=$p->{is_removed}" if $p->{is_removed};
  my $cw = join(' and ',@cw);
  $cw="where $cw" if $cw;
  my $q = "select * from log_shot $cw order by shot_id desc limit $start,$limit";
  my $sth = db()->Select($q);
  my @list;

  while (my $rec=$sth->fetchrow_hashref()) {
    push @list,$rec;
  }
  return \@list;

}

sub ListNewShots {
  my $self = shift;
  my $last_id = minutshot()->GetLastProcessedUshotID() || -1;
  my $h = db()->SelectAndFetchOne('select min(shot_id) as min from log_shot where shottime is null');
  my $w="log_shot.shot_id>$last_id ";
  $w.=" and log_shot.shot_id<$h->{min}" if $h->{min};
  my @list;
  my $sth = db()->
    Select(qq(
    select count('traflog.*') as count, log_shot.*
    from log_shot
    left join traflog on traflog.shot_id=log_shot.shot_id
    where $w group by log_shot.shot_id
    ));
  while (my $rec=$sth->fetchrow_hashref()) {
    fatal("Снимок $rec->{shot_id} имеет shottime is null") unless $rec->{shottime};
    foreach (qw(minlogtime maxlogtime)) {
    	$rec->{$_}=filter('date')->FromSQL($rec->{$_});
    }
    push @list,$rec;
  }
  return \@list;
}

sub GetShotsInfo_fake {
  my ($self,$from_id) = @_;
  my $h = db()->SelectAndFetchOne('select min(shot_id) as min from log_shot where shottime is null');
  my $w;
  $w=" and shot_id<$h->{min}" if $h->{min};
  $w.=" and shot_id>$from_id" if $from_id;
  $h = db()->
    SelectAndFetchOne(qq(select max(shot_id) as max,
                         count(shot_id) as count,
                         min(minlogtime) as dfrom,
                         max(maxlogtime) as dto from log_shot where shottime is not null $w));
  my $dfrom =filter('date')->FromSQL($h->{dfrom});
  my $dto =filter('date')->FromSQL($h->{dto});
  $dto=$dfrom if $dto<$dfrom;
  return ($dfrom,$dto,$h->{max},$h->{count});
}

sub MarkAsRemoved {
  my ($self) = @_;
  return if $self->Data('is_removed');
  return $self->{table}->Modify({is_removed=>1},
                                {router_id=>$self->Data('router_id'),
                                 filetime=>$self->Data('filetime')});
}

sub MarkAsNotRemoved {
  my ($self) = @_;
  return unless $self->Data('is_removed');
  return $self->{table}->
    Modify({is_removed=>0},
           {router_id=>$self->Data('router_id'),
            filetime=>$self->Data('filetime')});
}



sub Create  {
  my ($self,$data) = @_;
  $self->checkParams($data,'router_id','filetime');
  $data->{is_removed}=0;
  return $self->SUPER::Create($data);
}

sub Close {
  my ($self,$min,$max,$mins,$maxs,$bytes,$virus_bytes) = @_; #,$mindate,$maxdate
  my $dbh = db()->{dbh};
  my $q = "update log_shot set shottime=now(), minlogtime=from_unixtime(?), maxlogtime=from_unixtime(?), count_min=?, count_max=?, bytes=?, virus_bytes=? where shot_id=?";
  logger('sql')->debug($q);
  my $sth=$dbh->prepare_cached($q);
  $sth->execute($min,$max,$mins,$maxs,$bytes,$virus_bytes,$self->ID());
  $self->SetData($self->{table}->Load({shot_id=>$self->ID()}));
}

sub Archive {
  my ($self,$days) = @_;

}

sub DeleteLogs {
  my $self  = shift;
  db()->Query('delete from traflog where shot_id=?',$self->ID());
  db()->Query('delete from viruslog where shot_id=?',$self->ID());
}

sub DeleteOldTraffic {
  my ($self,$from_id,$to_id)  = @_;
  #Временно вырубил
  db()->Query("delete from traflog where shot_id>=$from_id and shot_id<=$to_id");
}

sub Delete {
  my ($self) = @_;
  $self->{table}->Modify({shottime=>undef},
                         {shot_id=>$self->ID()});
  $self->DeleteLogs();
  return $self->SUPER::Delete();
}

sub DeleteBroken {
  my ($self)=@_;
#  db()->Query('delete virus from log_shot where viruslog.shot_id=log_shot.shot_id and shottime is null');
  db()->Query('delete traflog from traflog, log_shot where traflog.shot_id=log_shot.shot_id and shottime is null');
  db()->Query('delete log_shot from log_shot where shottime is null');
}

sub DeleteOld {
  my ($self,$shot_id,$date) = @_;
  print "Удаляю статистику старше $shot_id" if setting('terminal');
  if ($date) {
    $date=filter('date')->ToSQL($date);
    $date=" and maxlogtime<='$date'";
  }
  my $q=qq(delete from traflog, log_shot where log_shot.shot_id=traflog.shot_id
           shot_id<=$shot_id
           $date);
  my $db=db();
  die $q;
  $db->Query($q);
  print ", оптимизирую таблицы: " if setting('terminal');
  $db->Query('optimize table log_shot');
  $db->Query('optimize table traflog');
  $db->Query('optimize table viruslog');
  print "Ok\n" if setting('terminal');
}



1;
