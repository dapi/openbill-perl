#!/bin/sh

{
echo "`date` Delete"
/home/danil/projects/openbill/bin/obs_local.pl -l collector -p uhkvuk delete_old_traffic force=1 

sleep 10

echo "`date` Optimize"
/usr/bin/mysql -u openbill -ppfrjkljdfyysq orionet -Be "OPTIMIZE TABLE traflog,minut_traffic,minut_shot,manager_session,day_traffic,host;"

} >>/var/log/openbill/deleteoldtraffic.log

