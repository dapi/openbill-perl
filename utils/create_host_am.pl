#!/usr/bin/perl
use lib qw(/home/danil/projects/openbill/
           /home/danil/projects/dpl/);
use dpl::XML;
use dpl::Error;
use dpl::Db::Database;
use dpl::Db::Table;
use dpl::Db::Filter;
use Date::Language;
use Date::Parse;
use strict;
use openbill::System;
use openbill::AccessMode;

$ENV{OPENBILL_ROOT}||='/usr/local/openbill/';
my $config = $ENV{OPENBILL_CONFIG} || "$ENV{OPENBILL_ROOT}etc/system.xml";

dpl::System::Define('openbill',$config);
dpl::Context::Init('openbill');

my $db = db();
$db->Connect();

table('access_mode')->Delete({});

my $a = access_mode();

$a->Create({id=>2,
            name=>'active',
            type=>'common',
            janitor_id=>1,
            rules=>[
                    '$fw -A USER_FORWARD -s $IP -p icmp -d ! 77.240.152.34 -j DROP',
                    '$fw -A USER_FORWARD -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -d $IP -j $USER_FORWARD_ACCEPT'
                   ]
           });
$a->Create({id=>3,
            name=>'deactive',
            type=>'common',
            janitor_id=>1,
            rules=>[
                    '$fw -A USER_FORWARD -p udp --destination-port 53 -d 10.100.0.0/16   -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p udp --source-port 53 -s 10.100.0.0/16   -d $IP -j $USER_FORWARD_ACCEPT',
		    '$fw -A USER_FORWARD -p udp --destination-port 53 -d 77.240.144.164   -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p udp --source-port 53 -s 77.240.144.164  -d $IP -j $USER_FORWARD_ACCEPT',

                    '$fw -A USER_FORWARD -p tcp --destination-port 110 -d 77.240.152.36 -s $IP -m mac --mac-source $MAC  -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --destination-port 143 -d 77.240.152.36 -s $IP -m mac --mac-source $MAC  -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --destination-port 993 -d 77.240.152.36 -s $IP -m mac --mac-source $MAC  -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 110 -s  77.240.152.36  -d $IP -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 143 -s  77.240.152.36  -d $IP -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 993 -s  77.240.152.36  -d $IP -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --destination-port 80   -d 77.240.152.34 -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --destination-port 443  -d 77.240.152.34 -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --destination-port 123  -d 77.240.152.34 -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --destination-port 5223 -d 77.240.152.34 -s $IP -m mac --mac-source $MAC  -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 80  -s 77.240.152.34  -d $IP -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 443 -s 77.240.152.34  -d $IP -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 123 -s 77.240.152.34  -d $IP -j $USER_FORWARD_ACCEPT',
		    '$fw -A USER_FORWARD -p tcp --source-port 5223 -s 77.240.152.34   -d $IP -j $USER_FORWARD_ACCEPT',

		    '$fw -A USER_FORWARD -p tcp --destination-port 110 -d 10.100.1.19 -s $IP -m mac --mac-source $MAC  -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --destination-port 143 -d 10.100.1.19 -s $IP -m mac --mac-source $MAC  -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --destination-port 993 -d 10.100.1.19 -s $IP -m mac --mac-source $MAC  -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 110 -s  10.100.1.19 -d $IP -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 143 -s  10.100.1.19 -d $IP -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 993 -s  10.100.1.19  -d $IP -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --destination-port 80   -d 10.100.1.17 -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --destination-port 443  -d 10.100.1.17 -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --destination-port 123  -d 10.100.1.17 -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --destination-port 5223 -d 10.100.1.17 -s $IP -m mac --mac-source $MAC  -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 80  -s 10.100.1.17  -d $IP -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 443 -s 10.100.1.17  -d $IP -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 123 -s 10.100.1.17  -d $IP -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 5223 -s 10.100.1.17   -d $IP -j $USER_FORWARD_ACCEPT',
                   ]
           });
