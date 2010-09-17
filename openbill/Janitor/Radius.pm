package openbill::Janitor::Radius;
use strict;
use Data::Dumper;
use Data::Serializer;
use openbill::Utils;
use openbill::Host;
use openbill::Router;
use openbill::Janitor;
use openbill::AccessMode;
use dpl::Context;
use dpl::Log;
use dpl::System;
use dpl::Db::Filter;
use dpl::Db::Table;
use dpl::Db::Database;
use Archive::Tar;
use dpl::Error;
use Error qw(:try);
use Exporter;
use vars qw(@ISA
            %MPD_RULES
            %MPD_RULES_SHARED
            %JANITOR_STATUS
	    %TARIFF_TYPE
            $COMMAND_LINE
            @EXPORT);

sub moduleDesc { 'Привратник по Radius-у' }

@ISA=qw(Exporter
        openbill::Janitor::IPTables);

$COMMAND_LINE="$SSH -i \${keysdir}\${hostname} \${login}@\${ip} /usr/local/openbill/janitors/change_speed.sh";

%JANITOR_STATUS=(RECEIVE=>2,INFO=>2,WARNING=>2,ERROR=>2,DONE=>1);
%MPD_RULES=(
                16=>[
                 {attribute=>'mpd-pipe', op=>'+=',
                  value=>'1=bw 16Kbit/s queue 10'},
                 {attribute=>'mpd-pipe', op=>'+=',
                  value=>'5=bw 16Kbit/s queue 10'},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'1=pipe %p1 all from any to any in'},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'2=pipe %p5 all from any to any out'},
                ],
		32=>[
                 {attribute=>'mpd-pipe', op=>'+=',
                  value=>'1=bw 32Kbit/s queue 10'},
                 {attribute=>'mpd-pipe', op=>'+=',
                  value=>'5=bw 32Kbit/s queue 10'},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'1=pipe %p1 all from any to any in'},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'2=pipe %p5 all from any to any out'},
                ],
                64=>[
                 {attribute=>'mpd-pipe', op=>'+=',
                  value=>'1=bw 64Kbit/s queue 20 gred 0.002/5/15/0.02'},
                 {attribute=>'mpd-pipe', op=>'+=',
                  value=>'5=bw 64Kbit/s queue 20 gred 0.002/5/15/0.02'},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'1=pipe %p1 all from any to any in'},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'2=pipe %p5 all from any to any out'},
                ],
           96=>[
                 {attribute=>'mpd-pipe', op=>'+=',
                  value=>'1=bw 96Kbit/s queue 25 gred 0.002/5/20/0.02'},
                 {attribute=>'mpd-pipe', op=>'+=',
                  value=>'5=bw 96Kbit/s queue 25 gred 0.002/5/20/0.02'},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'1=pipe %p1 all from any to any in'},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'2=pipe %p5 all from any to any out'},
                ],
           128=>[
                 {attribute=>'mpd-pipe', op=>'+=',
                  value=>'1=bw _SPEED_Kbit/s queue 35 gred 0.002/10/30/0.02'},
                 {attribute=>'mpd-pipe', op=>'+=',
                  value=>'5=bw _SPEED_Kbit/s queue 35 gred 0.002/10/30/0.02'},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'1=pipe %p1 all from any to any in'},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'2=pipe %p5 all from any to any out'},
                ],
           160=>[
                 {attribute=>'mpd-pipe', op=>'+=',
                  value=>'1=bw _SPEED_Kbit/s queue 35 gred 0.002/10/30/0.02'},
                 {attribute=>'mpd-pipe', op=>'+=',
                  value=>'5=bw _SPEED_Kbit/s queue 35 gred 0.002/10/30/0.02'},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'1=pipe %p1 all from any to any in'},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'2=pipe %p5 all from any to any out'},
                ],
           192=>[
                 {attribute=>'mpd-pipe', op=>'+=',
                  value=>'1=bw _SPEED_Kbit/s queue 35 gred 0.002/10/30/0.02'},
                 {attribute=>'mpd-pipe', op=>'+=',
                  value=>'5=bw _SPEED_Kbit/s queue 35 gred 0.002/10/30/0.02'},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'1=pipe %p1 all from any to any in'},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'2=pipe %p5 all from any to any out'},
                ],
           256=>[
                 {attribute=>'mpd-pipe', op=>'+=',
                  value=>'1=bw _SPEED_Kbit/s queue 40 gred 0.002/15/35/0.02'},
                 {attribute=>'mpd-pipe', op=>'+=',
                  value=>'5=bw _SPEED_Kbit/s queue 40 gred 0.002/15/35/0.02'},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'1=pipe %p1 all from any to any in'},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'2=pipe %p5 all from any to any out'},
                ],
           320=>[
                 {attribute=>'mpd-pipe', op=>'+=',
                  value=>'1=bw _SPEED_Kbit/s queue 40 gred 0.002/15/35/0.02'},
                 {attribute=>'mpd-pipe', op=>'+=',
                  value=>'5=bw _SPEED_Kbit/s queue 40 gred 0.002/15/35/0.02'},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'1=pipe %p1 all from any to any in'},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'2=pipe %p5 all from any to any out'},
                ],
           512=>[
                 {attribute=>'mpd-pipe', op=>'+=',
                  value=>'1=bw _SPEED_Kbit/s queue 50 gred 0.002/20/45/0.02'},
                 {attribute=>'mpd-pipe', op=>'+=',
                  value=>'5=bw _SPEED_Kbit/s queue 50 gred 0.002/20/45/0.02'},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'1=pipe %p1 all from any to any in'},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'2=pipe %p5 all from any to any out'},
                ]

);

