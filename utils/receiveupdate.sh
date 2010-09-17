#!/bin/sh
restart=$1
echo "Receiving update ON ($restart)"
dir="/home/danil/projects/"
if tar xf - -C $dir; then
 echo "Update is done, restart is $restart"
 if [ "$restart" -gt "1" ]; then
   echo "Start SOAP server's"
   sudo /etc/init.d/obs_soap_server restart &
 fi
 if [ "$restart" -gt "0" ]; then
   echo "Restart Apache: NO"
#   sudo /etc/init.d/apache2 restart
 fi
 echo "Finish"
fi