$a->Create({id=>10,
            name=>'active',
            type=>'wifi',
            janitor_id=>1,
            # 5190 - ICQ login.icq.com
	# 1863 - MSN
# 1001,1002,2020,2022 - forex
            rules=>[
		    '$fw -A USER_FORWARD -s $IP -d 10.100.1.1 -j ACCEPT', #VPN
		    '$fw -A USER_FORWARD -d $IP -s 10.100.1.1 -j ACCEPT', #VPN

                    '$fw -A USER_FORWARD -s $IP -p icmp -d ! 77.240.152.34 -j DROP',
                    '$fw -t nat -A PREROUTING -s $IP -d ! 10.100.1.17 -i $LOCAL_INT -p tcp --dport 80 -j DNAT --to 10.100.1.17:27567',

                    '$fw -A USER_FORWARD -p icmp -s $IP -d 77.240.152.34 -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p icmp -d $IP -s 77.240.152.34 -j $USER_FORWARD_ACCEPT',

                    '$fw -A USER_FORWARD -p tcp --dport 2022 -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 2022 -d $IP -j $USER_FORWARD_ACCEPT',

                    '$fw -A USER_FORWARD -p tcp --dport 2020 -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 2020 -d $IP -j $USER_FORWARD_ACCEPT',

                    '$fw -A USER_FORWARD -p tcp --dport 1001 -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 1001 -d $IP -j $USER_FORWARD_ACCEPT',

                    '$fw -A USER_FORWARD -p tcp --dport 1005 -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 1005 -d $IP -j $USER_FORWARD_ACCEPT',

                    '$fw -A USER_FORWARD -p tcp --dport 1002 -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 1002 -d $IP -j $USER_FORWARD_ACCEPT',

                    '$fw -A USER_FORWARD -p tcp --dport 1863 -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 1863 -d $IP -j $USER_FORWARD_ACCEPT',

                    '$fw -A USER_FORWARD -p tcp --dport 5190 -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 5190 -d $IP -j $USER_FORWARD_ACCEPT',

                    '$fw -A USER_FORWARD -p tcp --dport 80 -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 80 -d $IP -j $USER_FORWARD_ACCEPT',

                    '$fw -A USER_FORWARD -p tcp --destination-port 27567 -d 10.100.1.17  -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 27567 -s 10.100.1.17 -d $IP -j $USER_FORWARD_ACCEPT',

                    '$fw -A USER_FORWARD -p udp --destination-port 53 -d 10.100.6.1  -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p udp --source-port 53 -s 10.100.6.1 -d $IP -j $USER_FORWARD_ACCEPT',

                    '$fw -A USER_FORWARD -p tcp --destination-port 80 -d 77.240.152.34  -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 80 -s 77.240.152.34  -d $IP -j $USER_FORWARD_ACCEPT',

                    '$fw -A USER_FORWARD -p tcp --destination-port 110 -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 110 -d $IP -j $USER_FORWARD_ACCEPT',

                    '$fw -A USER_FORWARD -p tcp --destination-port 25 -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 25 -d $IP -j $USER_FORWARD_ACCEPT',

                    '$fw -A USER_FORWARD -p tcp --destination-port 5223 -d 77.240.152.34   -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 5223 -s 77.240.152.34  -d $IP -j $USER_FORWARD_ACCEPT',
                   ]
           });
$a->Create({id=>11,
            name=>'deactive',
            type=>'wifi',
            janitor_id=>1,
            rules=>[]
           });

$a->Create({id=>12,
            name=>'active',
            type=>'netping',
            janitor_id=>1,
            rules=>[
                    '$fw -A USER_FORWARD -p icmp -s $IP -d 77.240.152.34 -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p icmp -d $IP -s 77.240.152.34 -j $USER_FORWARD_ACCEPT',
                   ]
           });
$a->Create({id=>13,
            name=>'deactive',
            type=>'netping',
            janitor_id=>1,
            rules=>[]
           });


