#!/usr/bin/bash

OBS_ROOT='/usr/local/openbill'
OBR_ROOT="$OBS_ROOT/router"
FW_ROOT='/usr/local/openbill/router/firewall'
FW_CONF="$OBR_ROOT/etc/firewall.conf"

TRAFD_LOG_DIR='/var/trafd/'
TRAFD_ARC_DIR='/var/trafd/arc/'
TRAFD_TOSEND_DIR='/var/trafd/tosend/'

DHCPD_INC_FILE="$OBR_ROOT/etc/dhcpd.inc.conf"
#LOG_DIR="$DIR/log/";  test -d $LOG_DIR || mkdir $LOG_DIR  >&2
#ARC_DIR="$DIR/archive/";  test -d $ARC_DIR || mkdir $ARC_DIR  >&2
ACCOUNT="$DIR/account.log"
TEMP_DIR="/tmp/openbill_hosts/"; test -d $TEMP_DIR || mkdir $TEMP_DIR  >&2
OK_FILE="${TEMP_DIR}ok"

hostname=`hostname`

sleep_time=1 # Время которое система спит

ETHERS_FILE="$OBR_ROOT/etc/ethers"
