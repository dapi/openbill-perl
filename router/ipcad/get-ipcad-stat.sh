#!/usr/bin/bash

max=100
#set -x
DIR=/var/log/ipcad/
TOSEND_DIR=/var/log/ipcad/tosend


function print_help {
  echo -e "-nr\t- no rotate" >&2
  echo -e "-d [files]\t- delete old files" >&2
  exit 2
}


function delete {
  if [ "$#" != "0" ]; then
    cd $TOSEND_DIR
    echo "OPT: delete_dir=$TOSEND_DIR"  >&2
    echo "DELETE: $@ " >&2
    trap "" SIGHUP
    rm -f $@ || echo "WARNING: Can't delete logs" >&2
    trap "-" SIGHUP
  fi
}



function opt {
while [ "$#" != "0" ]; do
 case "$1" in
     "-nr") do_rotate="";;
     "-d") shift; delete $@; return 0;;
     "-h") print_help;;
     *) echo "ERROR: Unknown option $1" >&2; exit 1;;
 esac
 shift
done
}

opt $@

function rotate {
  echo "OPT: Rotate" >&2
  shopt -s extglob

  if [ ! -f $DIR/new.ipcad ];
    # Move IP accounting to checkpoint
    rsh localhost clear ip accounting >> /dev/null
    # Show saved IP accounting
    rsh localhost show ip accounting checkpoint > $DIR/new.ipcad
    # Clear checkpoint
    rsh localhost clear ip accounting checkpoint >> /dev/null
  fi

  date=`date -u +"%Y-%m-%d-%H:%M-GMT" -r $DIR/new.ipcad`
  # use `date +%Y-%m-%d-%H-%M` for BSD
  log="$hostname-$date.ipcad"
  echo "ROTATE: $file" >&2
  mv $DIR/new.ipcad $TOSEND_DIR/$log  || echo "WARNING: Can't rotate log ($log)">&2
  echo "ROTATE: done"  >&2
  done
}

if [ "$do_rotate" ]; then rotate; fi


cd $TOSEND_DIR

echo -n "COLLECT: "  >&2
files=`ls -1 | sort | xargs -n $max | perl -pe "\\$_=undef if \\$line++;"`
echo "$files" >&2

if [ "$files" ]; then
   if tar cf - $files; then
    echo "SEND: done" >&2
   else
    echo "ERROR: Tar errorcode $?. Can't send files" >&2
   fi
fi

echo "EXIT:" >&2