#Правила для общих анлимов (1 на несколько хостов)
#XXX: интерфейс (em0) должен совпадать с интерфейсом - аплинком на впне, иначе шейпериться не будет
#XXX: в skipto XXX вместо XXX подставляется номер правила с которого идут разрешающие правила (45000)
#XXX: // в конце правил добавляется чтобы закомментировать добавляемы mpd "via ngX"
%MPD_RULES_SHARED=(
           32=>[
                 {attribute=>'mpd-pipe', op=>'+=',
                  value=>'1=bw 32Kbit/s'},
                 {attribute=>'mpd-pipe', op=>'+=',
                  value=>'5=bw 32Kbit/s'},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'1=pipe %p1 ip from any to _IPSET_ in via em0 // '},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'2=skipto 45000 ip from any to _IPSET_ // '},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'3=pipe %p5 ip from _IPSET_ to any out via em0 // '},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'4=skipto 45000 ip from _IPSET_ to any // '}
                ],
           64=>[
                 {attribute=>'mpd-pipe', op=>'+=',
                  value=>'1=bw 64Kbit/s queue 20 gred 0.002/5/15/0.02'},
                 {attribute=>'mpd-pipe', op=>'+=',
                  value=>'5=bw 64Kbit/s queue 20 gred 0.002/5/15/0.02'},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'1=pipe %p1 ip from any to _IPSET_ in via em0 // '},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'2=skipto 45000 ip from any to _IPSET_ // '},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'3=pipe %p5 ip from _IPSET_ to any out via em0 // '},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'4=skipto 45000 ip from _IPSET_ to any // '}
                ],
           128=>[
                 {attribute=>'mpd-pipe', op=>'+=',
                  value=>'1=bw _SPEED_Kbit/s queue 35 gred 0.002/10/30/0.02'},
                 {attribute=>'mpd-pipe', op=>'+=',
                  value=>'5=bw _SPEED_Kbit/s queue 35 gred 0.002/10/30/0.02'},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'1=pipe %p1 ip from any to _IPSET_ in via em0 // '},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'2=skipto 45000 ip from any to _IPSET_ // '},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'3=pipe %p5 ip from _IPSET_ to any out via em0 // '},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'4=skipto 45000 ip from _IPSET_ to any // '}
                ],
           192=>[
                 {attribute=>'mpd-pipe', op=>'+=',
                  value=>'1=bw _SPEED_Kbit/s queue 35 gred 0.002/10/30/0.02'},
                 {attribute=>'mpd-pipe', op=>'+=',
                  value=>'5=bw _SPEED_Kbit/s queue 35 gred 0.002/10/30/0.02'},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'1=pipe %p1 ip from any to _IPSET_ in via em0 // '},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'2=skipto 45000 ip from any to _IPSET_ // '},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'3=pipe %p5 ip from _IPSET_ to any out via em0 // '},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'4=skipto 45000 ip from _IPSET_ to any // '}
                ],
           256=>[
                 {attribute=>'mpd-pipe', op=>'+=',
                  value=>'1=bw _SPEED_Kbit/s queue 40 gred 0.002/15/35/0.02'},
                 {attribute=>'mpd-pipe', op=>'+=',
                  value=>'5=bw _SPEED_Kbit/s queue 40 gred 0.002/15/35/0.02'},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'1=pipe %p1 ip from any to _IPSET_ in via em0 // '},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'2=skipto 45000 ip from any to _IPSET_ // '},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'3=pipe %p5 ip from _IPSET_ to any out via em0 // '},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'4=skipto 45000 ip from _IPSET_ to any // '}
                ],
           320=>[
                 {attribute=>'mpd-pipe', op=>'+=',
                  value=>'1=bw _SPEED_Kbit/s queue 40 gred 0.002/15/35/0.02'},
                 {attribute=>'mpd-pipe', op=>'+=',
                  value=>'5=bw _SPEED_Kbit/s queue 40 gred 0.002/15/35/0.02'},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'1=pipe %p1 ip from any to _IPSET_ in via em0 // '},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'2=skipto 45000 ip from any to _IPSET_ // '},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'3=pipe %p5 ip from _IPSET_ to any out via em0 // '},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'4=skipto 45000 ip from _IPSET_ to any // '}
                ],
           512=>[
                 {attribute=>'mpd-pipe', op=>'+=',
                  value=>'1=bw _SPEED_Kbit/s queue 50 gred 0.002/20/45/0.02'},
                 {attribute=>'mpd-pipe', op=>'+=',
                  value=>'5=bw _SPEED_Kbit/s queue 50 gred 0.002/20/45/0.02'},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'1=pipe %p1 ip from any to _IPSET_ in via em0 // '},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'2=skipto 45000 ip from any to _IPSET_ // '},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'3=pipe %p5 ip from _IPSET_ to any out via em0 // '},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'4=skipto 45000 ip from _IPSET_ to any // '}
                ],
           4000=>[
                 {attribute=>'mpd-pipe', op=>'+=',
                  value=>'1=bw 4Mbit/s'},
                 {attribute=>'mpd-pipe', op=>'+=',
                  value=>'5=bw 4Mbit/s'},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'1=pipe %p1 ip from any to _IPSET_ in via em0 // '},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'2=skipto 45000 ip from any to _IPSET_ // '},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'3=pipe %p5 ip from _IPSET_ to any out via em0 // '},
                 {attribute=>'mpd-rule', op=>'+=',
                  value=>'4=skipto 45000 ip from _IPSET_ to any // '}
                ]

);

