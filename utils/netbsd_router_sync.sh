#!/bin/sh
router=$1
echo "Update router $router"


utf=".update_time"
utf2=".update_time2"


dirs="."

if [ ! -f $utf ]; then
   touch -t 200001010000 $utf
fi

files=`find $dirs -newer $utf -type f | grep -v \.#  | grep -v \~$ | grep -v \.update_time.* | grep -v "/\."`
if [ "$files" ]; then
  echo "Files to copy:"
  list=`echo "$files" | xargs`
  touch $utf2
  (tar cvf - $list | ssh root@$router /etc/orionet/bin/getsync.sh) && mv $utf2 $utf
else
   echo "No new files.."
fi