$a->Create({id=>39,
            name=>'active',
            type=>'vpn_only',
            janitor_id=>2,
            rules=>[
		    'ipf: pass in quick on $if_int proto tcp from $ip to 77.240.152.34 keep state',
		    'ipf: pass in quick on $if_int proto tcp from $ip to 77.240.152.34 keep state',
		    'ipf: pass in quick on $if_int proto tcp from $ip to 77.240.152.34 keep state',
		    'ipf: pass in quick on $if_int proto icmp from $ip to 77.240.152.34 keep state',
		    #mail
		    'ipf: pass in quick on $if_int proto tcp from $ip to 77.240.152.36 keep state',
		    'ipf: pass in quick on $if_int proto udp from $ip to 77.240.152.36 keep state',
		    'ipf: pass in quick on $if_int proto tcp from $ip to 77.240.152.36 keep state',
		    'ipf: pass in quick on $if_int proto tcp from $ip to 77.240.152.36 keep state',
		    'ipf: pass in quick on $if_int proto icmp from $ip to 77.240.152.36 keep state',
		    #games,ftp
		    'ipf: pass in quick on $if_int proto tcp from $ip to 10.100.1.6 keep state',
		    'ipf: pass in quick on $if_int proto tcp from $ip to 10.100.1.9 keep state',
		    'ipf: pass in quick on $if_int proto icmp from $ip to 10.100.1.6 keep state',
		    'ipf: pass in quick on $if_int proto icmp from $ip to 10.100.1.9 keep state',
                   ]
           });
$a->Create({id=>40,
            name=>'deactive',
            type=>'vpn_only',
            janitor_id=>2,
            rules=>[
		    #simple routing to colocation
		    #www
		    'ipf: pass in quick on $if_int proto tcp from $ip to 77.240.152.34 port = 80 keep state',
		    'ipf: pass in quick on $if_int proto tcp from $ip to 77.240.152.34 port = 123 keep state',
		    'ipf: pass in quick on $if_int proto tcp from $ip to 77.240.152.34 port = 443 keep state',
		    'ipf: pass in quick on $if_int proto icmp from $ip to 77.240.152.34 keep state',
		    #mail
		    'ipf: pass in quick on $if_int proto tcp from $ip to 77.240.152.36 port = 53 keep state',
		    'ipf: pass in quick on $if_int proto udp from $ip to 77.240.152.36 port = 53 keep state',
		    'ipf: pass in quick on $if_int proto tcp from $ip to 77.240.152.36 port = 80 keep state',
		    'ipf: pass in quick on $if_int proto tcp from $ip to 77.240.152.36 port = 110 keep state',
		    'ipf: pass in quick on $if_int proto icmp from $ip to 77.240.152.36 keep state',
		    #games,ftp
		    'ipf: pass in quick on $if_int proto tcp from $ip to 10.100.1.6 keep state',
		    'ipf: pass in quick on $if_int proto tcp from $ip to 10.100.1.9 keep state',
		    'ipf: pass in quick on $if_int proto icmp from $ip to 10.100.1.6 keep state',
		    'ipf: pass in quick on $if_int proto icmp from $ip to 10.100.1.9 keep state',
                   ]
           });
$a->Create({id=>43,
            name=>'active',
            type=>'netping',
            janitor_id=>2,
            rules=>[
                   ]
           });
$a->Create({id=>44,
            name=>'deactive',
            type=>'netping',
            janitor_id=>2,
            rules=>[
                   ]
           });
$a->Create({id=>45,
            name=>'active',
            type=>'admin',
            janitor_id=>2,
            rules=>[
                   ]
           });
$a->Create({id=>46,
            name=>'deactive',
            type=>'admin',
            janitor_id=>2,
            rules=>[
                   ]
           });
$a->Create({id=>47,
            name=>'active',
            type=>'common',
            janitor_id=>2,
            rules=>[
                   ]
           });
$a->Create({id=>48,
            name=>'deactive',
            type=>'common',
            janitor_id=>2,
            rules=>[
                   ]
           });


###################

### VPN

