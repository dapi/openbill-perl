#!/usr/bin/bash

function update {
  router=$1
  echo "Update OpenBill router: $router"
  cd /home/danil/projects/openbill/router/

utf="../var/updates/$router.update_time"
utf2="../var/updates/$router.update_time2"
#dirs="awe/ orionet/"
echo "$utf"
if [ -f $utf ]; then
   nn="-newer $utf"
fi
# $nn | grep -v firewall
files=`find . $nn -type f |  grep -v \~ | grep -v db\.xml | grep -v CVS | grep -v log/ | grep -vi .bak$ | grep -vi .db$ | grep -v BAK  | grep -v \.# | grep -v \.update_time.* | grep -v '/\.' | grep -v "var/"  | grep -v "doc/" | grep -v ethers | grep -v users.dhcpd  | grep -v users.dump | grep -v users.fw`

if [ "$files" ]; then
  echo "Files to copy"
  list=`echo "$files" | xargs`
  touch $utf2
  (tar cvf - $list | bzip2 -c | ssh root@$router /usr/local/openbill/router/bin/receiveupdate.sh) && mv $utf2 $utf
else
   echo "No new files.."
fi

}

if [ -z "$1" ]; then
  echo "Укажите имя роутера для обновления ПО"
  exit 1
fi


for router in $@; do
echo "Update router: $router"
update $router
done
