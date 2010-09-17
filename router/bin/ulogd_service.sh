#!/usr/bin/bash
. /usr/local/openbill/router/etc/ulog-conf.sh
echo "Start"
$ULOG_PROG -d -D -c $CONF_FILE || echo "Can't start daemon!"
