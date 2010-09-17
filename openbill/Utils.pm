package openbill::Utils;
use strict;
use locale;
use IPC::Open3;
use Symbol qw(gensym);
use IO::File;
use IO::Scalar;
use Number::Format qw(:subs);
use dpl::Context;
use dpl::Log;
use dpl::Error;
use Time::HiRes qw(usleep ualarm gettimeofday tv_interval);
use openbill::DataType::Date;
use openbill::DataType::DateTime;
use openbill::DataType::Time;
use dpl::System;
#use LockFile::Simple qw(lock trylock unlock);
#use Number::Format qw(:subs);
#use Date::Parse;
#use Number::Format qw(:subs);
#use POSIX qw(locale_h);
#use locale;
#use Date::Handler;
#use Date::Format;
#use Date::Calc;
use Exporter;
use vars qw(@ISA
	    @EXPORT
            $SSH
            $KBYTES
            $MBYTES
            $GBYTES);
@ISA = qw(Exporter);

$SSH=ssh();

$KBYTES=1000; # TODO Переместить в конфиг
$MBYTES=$KBYTES*$KBYTES;
$GBYTES=$KBYTES*$KBYTES*$KBYTES;

@EXPORT=qw(GetMonthFromDate
           $SSH
           CheckMac
           RoundMoney
           MonthToDate
           DateToMonth
           FormatBytes
           FormatMoney
           ParseInline
           RemoteExecute
           inet_fromint
           inet_toint
           inet_aton
           inet_atobm
           inet_ntoa
           inet_bmtoa
           ConvertIPsToStr
	   StartTimer
           GetTimer
           ParseDate
           ParseDateTime
           ParseMonth
           IsDatesEqual
           PeriodFromDate
           ToDate
          );

sub ssh {
  return '/usr/bin/ssh -C -oProtocol=2 ';
}

sub CheckMac {
  my $mac = shift;
  return $mac=~/^([a-f0-9]{2}:){5}[a-f0-9]{2}$/i;
}

sub ToDate {
  my $value = shift;
  return bless $value, 'openbill::DataType::Date';
}

sub ToDateTime {
  my $value = shift;
  return bless $value, 'openbill::DataType::DateTime';
}

sub ToTime {
  my $value = shift;
  die 2;
  return bless $value, 'openbill::DataType::Time';
}


sub IsDatesEqual {
  my ($date1,$date2)=@_;
  return $date1->Year()==$date2->Year() &&
    $date1->Month()==$date2->Month() &&
      $date1->Day()==$date2->Day();
}

sub PeriodFromDate {
  my ($date) = @_;
  return undef unless $date;
  $date=ParseData($date) unless ref($date);
  my $locale = $date->Locale();
  my $from = new openbill::DataType::Date({ date => {year => $date->Year(), month => $date->Month(),
                                                     day => 1, hour => 0, min => 0, sec => 0, },
                                            time_zone => $date->TimeZone(), locale => $locale,
                                          });
  my $end = new openbill::DataType::Date({ date => {year => $date->Year(), month => $date->Month(),
                                                    day => $date->DaysInMonth(), hour => 0, min => 0, sec => 0, },
                                           time_zone => $date->TimeZone(), locale => $locale,
                                         });
  return ($from,$end);
}

#sub Date::Handler::string {
#  my $self = shift;
#  return $self->TimeFormat('%Y-%m-%d');
#}

sub ParseDate {
  my $value = shift;
  if ($value eq 'today') {
    return today();
  } elsif ($value eq 'yesterday') {
    return today() - 24*60*60;
  } elsif (my ($year,$month,$day)=($value=~/^(\d\d\d\d)[.\-\/](\d\d)[.\-\/](\d\d)/)) {
    return new openbill::DataType::Date({ date => {year=>$year,
                                                   month=>$month,
                                                   day=>$day},
                                          locale=>'ru_RU.KOI8-R',
                                          time_zone => 'Europe/Moscow'});    # TODO time_zone веьде перевезти в конфиг
  } else {
    fatal("Неверно указана дата '$value', надо в формате YYYY.MM.DD");
  }
}

sub ParseDateTime {
  my $value = shift;
  if ($value eq 'today') {
    return today();
  } elsif (my ($year,$month,$day,$hour,$minut,$seconds)
           =($value=~/^(\d\d\d\d)[.\-\/](\d\d)[.\-\/](\d\d) (\d\d):(\d\d):(\d\d)/)) {
    return new openbill::DataType::DateTime({ date => {year=>$year,
                                                   month=>$month,
                                                   day=>$day,
                                                   hour=>$hour,
                                                   min=>$minut,
                                                   sec=>$seconds},
                                          locale=>'ru_RU.KOI8-R',
                                          time_zone => 'Europe/Moscow'});    # TODO time_zone веьде перевезти в конфиг
  } else {
    fatal("Неверно указана дата '$value', надо в формате YYYY.MM.DD HH:MM:SS");
  }
}



