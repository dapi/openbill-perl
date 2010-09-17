package openbill::Account;
use strict;
use dpl::Base;
use dpl::Db::Filter;
use dpl::Db::Table;
use dpl::Db::Database;
use openbill::Utils;
use Exporter;
use vars qw(@ISA
            @EXPORT);

@ISA=qw(Exporter
        dpl::Base);
@EXPORT=qw(account);

sub account {
  return openbill::Account->instance('account',@_);
}

sub init {
  my ($self,$client) = @_;
  $self->{client} = $client;
  return $self;
}

sub GetCurrency { return 'р.'; }


sub GetBalance {
  my ($self,$date) = @_;
  my $charged = $self->GetChargedSumm($date);
  my $payed = $self->GetPayedSumm($date);
  my $balance = $payed-$charged;
  return $balance;
}

sub GetChargedSumm {
  my ($self,$date) = @_;
  my $cid = $self->{client}->ID();
  if (ref($date)=~/date::handler/i) {
    $date = filter('date')->ToSQL($date);
    my $t=db()->SelectAndFetchOne(qq(select sum(summa) as summa
                                     from charge, period
                                     where period.id=charge.period_id
                                     and client_id=$cid and end<'$date'));
    return $t->{summa};
  } else {
    my $t=db()->SelectAndFetchOne("select sum(summa) as summa from charge where client_id=$cid");
    return $t->{summa};
  }
}

# Возвращает коэффициент использования месяца (0..1)

sub GetChargesLog {
  my $self = shift;
  my $cid = $self->{client}->ID();
  my @list;
  my $t=db()->SelectAndFetchAll("select * from charge, period where client_id=$cid and period.id=charge.period_id order by start desc");
  foreach (@$t) {
    # TODO зависимости от service_id запускать различные FromSQL
    $_->{traffic}=filter('serializer')->FromSQL($_->{traffic});
    $_->{start}=filter('date')->FromSQL($_->{start});
    $_->{end}=filter('date')->FromSQL($_->{end});
    push @list,$_;
  }
  return \@list;

}

sub GetPayedSumm {
  my ($self,$date) = @_;
  my $cid = $self->{client}->ID();
  if (ref($date)=~/date::handler/i) {
    $date=filter('date')->ToSQL($date);
    my $t = db()->SelectAndFetchOne(qq(select sum(summa) as summa
                                       from payment where client_id=$cid and
                                       type=1 and date<'$date'));
    return $t->{summa};
  } elsif (ref($date)=~/period/i) {
    my $start=filter('date')->ToSQL($date->Data('start'));
    my $end=filter('date')->ToSQL($date->Data('end'));
    my $t = db()->SelectAndFetchOne(qq(select sum(summa) as summa
                                       from payment where client_id=$cid and
                                       type=1 and date<='$end' and date>='$start'));
    return $t->{summa};
  } elsif (!$date) {
    my $t=db()->SelectAndFetchOne("select sum(summa) as summa from payment where client_id=$cid and type=1");
    return $t->{summa};
  } else {
    fatal("internal error ($date)");
  }
}

sub GetPaymentsLog {
  my ($self) = @_;
  return table('payment')->List({client_id=>$self->{client}->ID()});
}

1;
