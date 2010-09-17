#!/usr/bin/bash
date=`date +"%Y-%m-%d-%H:%M"`
db="orionet"
file="$db-$date.sql"

echo "Copy ORIONET database.."

echo "drop database openbill; create database openbill; connect openbill;" > $file

/usr/local/mysql/bin/mysqldump -uroot -prehjxrb $db >> $file

#echo "delete from manager_session; commit; update client set email=client_id, name=client_id, firmname=client_id, inn=client_id, telefon=client_id;" >> $file

ls -la $file

echo "Create OPENBILL database.."

/usr/local/mysql/bin/mysql -f -uroot -prehjxrb < $file && rm $file

msql='/tmp/manager.sql'

echo "connect openbill;" > $msql
echo "delete from manager;" >> $msql
echo "update street set name=street_id;" >> $msql
echo "update client set name=client_id, firmname=client_id, inn=client_id, telefon=client_id, email=client_id;" >> $msql

echo "insert into manager values (1,'rdfrdf','admin','admin','',1,1);" >> $msql
echo "insert into manager values (2,'rdfrdf','operator','operator','',2,1);"  >> $msql


/usr/local/mysql/bin/mysql -f -uroot -prehjxrb < $msql && rm $msql
