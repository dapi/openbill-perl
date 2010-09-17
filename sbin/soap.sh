#!/bin/sh

ROOT="/home/danil/projects/openbill";
LOG="/var/log/openbill/soap.log"
echo "Starting OpenBill SOAP Server"
#/usr/local/bin/sudo -u danil $ROOT/sbin/obs_soap_server.pl -config $ROOT/etc/system.xml -p 1031 -s 217.107.177.196 2>&1 >> $LOG &

# TEST server 1030
#nohup $ROOT/sbin/obs_soap_server.pl -config $ROOT/etc/system_test.xml -p 1030 -s 217.107.177.196 2>&1 >> $LOG &

# REAL server 1031
/bin/killall obs_soap_server.pl
/usr/bin/nohup $ROOT/sbin/obs_soap_server.pl -config $ROOT/etc/system.xml -p 1031 -s 127.0.0.1 >> $LOG 2>> $LOG &
/usr/bin/nohup $ROOT/sbin/obs_soap_server.pl -config $ROOT/etc/system.xml -p 1031 -s 213.59.74.52 >> $LOG 2>> $LOG &
echo "Started"
exit