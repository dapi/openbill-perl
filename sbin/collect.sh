#!/bin/sh
PATH=/usr/sbin:/sbin/:/usr/local/sbin:/bin:/usr/bin:/usr/local/bin
export PATH
echo "Start.."
while (/bin/true); do
echo "collect"
nice -n 19 /home/danil/projects/openbill/bin/obs_local.pl -l collector -p uhkvuk collect
echo "history"
nice -n 19 /mnt/stats/bin/history_shots.sh /mnt/stats/archive_*/*
echo "update_traffic"
/home/danil/projects/openbill/bin/obs_local.pl -l collector -p uhkvuk update_traffic
echo "charge"
/home/danil/projects/openbill/bin/obs_local.pl -l collector -p uhkvuk charge
echo "do_alert"
/home/danil/projects/openbill/bin/obs_local.pl -l collector -p uhkvuk do_alert
#date
#/home/danil/projects/openbill/bin/obs_local.pl -l collector -p uhkvuk delete_old_traffic 2>&1
echo "Sleeping for 120"
sleep 120
done
