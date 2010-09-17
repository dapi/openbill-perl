#!/bin/bash
#$1 - day/week/month
#$2 - емайл (ek@orionet.ru)


case $1 in 
"day")
	subj2="день"
	datefmt="1 day ago 00:00"
	;;
"week")
	subj2="неделю"
	datefmt="1 week ago 00:00"
	;;
"month")
	subj2="месяц"
	datefmt="1 month ago 00:00"
	;;
*)
	echo "usage: $0 day|week|month"
	exit
	;;
esac

subj="Статистика за $subj2 от `date -d "$datefmt" +%Y-%m-%d`"
stats_fname="stats-`date -d "$datefmt" +%Y-%m`.txt"

{
	boundary='simple boundary';
	echo "To: $2
From: littlesavage@orionet.ru
Subject:  $subj
Content-Type: multipart/mixed; boundary=\"$boundary\"
	 
This is a multi-part message in MIME format. 
--$boundary 
Content-Type: text/plain; charset=KOI8-R; format=flowed
Content-Transfer-Encoding: 8bit


--$boundary 
Content-Type: text/plain; name=\"stats.txt\"
Content-Transfer-Encoding: 8bit
Content-Disposition: inline; filename=\"stats.txt\" 

	   
"
	cat "/mnt/stats/bandwidth_usage/$stats_fname" | awk -v bw=8000000 -v params_start_time=`date -d "$datefmt" +%s` -f utils/getstats.awk | iconv -f koi8-r -t cp1251//IGNORE
	echo
	echo "--$boundary "

	} | /usr/sbin/sendmail -oi $2
