#!/bin/sh
echo "Update Openbill on oriopay.ru"

cd /home/danil/projects/

utf="openbill/utils/.update_time"
utf2="openbill/utils/.update_time2"
dirs="dpl/ openbill/"
restart=$1
if [ -z "$restart" ]; then
restart=2
fi
files=`find $dirs -newer $utf -type f | grep -v \~ | grep -v db\.xml | grep -v "log/" | grep -v bz2 | grep -v "tmp/" | grep -v gz  | grep -v "var/" | grep -v CVS | grep -v log/ | grep -v images/ | grep -vi .bak$ | grep -vi .db$ | grep -v BAK | grep -v "openbill/etc/local___.xml" | grep -v \.# | grep -v \.update_time.* | grep -v "/\."`
if [ "$files" ]; then
#  echo "Files to copy:"
#  restart="$1"
  echo "Restart $restart"
  list=`echo "$files" | xargs`
   touch $utf2
  (tar cvf - $list | ssh danil@billing.orionet.ru /home/danil/projects/openbill/utils/receiveupdate.sh $restart) && mv $utf2 $utf
else
   echo "No new files.."
fi

./openbill/utils/update_shell.sh