$a->Create({id=>19,
            name=>'active',
            type=>'vpn_only',
            janitor_id=>1,
            rules=>[
                    '$fw -A USER_FORWARD -p tcp -d 10.100.1.1 --dport 1723 -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp -s 10.100.1.1 --sport 1723 -d $IP -j $USER_FORWARD_ACCEPT', 
                    '$fw -A USER_FORWARD -p 47 -d 10.100.1.1 -s $IP -j ACCEPT',
                    '$fw -A USER_FORWARD -p 47 -s 10.100.1.1 -d $IP -j ACCEPT',
                    '$fw -A USER_FORWARD -p udp --destination-port 53 -d 10.100.0.0/16  -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p udp --source-port 53 -s 10.100.0.0/16  -d $IP -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --destination-port 110 -d  77.240.152.36  -s $IP -m mac --mac-source $MAC  -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 110 -s  77.240.152.36  -d $IP -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --destination-port 143 -d  77.240.152.36  -s $IP -m mac --mac-source $MAC  -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 143 -s  77.240.152.36  -d $IP -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --destination-port 993 -d  77.240.152.36  -s $IP -m mac --mac-source $MAC  -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 993 -s  77.240.152.36  -d $IP -j $USER_FORWARD_ACCEPT',
		    '$fw -A USER_FORWARD -p tcp --destination-port 80   -d 77.240.152.34 -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --destination-port 443  -d 77.240.152.34 -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --destination-port 123  -d 77.240.152.34 -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 80  -s 77.240.152.34  -d $IP -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 443 -s 77.240.152.34  -d $IP -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 123 -s 77.240.152.34  -d $IP -j $USER_FORWARD_ACCEPT',

                    '$fw -A USER_FORWARD -p tcp --destination-port 110 -d  10.100.1.19  -s $IP -m mac --mac-source $MAC  -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 110 -s  10.100.1.19  -d $IP -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --destination-port 143 -d  10.100.1.19  -s $IP -m mac --mac-source $MAC  -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 143 -s  10.100.1.19  -d $IP -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --destination-port 993 -d  10.100.1.19  -s $IP -m mac --mac-source $MAC  -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 993 -s  10.100.1.19  -d $IP -j $USER_FORWARD_ACCEPT',
		    '$fw -A USER_FORWARD -p tcp --destination-port 80   -d 10.100.1.17 -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --destination-port 443  -d 10.100.1.17 -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --destination-port 123  -d 10.100.1.17 -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 80  -s 10.100.1.17  -d $IP -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 443 -s 10.100.1.17  -d $IP -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 123 -s 10.100.1.17  -d $IP -j $USER_FORWARD_ACCEPT',
                   ]
           });
$a->Create({id=>20,
            name=>'deactive',
            type=>'vpn_only',
            janitor_id=>1,
            rules=>[
                    '$fw -A USER_FORWARD -p tcp -d 10.100.1.1 --dport 1723 -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp -s 10.100.1.1 --sport 1723 -d $IP -j $USER_FORWARD_ACCEPT', 
                    '$fw -A USER_FORWARD -p 47 -d 10.100.1.1 -s $IP -j ACCEPT',
                    '$fw -A USER_FORWARD -p 47 -s 10.100.1.1 -d $IP -j ACCEPT',
                    '$fw -A USER_FORWARD -p udp --destination-port 53 -d 10.100.0.0/16  -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p udp --source-port 53 -s 10.100.0.0/16  -d $IP -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --destination-port 110 -d  77.240.152.36  -s $IP -m mac --mac-source $MAC  -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 110 -s  77.240.152.36  -d $IP -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --destination-port 143 -d  77.240.152.36  -s $IP -m mac --mac-source $MAC  -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 143 -s  77.240.152.36  -d $IP -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --destination-port 993 -d  77.240.152.36  -s $IP -m mac --mac-source $MAC  -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 993 -s  77.240.152.36  -d $IP -j $USER_FORWARD_ACCEPT',
		    '$fw -A USER_FORWARD -p tcp --destination-port 80   -d 77.240.152.34 -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --destination-port 443  -d 77.240.152.34 -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --destination-port 123  -d 77.240.152.34 -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 80  -s 77.240.152.34  -d $IP -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 443 -s 77.240.152.34  -d $IP -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 123 -s 77.240.152.34  -d $IP -j $USER_FORWARD_ACCEPT',

		    '$fw -A USER_FORWARD -p tcp --destination-port 110 -d  10.100.1.19  -s $IP -m mac --mac-source $MAC  -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 110 -s  10.100.1.19  -d $IP -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --destination-port 143 -d  10.100.1.19  -s $IP -m mac --mac-source $MAC  -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 143 -s  10.100.1.19  -d $IP -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --destination-port 993 -d  10.100.1.19  -s $IP -m mac --mac-source $MAC  -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 993 -s  10.100.1.19  -d $IP -j $USER_FORWARD_ACCEPT',
		    '$fw -A USER_FORWARD -p tcp --destination-port 80   -d 10.100.1.17 -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --destination-port 443  -d 10.100.1.17 -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --destination-port 123  -d 10.100.1.17 -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 80  -s 10.100.1.17  -d $IP -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 443 -s 10.100.1.17  -d $IP -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 123 -s 10.100.1.17  -d $IP -j $USER_FORWARD_ACCEPT',
                   ]
           });


