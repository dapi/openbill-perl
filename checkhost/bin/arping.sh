#!/usr/bin/bash

ip=$1
tmp="/tmp/checklink_arping_$ip"
#echo "tmp=$tmp"

if arping -V | grep Tomas; then
  if arping -i `cat /etc/orionet/iface_local` -c 2 $ip > $tmp; then
    time=`cat $tmp | grep "bytes from" | tail -1 | sed -e 's/.*time=//'`
    loss=`cat $tmp | grep unanswer | sed -e 's/.*, //'`
    echo "ARPING: $ip=OK (TIME: $time, LOSS: $loss)"  >&2
  else
    echo "ARPING: $ip=NO ($?)"  >&2
  fi
else
  if arping -I `cat /etc/orionet/iface_local` -c 3 -f -w 1 $ip > $tmp; then
    time=`cat $tmp | grep "Unicast" | tail -1 | sed -e 's/.*\]\s*//'`
    echo "ARPING: $ip=OK (TIME: $time)"  >&2
  else
    echo "ARPING: $ip=NO ($?)"  >&2
  fi
fi


#rm $tmp