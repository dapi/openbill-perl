#!/bin/sh
touch /var/log/ulog-acctd/account.log
echo  "Start daemon.."
/usr/sbin/ulog-acctd -d -D -c /usr/local/openbill/router/etc/ulog-acctd.conf
