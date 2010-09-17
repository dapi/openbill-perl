#!/usr/bin/bash

ip=$1
tmp="/tmp/checklink_ping_$ip"
#echo "tmp=$tmp"
if ping -qn -c 3 -f -w 2 $ip > $tmp; then
  trip=`cat $tmp | grep "round-trip\|rtt" | sed -e 's/.*=\s*//'`
  trip=`echo $trip | sed -e 's/,.*'//`
  echo "PING: $ip=OK (TRIP: $trip)"  >&2
else
  echo "PING: $ip=NO ($?)"  >&2
fi

#rm $tmp