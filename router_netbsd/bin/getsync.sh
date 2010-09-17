#!/bin/sh

TMP=/tmp/sync/

# Очищаем от старых остатков
rm -fr $TMP ; mkdir $TMP

if tar xf - -C $TMP; then
 echo "RECEIVE: done" >&2
 /etc/orionet/bin/dosync.pl
 rm -fr $TMP
 exit $?
fi

echo "ERROR: tar" >&2
exit $?
