#!/usr/bin/bash

now=`echo now | tai64n`
echo "NOW: $now" >&2
path=/etc/orionet/bin
for ip in $* ; do
  echo "IP: $ip" >&2
  $path/ping.sh $ip &
  $path/arping.sh $ip &
  $path/dhcp.sh $ip &
done

wait

echo "DONE: OK" >&2