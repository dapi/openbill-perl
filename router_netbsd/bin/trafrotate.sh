#!/usr/bin/bash

# ���� ��������, ��� ��� �������
# � ���� ���������� ���������
# �� ������

PARAM=$1

FLAG=/tmp/save_trafd
COUNT_FLAG=/tmp/trafd_count
MAX_COUNT=7 # 6 ��� �� 5 ����� ��� �������

LOG_DIR=/var/trafd/
TOSEND_DIR=/var/trafd/tosend/
SAVE_DIR=/etc/orionet/trafd/

if [ -f $FLAG ]; then
  echo "DEBUG: save traf flag"
  DST_DIR=$SAVE_DIR;
else
  DST_DIR=$TOSEND_DIR;

  # ���� trafsave ������� ����� ������������� ����� ���
  # ������ ������ ����� �� �������� � ��� ����
  # ��������� �� flash
  c=`test -f $COUNT_FLAG && cat $COUNT_FLAG || echo 0`;
  if [ $c -gt $MAX_COUNT ]; then
     echo "DEBUG: max count $c > $MAX_COUNT"
     DST_DIR=$SAVE_DIR;
     PARAM='s'   # �������������� �����
  fi

  # �����, ���� ������� �� trafsave � ��� ������������� ���������
  if [ "$PARAM" = 'save' ]; then
    exit 0
  fi
fi

hostname=`hostname -s`

shopt -s extglob
files=`ls -1 $LOG_DIR | grep "^trafd.\(\w\)\+$" | xargs`

for file in $files ; do
    d='0'
    log=''
    while [ -z "$log" ]; do
        date=`date -u +"%Y-%m-%d-%H:%M:$d-GMT"`
        log="$hostname-$date.$file"
        # ���� ���� ���������� - ������������� ���
        if [ -f $DST_DIR/$log ]; then
           echo "DEBUG: file exists $log" >&2
           d=`echo $d+1 | bc`
           log=''
        fi
    done
    echo "ROTATE: $log" >&2
    mv $LOG_DIR/$file $DST_DIR/$log || echo "ERROR: Can't rotate log ($log)">&2
    echo "ROTATE: done"  >&2
done
