#!/bin/bash
db='orionet'
date=`date +"%Y-%m-%d-%H:%M"`
file=`echo "$db-$date.sql" | sed "+s/:/_/g"`

cd /mnt/stats/backup/

echo "Dump"
tables=`echo "show tables" | /usr/bin/mysql -uopenbill -ppfrjkljdfyysq orionet | grep -v traffic | grep -v Tables | xargs`
/usr/bin/mysqldump --default-character-set=koi8r --set-charset -uopenbill -ppfrjkljdfyysq $db $tables > $file
#mysqldump --default-character-set=koi8r --set-charset -uopenbill -ppfrjkljdfyysq $db > $file

echo "Bzip2"
bzip2 $file

echo "Cleanup"
find  /mnt/stats/backup -mtime +60 -delete

echo "Copy"
scp -o Protocol=2 -i/usr/local/openbill/var/keys/vpn.orionet.ru "$file.bz2"  vpn.orionet.ru:/usr/local/backups/mysql/orionet/
echo "Cleanup"
ssh -o Protocol=2 -i/usr/local/openbill/var/keys/vpn.orionet.ru vpn.orionet.ru find /usr/local/backups/mysql/orionet/ -a -mtime +2 -delete 
