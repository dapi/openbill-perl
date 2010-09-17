#!/usr/bin/bash

iface=`cat /etc/orionet/iface_external`
echo "AIRO:"
cat /proc/driver/aironet/$iface/Status
echo "DF:"
/bin/df
echo "FREE:"
/bin/free