sub ParseMonth {
  my $value = shift;
  my $year;
  my $month;
  my $day;
  if ($value eq 'today' || $value eq 'yesterday') {
    my $date = ParseDate($value);
    $year = $date->Year();
    $month = $date->Month();
  } elsif (($year,$month,$day)=($value=~/^(\d\d\d\d)[.\-\/](\d\d)/)) {
  } else {
    fatal("Неверно указана дата '$value', надо в формате YYYY.MM");
  }
  return new openbill::DataType::Date({ date => {year=>$year,
                                                 month=>$month,
                                                 day=>1},
                                        locale=>'ru_RU.KOI8-R',
                                        time_zone => 'Europe/Moscow'});    # TODO time_zone веьде перевезти в конфиг
}


sub ParseInline {
  my ($str,$p) = @_;
  # TODO Ругаться если спрашивается праметр, который не установлен
  $str=~s/\$\{([a-z0-9_]+)\}/$p->{$1}/gei;
  return $str;
}

sub inet_atobm {
  my @t;
  for (@_) {
    my ($quad,$b, $bits) = m!^(\d+\.\d+\.\d+\.\d+)([:/](\d+))?!g;
    $bits=32-($bits || 32);
    my $int = unpack("N", pack("C4", split(/\./, $quad)));
    push @t, { mask => $int >> $bits, bits => $bits };
  }
  return wantarray ? @t : $t[0];
}

sub inet_bmtoa {
  my @t;
  foreach (@_) {
    my $mask = $_->{mask} << $_->{bits};
    my $str = join('.',$mask >> 24,($mask >> 16) & 255, ($mask >> 8) & 255, $mask & 255);
    $str.="/".(32-$_->{bits}) if $_->{bits}>0;
    $str.="[$_->{mark}]" if $_->{mark};
    push @t,$str;
  }
  return wantarray ? @t : $t[0];
}

sub inet_toint {
  my $str=shift;
  my $mask=32;
  if ($str=~s/\/(\d+)//) {
    $mask=$1;
  }
  fatal("Неверная маска ($mask). Формат должен быть nnn.nnn.nnn.nnn/nn")
    if $mask<1 || $mask>32;
  my $bits = 32-$mask;
  my $n = inet_aton($str) || fatal("Неверный формат ($str/$mask), должен быть nnn.nnn.nnn.nnn/nn");
  $n=$n>>$bits if $bits;
  return ($n,$bits);
}

sub inet_fromint {
  my ($num,$bits)=@_;
  $num=$num<<$bits if $bits;
  my $mask = 32-$bits;
  return $mask==32 ? inet_ntoa($num) : inet_ntoa($num)."/$mask";
}

sub inet_aton {
  my $ip = shift;
  return unpack("N", pack("C4", split(/\./, $ip)));
}

sub inet_ntoa {
  my $value = shift;
  return join('.',$value >> 24,($value >> 16) & 255, ($value >> 8) & 255, $value & 255)
}

sub GetMonthFromDate {
  my $date = shift;
  return $date->TimeFormat('%y%m');
}

sub MonthToDate {
  my $str = shift;
  throw dpl::Error("Неверный формат месяца ($str). Надо YYYYMM")
    unless $str=~/^(\d{4})(\d{2})$/;
  return new openbill::DataType::Date({
                                       date => [$1,$2,1,00,00,00],
                                       time_zone => 'Europe/Moscow'
                                      });
}