#################
# RADIUS

$a->Create({id=>21,
            name=>'active',
            type=>'common',
            janitor_id=>3,
            rules=>[
                   ]
           });
$a->Create({id=>22,
            name=>'deactive',
            type=>'common',
            janitor_id=>3,
            rules=>[
                   ]
           });
###################


$a->Create({id=>23,
            name=>'active',
            type=>'admin',
            janitor_id=>1,
            rules=>[
                    '$fw -A USER_FORWARD -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -d $IP -j $USER_FORWARD_ACCEPT'
                   ]
           });
$a->Create({id=>24,
            name=>'deactive',
            type=>'admin',
            janitor_id=>1,
            rules=>[
                    '$fw -A USER_FORWARD -p udp --destination-port 53 -d 10.100.0.0/16   -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p udp --source-port 53 -s 10.100.0.0/16   -d $IP -j $USER_FORWARD_ACCEPT',
		    '$fw -A USER_FORWARD -p tcp --destination-port 80   -d 77.240.152.34 -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --destination-port 443  -d 77.240.152.34 -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --destination-port 123  -d 77.240.152.34 -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 80  -s 77.240.152.34  -d $IP -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 443 -s 77.240.152.34  -d $IP -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 123 -s 77.240.152.34  -d $IP -j $USER_FORWARD_ACCEPT',

		    '$fw -A USER_FORWARD -p tcp --destination-port 80   -d 10.100.1.17 -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --destination-port 443  -d 10.100.1.17 -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --destination-port 123  -d 10.100.1.17 -s $IP -m mac --mac-source $MAC -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 80  -s 10.100.1.17  -d $IP -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 443 -s 10.100.1.17  -d $IP -j $USER_FORWARD_ACCEPT',
                    '$fw -A USER_FORWARD -p tcp --source-port 123 -s 10.100.1.17  -d $IP -j $USER_FORWARD_ACCEPT',
                   ]
           });



### FreeBSD ipfw

$a->Create({id=>25,
            name=>'active',
            type=>'common',
            janitor_id=>4,
            rules=>[
                    #'allow udp from $ip to me dst-port 53',
                    'allow ip from 77.240.152.34 to $ip keep-state',
		    #'allow ip from $ip to not me',
		    'allow ip from $ip to any keep-state',
		    ]
           });
$a->Create({id=>26,
            name=>'deactive',
            type=>'common',
            janitor_id=>4,
            rules=>[
                    #'allow udp from $ip to me dst-port 53 MAC any $mac',
                    'allow ip from 77.240.152.34 to $ip keep-state',
                    'allow ip from $ip to 77.240.152.34 dst-port 80,123 keep-state']
           });


$a->Create({id=>27,
            name=>'active',
            type=>'admin',
            janitor_id=>4,
            rules=>[
                    'allow ip from 77.240.152.34 to $ip keep-state',
		    'allow ip from $ip to any keep-state',
                    'allow ip from any to $ip keep-state',
                    'allow gre from $ip to any keep-state',
                    'allow gre from any to $ip keep-state'
                   ]
           });
$a->Create({id=>28,
            name=>'deactive',
            type=>'admin',
            janitor_id=>4,
            rules=>[
                    'allow ip from 77.240.152.34 to $ip keep-state',
                    'allow ip from $ip to 77.240.152.34 keep-state'
                   ]

           });


$a->Create({id=>29,
            name=>'active',
            type=>'netping',
            janitor_id=>4,
            rules=>[
                    'allow icmp from $ip to 77.240.152.34',
                    'allow icmp from 77.240.152.34 to $ip'
                   ]
           });
$a->Create({id=>30,
            name=>'deactive',
            type=>'netping',
            janitor_id=>4,
            rules=>['allow icmp from 77.240.152.34 to $ip keep-state']
           });


