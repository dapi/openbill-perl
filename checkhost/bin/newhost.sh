#!/usr/bin/bash

log=`cat /etc/orionet/dhcpd_log`
tail -500 $log | grep DHCPACK
