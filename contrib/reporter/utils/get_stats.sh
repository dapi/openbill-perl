#!/bin/sh

#$1 - day | month
#$2 - day (2007-08-01) | month (2007-08-01)
#$3 - [format ( -1 -2 -3)]
#$4 - speed kbit/s (6000)

#Пример: utils/get_stats.sh month 2007-08-01 -2

OBS_MONTH="$2"
REPORTER_KEYS=${3:-"-3"}
speed_bw=${4:-6000}

WORK_DIR="/tmp/reporter"
LOCALS_FILE="$WORK_DIR/locals.txt"

OBS_LOCAL="/home/danil/projects/openbill/bin/obs_local.pl"
OBS_ACCOUNT="-l littlesavage -p fRtb842vtG"
REPORTER="./reporter -m $speed_bw"

HISTORY_DIR="/mnt/stats/history/"
STATS_FILES="vpn.orionet.ru-ipacct/*.xl0.bz2"

GET_LOCALS_AWK="utils/getlocals.awk"

rm -rf $WORK_DIR && mkdir $WORK_DIR

if [ "$1" = "day" ]; then
	HISTORY_FILES="$HISTORY_DIR/$2"
elif [ "$1" = "month" ]; then
	HISTORY_FILES="$HISTORY_DIR/${2:0:7}-*"
else
    echo "usage:"
    echo "$0 day|month value(day: 2007-08-01, month: 2007-08-01)"
    exit
fi

#Считываем локальные хосты с тарифами
$OBS_LOCAL $OBS_ACCOUNT list_all_hosts month=$OBS_MONTH | awk -v month=$OBS_MONTH  -f $GET_LOCALS_AWK | sort -n > $LOCALS_FILE

if [ ! -s $LOCALS_FILE ]; then
    echo "cannot get local ips"
    exit
fi

#Скармливаем логи из /mnt/stats reporter'у
for d in $HISTORY_FILES; do 
	bzcat ${d}/$STATS_FILES; 
done | $REPORTER $REPORTER_KEYS -c $LOCALS_FILE 

#rm -rf $WORK_DIR

