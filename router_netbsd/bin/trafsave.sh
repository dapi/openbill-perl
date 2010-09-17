#!/bin/sh

COUNT_FLAG=/tmp/trafd_count
HOST=`/bin/hostname`

IncreaseFlag () {
 n=1
 if [ -f $COUNT_FLAG ]; then
   c=`cat $COUNT_FLAG`
   n=`echo "$c+1" | bc`
 fi
 echo $n > $COUNT_FLAG
 echo "DEBUG: counter is $n" >&2
}

IncreaseFlag


# ���������� trafsave
/etc/orionet/bin/trafcheck start
/usr/local/bin/trafsave all
# �������������� trafd.* � hostname-����
# � ����������� � �������� ��� �������� (��� �� ���� ��� � ������)

/etc/orionet/bin/trafrotate.sh save