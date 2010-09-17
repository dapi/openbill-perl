#!/usr/bin/bash

/home/danil/projects/openbill/utils/check_traffic.sh > /tmp/check_traffic
grep LEAK /tmp/check_traffic | grep -v bridge140 | grep -v bridge18 | grep -v 128 > /tmp/traffic_alarm
if [ -s /tmp/traffic_alarm ]; then
		echo -e "Subject: TRAFFIC LEAK\n\n" > /tmp/alarm_message
		cat /tmp/check_traffic >> /tmp/alarm_message
		cat /tmp/alarm_message | sendmail admin@orionet.ru
fi
