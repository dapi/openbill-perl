#!/usr/bin/bash
. /usr/local/openbill/router/etc/conf.sh

do_rotate=1

# TODO максиальное число пересылаемых единовремнено файлов в опции
# TODO man getopts
# TODO делать файл через touch для вычисления последней ротации
# TODO оотменять ротацию если файл имеет такое же название
# TODO сделать болкировку чтобы не могли этот скрипт запустить параллельно
max=1000

function print_help {
  echo -e "-nr\t- no rotate" >&2
  echo -e "-a [files]\t- archive old files" >&2
  echo -e "-d [files]\t- delete old files" >&2
  exit 2
}

function delete {
  if [ "$#" != "0" ]; then
    cd $TRAFD_TOSEND_DIR
    echo "OPT: delete_dir=$TRAFD_TOSEND_DIR"  >&2
    echo "DELETE: $@ " >&2
    trap "" SIGHUP
    rm -f $@ || echo "WARNING: Can't delete logs" >&2
    trap "-" SIGHUP
  fi
}

function archive {
  if [ "$#" != "0" ]; then
    echo "OPT: stats_dir=$TRAFD_TOSEND_DIR, arc_dir=$TRAFD_ARC_DIR"  >&2
    echo "ARCHIVE: $@ " >&2
    cd $TRAFD_TOSEND_DIR || echo "WARNING: Can't change dir ($TRAFD_TOSEND_DIR)" >&2
    trap "" SIGHUP
    mv $@ $TRAFD_ARC_DIR || echo "WARNING: Can't archive logs (dir=$TRAFD_ARC_DIR)" >&2
    trap "-" SIGHUP
  fi
}

function opt {
while [ "$#" != "0" ]; do
 case "$1" in
     "-nr") do_rotate="";;
     "-a") shift; archive $@; return 0;;
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
  /usr/local/bin/trafsave >&2
  files=`ls -1 $TRAFD_LOG_DIR | grep "^trafd.\(\w\)\+$" | xargs`
  for file in $files ; do
    date=`date -u +"%Y-%m-%d-%H:%M-GMT" -r $TRAFD_LOG_DIR/$file`
    # use `date +%Y-%m-%d-%H-%M` for BSD
    log="$hostname-$date.$file"
    echo "ROTATE: $file" >&2
    mv $TRAFD_LOG_DIR/$file $TRAFD_TOSEND_DIR/$log  || echo "WARNING: Can't rotate log ($log)">&2
    echo "ROTATE: done"  >&2
  done
}

if [ "$do_rotate" ]; then rotate; fi

cd $TRAFD_TOSEND_DIR

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
