#!/usr/bin/bash

TOSEND_DIR=/var/trafd/tosend
TOSEND2_DIR=/etc/orionet/trafd

COUNT_FLAG=/tmp/trafd_count

files_max=100

do_rotate=1
do_send=1

# Удаляем флаг
rm -f $COUNT_FLAG


function delete {
  if [ "$#" != "0" ]; then
    echo "DELETE: $@ " >&2
    trap "" SIGHUP

    cd $TOSEND_DIR
    echo "OPT: delete_dir=$TOSEND_DIR"  >&2
    rm -f $@ || echo "WARNING: Can't delete logs" >&2

    cd $TOSEND2_DIR
    echo "OPT: delete_dir=$TOSEND2_DIR"  >&2
    rm -f $@ || echo "WARNING: Can't delete logs" >&2

    trap "-" SIGHUP
  fi
}

function opt {
while [ "$#" != "0" ]; do
 case "$1" in
     "-nr") do_rotate="";;
     "-ns") do_send="";;
     "-d") shift; delete $@; return 0;;
     *) echo "ERROR: Unknown option $1" >&2; exit 1;;
 esac
 shift
done
}

opt $@

/etc/orionet/bin/trafsave.sh

if [ "$do_rotate" ]; then /etc/orionet/bin/trafrotate.sh; fi

echo -n "COLLECT: "  >&2

ls -1 $TOSEND2_DIR | grep . && cp -f $TOSEND2_DIR/* $TOSEND_DIR/
cd $TOSEND_DIR
#files=`find $TOSEND_DIR -type f | sort | xargs -n $files_max`
files=`ls -1 | sort | xargs -n $files_max`
echo "$files" >&2


if [ "$files" -a "$do_send" ]; then
     echo "SEND: start" >&2
   if tar cf - $files; then
     echo "SEND: done" >&2
   else
     echo "ERROR: Tar errorcode $?. Can't send files" >&2
   fi
fi

echo "EXIT:" >&2
