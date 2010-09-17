#!/usr/bin/bash
. /usr/local/openbill/router/etc/ulog-conf.sh

do_rotate=1
do_archive=0

# TODO максиальное число пересылаемых единовремнено файлов в опции
# TODO man getopts
# TODO делать файл через touch для вычисления последней ротации
# TODO оотменять ротацию если файл имеет такое же название
# TODO сделать болкировку чтобы не могли этот скрипт запустить параллельно
max=1000

function print_help {
  echo -e "-nr\t- no rotate ulog-acctd" >&2
  echo -e "-a\t- archive moved files" >&2
  echo -e "-d [files]\t- delete old logs" >&2
  exit 2
}

function delete_arc {
  if [ "$#" != "0" ]; then
    if [ "$do_archive" ]; then
      cd $ARC_DIR >&2
      echo "OPT: delete_dir=$ARC_DIR"  >&2
    else
      cd $LOG_DIR >&2
      echo "OPT: delete_dir=$LOG_DIR"  >&2
    fi
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
     "-a") do_archive="";;
     "-d") shift; delete_arc $@; return 0;;
     "-h") print_help;;
     *) echo "ERROR: Unknown option $1" >&2; exit 1;;
 esac
 shift
done
}

opt $@

if [ "$do_archive" ]; then
 echo "OPT: Archive moved files. " >&2
fi

if [ "$do_rotate" ]; then
 echo "OPT: Rotate account log. " >&2
fi

function archive {
    echo "ARCHIVE: $@ " >&2
    trap "" SIGHUP
    mv $@ $ARC_DIR || echo "WARNING: Can't archive logs (dir=$ARC_DIR)" >&2
    trap "-" SIGHUP
}

function rotate {
  date=`date -u +"%Y-%m-%d-%H:%M-GMT"`
  log="$hostname-$date.log"
  if [ -f "$LOG_DIR$log" ]; then
     echo "EXISTS: $log" >&2
     return 1
  fi
  if [ -s $ACCOUNT ]; then
    echo "ROTATE: $log" >&2
    pid=`cat $PID_FILE`
    if [ "$pid" ] && ps -p $pid > /dev/null; then
      trap "" SIGHUP
      kill -TSTP $pid || echo "ERROR: stop"  >&2
      mv $ACCOUNT "$LOG_DIR$log" || echo "ERROR: rotate"  >&2
      kill -CONT $pid || echo "ERROR: continue"  >&2
      trap "-" SIGHUP
    else
      echo "WARNING: Daemon it not running!"  >&2
    fi
    echo "ROTATE: done"  >&2
  else
    echo "ZERO: $log"  >&2
  fi
}



if [ "$do_rotate" ]; then rotate;  fi

cd $LOG_DIR

echo -n "COLLECT: "  >&2
files=`find . -maxdepth 1 -name "*.log" | sort | xargs -n $max | perl -pe "\\$_=undef if \\$line++;"`
echo "$files" >&2

if [ "$files" ]; then
   if tar cf - $files; then
    echo "SEND: done" >&2
    if [ "$do_archive" ]; then archive $files; fi
   else
     echo "ERROR: Tar errorcode $?. Can't send files" >&2
   fi
fi

echo "EXIT:" >&2