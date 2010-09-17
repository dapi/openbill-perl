#!/usr/bin/bash
db='orionet'
date=`date +"%Y-%m-%d-%H:%M"`
file="$db-$date-traffic.sql"

cd /mnt/stats/backup/

/usr/local/mysql/bin/mysqldump -uorionet -prehjxrf $db \
 log_shot day_traffic day_shot > $file
#minut_shot minut_traffic  > $file

bzip2 $file