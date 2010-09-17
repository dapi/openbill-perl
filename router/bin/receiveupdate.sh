#!/bin/sh
. /usr/local/openbill/router/etc/ulog-conf.sh
echo "Receiving OpenBill update"

dir=$OBR_ROOT

if tar xyf - --atime-preserve -C $dir; then
 echo "Update is done"
fi