sub RemoteExecute {
  my ($cmd_line,$status_info,$params,$tosend) = @_;
  #  die join(',',@$toremove);
  $params->{login}='root' unless $params->{login};
  $params->{root}='/usr/local/openbill/router/';
  $params->{keysdir}=directory('ssl_keys');
  # params:
  #   ip
  #   real_ip
  #   hostname
  my $cmd = ParseInline($cmd_line,$params);
#  print STDERR "Выполняю '$cmd'\n";
#  print STDERR "Посылаю '$tosend'\n";
  logger()->debug("Выполняю '$cmd'");
  local *TOSEND;
  if ($tosend) {
    *TOSEND =  IO::File->new_tmpfile();
    print TOSEND $tosend;
    seek TOSEND,0,0;
  }
  local *CATCHERR = IO::File->new_tmpfile();
  my $pid = open3($tosend ? "<&TOSEND" : gensym, \*CATCHOUT, ">&CATCHERR", $cmd);
  my $out;
  while( <CATCHOUT> ) {
    $out.=$_;
  }
  waitpid($pid, 0);
  my $code = $?;
  seek CATCHERR, 0, 0;
  my $err;
  my %status;
  while( <CATCHERR> ) {
    if (/ssh\:.+connect/ && !$params->{log_ssh_errors}) {
      logger()->debug($_);
      next;
    }

    $err.=$_;
    if (/^([A-Z0-9_]+):\s*(.*)$/) {
      my ($key,$value)=($1,$2);
      if ($status_info->{$key}==1) {
        logger()->error("$params->{hostname}: Атрибут $key повторился")
          if defined $status{$key};
        $status{$key}=$value;
      } elsif ($status_info->{$key}==2) {
        $status{$key}=[]
          unless $status{$key};
        push @{$status{$key}},$value;
      } else {
        logger()->error("$params->{hostname}: Неизвестный атрибут в строке STDERR: '$_'");
        $status{$key}=[]
          unless $status{$key};
        push @{$status{$key}},$value;
      }
    } else {
    	chomp;
      logger()->error("$params->{hostname} '$cmd': Неизвестный формат строке в STDERR: '$_'")
      	unless /Connection closed by/i || /in the future/i;
    }
  }
  map {logger()->warn("Хост вернул предупреждение: $_")} @{$status{WARNING}}
    if $status{WARNING};
  map {logger()->error("$params->{hostname}: Хост вернул ошибку: $_")} @{$status{ERROR}}
    if $status{ERROR};
  if ($code>0) {
    logger()->debug("Ошибка соединения с роутером: $code");
    return \%status;
  } elsif ($out) {
    logger()->error("$params->{hostname}: Ошибка соединения с роутером. Выданы символы в STDOUT: $out");
    return \%status;
  } elsif ($err=~/error|warning/i) {
    logger()->error("$params->{hostname}: Проблемы соединения с роутером. Выданы error или warning STDERR: $err");
    return \%status;
  } else {
    logger()->debug("Передача закончена успешно. STDOUT=$out, STDERR=$err, EXITCODE=$code;");
  }
  return \%status;
}


sub DateToMonth {
  my $date = shift;
  return $date->TimeFormat('%Y-%m');
}

sub StartTimer {
  my $name = shift;
  setContext("openbill:times_$name",[gettimeofday]);
}

sub GetTimer {
  my ($name,$m) = @_;
  my $t = context("openbill:times_$name");
  return round(tv_interval ( $t ),defined $m ? $m : 2);
}

sub RoundMoney {
  my $money = shift;
  return round($money,2);
}



sub filter_bytes {
  return FormatBytes(@_);
}

sub filter_inet_ntoa {
  return inet_ntoa(@_);
}



sub filter_money_balance {
  my $money = shift;
  $money=0 unless $money;
  return FormatMoney($money,'руб.') if $money>0;
  return '<font color=#cc0000>'.FormatMoney($money,'руб.').'</font>';
}

sub filter_money {
  my $money = shift;
  return '' unless $money;
  return FormatMoney($money,'руб.');
}



sub filter_date {
  my $date = shift;
  return $date->TimeFormat('%Y %B %d');
}

sub filter_time {
  my $time = shift;
  if (ref($time)) {
    return $time->TimeFormat('%X');
  } else {
    my $m = $time % 60;
    $m="0$m" if $m<10;
    my $h=($time-$m)/60;
    $h="0$h" if $h<10;
    return "$h:$m";
  }
}

sub FormatMoney {
  my ($money,$currency) = @_;
  return '0' unless $money;
  $money=RoundMoney($money);
  my $kop = $money=~s/[.,](.+)$// ? $1 : 0;
  #  while ($money=~s/(\d)(\d{3})( |$)/$1\`$2$3/) {
  #    1;
  #  };
  #$kop=~s/(.{2}).*/$1/;
  $kop.='0' if length($kop)==1;
  $kop='00' unless $kop;
  $currency=" $currency" if $currency;
  return $kop ? "$money.$kop$currency" : "$money$currency";
}

sub FormatBytes {
  my ($bytes,$type) = @_;
  return 'ref:'.ref($bytes) if ref($bytes);
  return '-' if !$bytes && $bytes ne '0';
  my $show_bytes = setting('show_bytes') || 'm';
  return $bytes if $show_bytes eq 'b';
  my $minus;
  if ($bytes<0) {
    $minus='-';
    $bytes=-$bytes;
  }
  if ($type) {
    while ($bytes=~s/(\d)(\d{3})( |$)/$1 $2$3/) {
      1;
    };
  } elsif ($show_bytes eq 'm') {
    if ($bytes > $GBYTES) {
      $bytes=round($bytes/$MBYTES,0);
      while ($bytes=~s/(\d)(\d{3})( |$)/$1\`$2$3/) {
        1;
      };
      $bytes="$bytes Мб";
             #      $bytes=round($bytes/$GBYTES).' Гб';
   } elsif ($bytes > $MBYTES) {
     $bytes=round($bytes/$MBYTES,2).' Мб';
   } elsif ($bytes > 9999 || $show_bytes eq 'k') {
     $bytes=round($bytes/$KBYTES,2).' Кб';
   } else {
     $bytes="$bytes байт";
   }
    } else {
      die 'not imeplemented';
    }
  return "$minus$bytes";
}








1;
