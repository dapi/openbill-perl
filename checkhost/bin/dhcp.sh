#!/usr/bin/bash

ip=$1
log=`cat /etc/orionet/dhcpd_log`
res=`tail -500 $log |  grep "DHCPACK on $ip" | tail -1`
echo "DHCP: $ip=$res" >&2

#rm $tmp