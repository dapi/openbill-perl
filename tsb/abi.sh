#!/bin/sh
echo "$@" >> /var/log/abi.log

/usr/local/openbill/bin/obs.pl -e 1 -l sberbank -p masspay tsb $@ | iconv -f koi8-r -t cp1251 | grep -v "Exit with result:"
#echo "result: $res" >> /var/log/abi.log
#echo $res