$a->Create({id=>31,
            name=>'active',
            type=>'wifi',
            janitor_id=>4,
            # 5190 - ICQ login.icq.com
	# 1863 - MSN
# 1001,1002,2020,2022 - forex
            rules=>[
                    # Allow http to orionet.ru
                    'allow tcp from $ip to 77.240.152.34 dst-port 80,123 keep-state',
                    'allow tcp from $ip to 77.240.152.36 dst-port 80,25,110,993,995,143,220,465 keep-state',
                    # Forward all http traf to our proxy
                    'fwd 127.0.0.1,27567 tcp from $ip to any dst-port 80',
                    # Allow http answers from hosts to wifi
                    'allow ip from any 80 to $ip',
                    # Allow icmp ping tests to any host
                    'allow icmp from $ip to any keep-state',
                    # Allow to receive and send mail
                    'allow ip from $ip to any dst-port 25,110,143 keep-state',
                    # ICQ and Jabber and Windows Messager
                    'allow ip from $ip to any dst-port 5190,5223,1863 keep-state',
                    # Forex
                    'allow ip from $ip to any dst-port 1001,1002,1005,2020,2022 keep-state',

                   ]
           });

$a->Create({id=>32,
            name=>'deactive',
            type=>'wifi',
            janitor_id=>4,
            rules=>[
                    'allow ip from 77.240.152.34 to $ip keep-state'
                   ]
           });

$a->Create({id=>33,
            name=>'active',
            type=>'vpn_only',
            janitor_id=>4,
            rules=>[
                    'allow ip from 77.240.152.34 to $ip keep-state',
		    'allow tcp from $ip to 10.100.1.1 1723 keep-state',
                    'allow gre from $ip to 10.100.1.1 keep-state',

# Это соединение со спутником, его тут не должно быть
# для него нужно создавать отдельный тип соединения, например satellite
#                    'allow tcp from $ip to 87.238.112.164 1723 keep-state',
#                    'allow gre from $ip to 87.238.112.164 keep-state',
                    'allow ip from $ip to 77.240.152.34 dst-port 80,123 keep-state',
# Разрешить почту
                    'allow ip from $ip to 77.240.152.36 keep-state',
		    ]
           });
$a->Create({id=>34,
            name=>'deactive',
            type=>'vpn_only',
            janitor_id=>4,
            rules=>[
                    'allow ip from 77.240.152.34 to $ip keep-state',

                    'allow gre from $ip to 10.100.1.1 keep-state',
                    'allow tcp from $ip to 10.100.1.1 1723 keep-state',
# Разрешить почту
                    'allow ip from $ip to 77.240.152.36 keep-state',

# Доступ на WWW	и тайм-сервер
                    'allow ip from $ip to 77.240.152.34 dst-port 80,123 keep-state'
                   ]
           });

$a->Create({id=>37, name=>'active', type=>'sputnik', janitor_id=>4, rules=>[] });
$a->Create({id=>38, name=>'deactive', type=>'sputnik', janitor_id=>4, rules=>[] });
$a->Create({id=>41, name=>'active', type=>'local_resources', janitor_id=>4, rules=>[] });
$a->Create({id=>42, name=>'deactive', type=>'local_resources', janitor_id=>4, rules=>[] });
$a->Create({id=>49, name=>'active', type=>'vpn_nodhcp',	janitor_id=>4, rules=>[] });
$a->Create({id=>50, name=>'deactive', type=>'vpn_nodhcp', janitor_id=>4, rules=>[] });
$a->Create({id=>51, name=>'active', type=>'admin64',	janitor_id=>4, rules=>[] });
$a->Create({id=>52, name=>'deactive', type=>'admin64', janitor_id=>4, rules=>[] });
$a->Create({id=>53, name=>'active', type=>'admin128',	janitor_id=>4, rules=>[] });
$a->Create({id=>54, name=>'deactive', type=>'admin128', janitor_id=>4, rules=>[] });
$a->Create({id=>55, name=>'active', type=>'admin256',	janitor_id=>4, rules=>[] });
$a->Create({id=>56, name=>'deactive', type=>'admin256', janitor_id=>4, rules=>[] });


### FreeBSD ipfw_table

$db->Commit();
$db->Disconnect();
