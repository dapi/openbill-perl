#!/bin/sh

ch()
{

ip=$1

tmp="/tmp/arping_$ip"

if arp -an | grep "($ip)" > $tmp; then
  iface=`cat $tmp | sed -e 's/.* on \([a-z0-9]*\).*/\1/'`
  rm -f $tmp
else
  echo "ARPING: $ip;NO;ARP"  >&2
  rm -f $tmp
  return 4
fi

if arping -v | grep Thomas >/dev/null; then
  if arping -v -i $iface -c 3 $ip > $tmp; then
    time=`cat $tmp | grep "bytes from" | tail -1 | sed -e 's/.*time=//'`
    mac=`cat $tmp | grep "bytes from" | tail -1 | sed -e 's/.*bytes from //' | sed -e 's/ (.*//'`
    loss=`cat $tmp | grep unanswer | sed -e 's/\(.*\)\([ 0-9][ 0-9][0-9]\)% *.*/\2/' | sed -e 's/ //g'`
    echo "ARPING: $ip;OK;$mac;$time;$loss"  >&2
    rm -f $tmp
    return 0
  else
    rm -f $tmp
    echo "ARPING: $ip;NO;$?"  >&2
    return 1
  fi
else
 echo "ARPING: $ip;NO;UNKNOWN" >&2
 return 2
fi

}

for ip in $*; do
 ch $ip
done