#!/usr/bin/bash
rm -f /var/trafd/run/trafd.*
cd /etc/orionet/
for iface in iface_local*; do
  iface=`cat $iface`
  /usr/local/bin/trafstart $iface
done