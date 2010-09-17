#!/bin/sh

ch()
{
count=$1
ip=$2

rm -f $tmp
tmp="/tmp/arping_$tt_$ip"


if arp -an | grep "($ip)" > $tmp; then
  iface=`cat $tmp | sed -e 's/.* on \([a-z0-9]*\).*/\1/'`
else
  ping -c 1 $ip > /dev/null
  if arp -an | grep "($ip)" > $tmp; then
    iface=`cat $tmp | sed -e 's/.* on \([a-z0-9]*\).*/\1/'`
  else
    echo "ARPING: $ip;NO;ARP"  >&2
    return 4
  fi
fi

if arping -v | grep Thomas >/dev/null; then
  if arping -v -i $iface -c $count $ip > $tmp; then
    time=`cat $tmp | grep "bytes from" | tail -1 | sed -e 's/.*time=//'`
    mac=`cat $tmp | grep "bytes from" | tail -1 | sed -e 's/.*bytes from //' | sed -e 's/ (.*//'`
    loss=`cat $tmp | grep unanswer | sed -e 's/\(.*\)\([ 0-9][ 0-9][0-9]\)% *.*/\2/' | sed -e 's/ //g'`
    echo "ARPING: $ip;OK;$mac;$time;$loss;$count"  >&2
    return 0
  else
    echo "ARPING: $ip;NO;$?"  >&2
    return 1
  fi
else
 echo "ARPING: $ip;NO;UNKNOWN" >&2
 return 2
fi

}

count=3
tt='tmp'

if [ "$1" = "-n" ]; then
   count=$2
   shift 2
fi

for ip in $*; do
 ch $count $ip &
done

wait
