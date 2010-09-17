#!/bin/sh
PATH=/usr/sbin:/sbin/:/usr/local/sbin:/bin:/usr/bin:/usr/local/bin
export PATH
while (/bin/true); do
#if [ -f /usr/local/openbill/var/update_janitors.flag ]; then
#  echo "update_janitors"
  date
  nice -n 19 /home/danil/projects/openbill/sbin/update_janitors.pl
#fi
date
echo "Sleeping for 15 sec"
sleep 15
done