#Спец тарифы. Номера соотвествуют номерам таблиц, прописанные на vpn в /usr/local/etc/firewall.table.names
%TARIFF_TYPE=(
	#Аренда канала (анлим + фирма)
	rent=>109,
	#Помегабайтная оплата
	mb=>110,
	#Безлимиты
	unlim=>111,
	#Ограничения для офиса ORIONET
	office=>114
);

sub AddRules {
  my ($self,$db,$rules,$username,$speed,$ipset)=@_;
  foreach (@$rules) {
    my $val =  $_->{value};
    $val =~ s/_IPSET_/$ipset/g;
    $val =~ s/_SPEED_/$speed/g;
    $db->Query("insert into radreply (username,attribute,op,value) values (?,?,?,?)",
               $username,$_->{attribute},$_->{op},$val);
  }
}

#Вывод всех впн-хостов клиента в виде множества: "net24/{host1,host2,...,hostN}" (напр 10.100.96.0/24{1,2,3})
#возврат:
#   "all" - хост только один (множество не нужно)
#   [] - хосты клиента не лежат в одной /24 сети и не могут быть записаны одним множеством.
sub get_client_ipset {
  my ($self,$hosts,$client_id)=@_;
  my %networks;
  my $cnt = 0;

  #XXX: Определять список хостов клиента надо по другому
  #XXX: Хеш networks сохранен в виде хеша на случай если вдруг понадобится
  # убрать ограничение в одно /24 множество
  foreach my $h (@$hosts) {
    if ($h->{client_id} == $client_id) {
      my $ip = $h->{ip};
      my ($net24,$host) = ($ip =~ /(\d+\.\d+\.\d+)\.(\d+)$/);
      if ( ! defined %networks->{$net24} ) {
      	%networks->{$net24} = "$net24.0/24{$host";
      }else {
      	%networks->{$net24} = %networks->{$net24} . ",$host";
      }
      $cnt++;
    }
  } 

  #Возвращаем ошибку если у нас получлось больше одной /24 сети
  if ( (keys %networks) != 1 ) {
  	return;
  }

  if ($cnt == 1) {
	return "all";
  }

  my $res = %networks->{(keys %networks)[0]} . "}";
  return $res;
}


sub _wholeUpdate {0}

sub remoteUpdate {
  my ($self,$router,$hosts,$restore) = @_;

  my $r = $router->Data();
  my @change_speed;
#  print "Обновляю привратника на $r->{hostname}: ";
  my $db = db('radius');
  return
try {
   # $db->Begin();
   if ($restore) {
      # Обновляем всю базу
      $db->Query("delete from radcheck");
      $db->Query("delete from radreply");
      $db->Query("delete from usergroup");
   }
   foreach my $h (@$hosts) {
      unless ($restore) {
	 $db->Query("delete from radcheck where username=?",$h->{hostname});
	 $db->Query("delete from radreply where username=?",$h->{hostname});
	 $db->Query("delete from usergroup where username=?",$h->{hostname});
      }
      if ($h->{access_name} eq 'active') {
	 if ($h->{tariff}) {
	    my $s = $h->{tariff}->{speed};
	    my $bonus = $h->{bonus_speed} || 0;
	    if ($h->{is_limited}) {
	       $s=$h->{tariff}->{limit_speed};
	       $bonus=0;
	       print STDERR "Month traffic limit '$s' for user $h->{hostname}:$h->{ip}\n";
	       logger()->debug("Month traffic limit '$s' for user $h->{hostname}:$h->{ip}");
	    }
	    if ($h->{is_night_mode} && $h->{night_speed}) {
	       $s=$h->{night_speed};
	       $bonus=0;
	       logger()->debug("Night mode '$s' for user $h->{hostname}:$h->{ip}");
	    }
	    if (!$s && $h->{tariff}->{is_unlim}) {
	       logger->error("No speed limit ($s) for unlimit tariff, change to 32kbit for $h->{hostname}:$h->{ip} ($h->{is_night_mode}:$h->{is_limited})");
	       $s=32;
	       $bonus=0;
	    }

	    if ($s) {
	       my $r;
	       my $ipset = $self->get_client_ipset($hosts, $h->{client_id});
	       #XXX: Проверку количества впн хостов лучше сделать не по значению ipset
	       if ( ! defined $ipset ) {
		  #Клиент на анлиме с несколькими впн хостами в разных /24 сетях.
		  #Делаем на каждый ип 32 килобита.
		  logger->error("Client $h->{client_id} have vpn hosts in different /24 subnets.
			Can not limit speed");
		  $ipset=$h->{ip};
		  $s=32;
		  $bonus=0;
		  $r = $MPD_RULES{$s};
	       } elsif ( $ipset != "all") {
		  #Клиент на анлиме с несколькими впн хостами
		  logger->debug("Client $h->{client_id} is on unlim and have many vpn hosts: $ipset");
		  $r = $MPD_RULES_SHARED{$s}
	       }else {
		  #Клиент на анлиме с одним впн хостом
		  $r = $MPD_RULES{$s};
	       }

	       unless ($r) {
		  logger->error("No such speed in MPD rules '$s',
			change to 32kbit for  $h->{hostname}:$h->{ip}
			($h->{is_night_mode}:$h->{is_limited})");
			$r = $MPD_RULES{32};
			$s=32;
			$bonus=0;
			$ipset=$h->{ip};
	       }
	       $self->AddRules($db,$r,$h->{hostname}, $s+$bonus, $ipset);
	    }
	    if ( ($h->{tariff}->{is_unlim} && !$h->{current_speed})
		  || ($h->{current_speed}!=$s+$bonus)) {
	       push @change_speed,{ip=>$h->{ip},speed=>$s+$bonus};
	       db()->Query('update host set current_speed=?,is_night_mode=? where host_id=?',
		     $s+$bonus,
		     $h->{is_night_mode},
		     $h->{host_id});
	    }
	    print STDERR "host $h->{host_id}:$h->{ip} ($h->{is_night_mode}:$h->{is_limited},$h->{tariff}->{tariff_id}:$h->{tariff}->{is_unlim}) speed $s bonus $bonus\n";
	    $db->Query("insert into radcheck (username,attribute,op,value) values (?,'User-Password',':=',?)",
		  $h->{hostname},$h->{password});
	    $db->Query("insert into radreply (username,attribute,op,value) values (?,'Framed-IP-Address',':=',?)",
		  $h->{hostname},$h->{ip});
	    $db->Query("insert into radreply (username,attribute,op,value) values (?,'Framed-IP-Netmask',':=','255.255.255.255')",
		  $h->{hostname});
	    $db->Query("insert into usergroup (username,groupname) values (?,'users')",
		  $h->{hostname});
	    my $tblnum=$TARIFF_TYPE{mb};
	    $tblnum=$h->{tariff}->{is_firm}?$TARIFF_TYPE{rent}:$TARIFF_TYPE{unlim}
	    if ( $h->{tariff}->{is_unlim} );
	    $tblnum=$TARIFF_TYPE{office}
	    if ( $h->{comment} =~ /OFFICE/ );

	    $db->Query("insert into radreply (username,attribute,op,value) values (?,'mpd-table-static','+=',?)",
		  $h->{hostname}, "$tblnum=$h->{ip}");

	 } else {
	    logger()->error("No tariff for host $h->{host_id}, client: $h->{client_id}");
	 }
      } else {
	 # Выключить
	 push @change_speed, {ip=>$h->{ip},speed=>0} unless $h->{am_time};
      }
   } #foreach my $h (@$hosts)
   my $ok=1;
   $db->Commit();
   if (@change_speed) {
      my $tosend = join("\n",map {"$_->{ip} $_->{speed}"} @change_speed);
      my $status = RemoteExecute($COMMAND_LINE,
	    \%JANITOR_STATUS,
	    {login=>$r->{login},
	    hostname=>$r->{hostname},
	    ip=>$r->{real_ip},
	    },
	    "$tosend\n");
      $ok=$status && ref($status) && $status->{DONE} eq 'OK';
   }

   return $ok;
} except {
	$db->Rollback();
	return 0;
};
}

sub CheckLink {
  my ($self,$router,$count) = (shift,shift,shift);
  return undef;
}



1;
