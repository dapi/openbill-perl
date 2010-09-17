#!/bin/sh
#
# $FreeBSD: ports/databases/postgresql82-server/files/502.pgsql,v 1.8 2006/12/06 16:48:57 girgen Exp $
#
# Maintenance shell script to vacuum and backup database
#
# Written by Palle Girgensohn <girgen@pingpong.net>
#
# In public domain, do what you like with it,
# and use it at your own risk... :)
#

# Define these variables in either /etc/periodic.conf or
# /etc/periodic.conf.local to override the default values.
#
# daily_pgsql_backup_enable="YES" # do backup
# daily_pgsql_vacuum_enable="YES" # do vacuum

daily_pgsql_vacuum_enable="NO"
daily_pgsql_backup_enable="YES"
daily_pgsql_remote_backup_enable="YES"

daily_pgsql_vacuum_args="-z"
daily_pgsql_pgdump_args="-b -F c"

daily_pgsql_backupdir="/mnt/stats/backup/pgsql"
daily_pgsql_savedays="20"

daily_pgsql_user="postgres" # pgsql in freebsd

#remote backup
daily_pgsql_remote_backupdir="/usr/local/backups/pgsql/`hostname`/"
daily_pgsql_remote_backuphost="vpn.orionet.ru"
daily_pgsql_my_secret_key="/usr/local/openbill/var/keys/vpn.orionet.ru"

# If there is a global system configuration file, suck it in.
#
if [ -r /etc/defaults/periodic.conf ]
then
    . /etc/defaults/periodic.conf
    source_periodic_confs
fi

if [ -r /usr/local/openbill/etc/openbill.conf ]
then
   . /usr/local/openbill/etc/openbill.conf
fi

# allow '~´ in dir name
eval backupdir=${daily_pgsql_backupdir}
eval remote_backupdir=${daily_pgsql_remote_backupdir}

rc=0

case "$daily_pgsql_backup_enable" in
    [Yy][Ee][Ss])

	# daily_pgsql_backupdir must be writeable by user pgsql
	# ~pgsql is just that under normal circumstances,
	# but this might not be where you want the backups...
	if [ ! -d ${backupdir} ] ; then 
	    echo Creating ${backupdir}
	    mkdir ${backupdir}; chmod 700 ${backupdir}; chown ${daily_pgsql_user} ${backupdir}
	fi

	echo
	echo "PostgreSQL maintenance"

	# Protect the data
	umask 077
	dbnames=`su -l ${daily_pgsql_user} -c "psql -q -t -A -d template1 -c SELECT\ datname\ FROM\ pg_database\ WHERE\ datname!=\'template0\'"`
	rc=$?
	now=`date "+%Y-%m-%d-%H_%M"`
	file=${daily_pgsql_backupdir}/pgglobals_${now}
	su -l ${daily_pgsql_user} -c "pg_dumpall -g | gzip -9 > ${file}.gz"
	created_files="${file}.gz"
	for db in ${dbnames}; do
	    echo -n " $db"
	    file=${backupdir}/pgdump_${db}_${now}
	    su -l ${daily_pgsql_user} -c "pg_dump ${daily_pgsql_pgdump_args} -f ${file} ${db}"
	    [ $? -gt 0 ] && rc=3
	    created_files="${created_files} ${file}"
	done

	if [ $rc -gt 0 ]; then
	    echo
	    echo "Errors were reported during backup."
	fi

	# cleaning up old data
	find ${backupdir} \( -name 'pgdump_*' -o -name 'pgglobals_*' \) \
	    -and -mtime +${daily_pgsql_savedays} -delete

	case "$daily_pgsql_remote_backup_enable" in
		[Yy][Ee][Ss])
			echo
			echo "PostgreSQL remote backup"
			scp -o Protocol=2 -i${daily_pgsql_my_secret_key} $created_files  \
				${daily_pgsql_remote_backuphost}:${remote_backupdir}
			#remote cleanup
			ssh -o Protocol=2 -i${daily_pgsql_my_secret_key} ${daily_pgsql_remote_backuphost} \
				find ${remote_backupdir} -mtime +${daily_pgsql_savedays} -delete
		;;
	esac

	;;
esac

case "$daily_pgsql_vacuum_enable" in
    [Yy][Ee][Ss])

	echo
	echo "vacuuming..."
	su -l ${daily_pgsql_user} -c "vacuumdb -a -q ${daily_pgsql_vacuum_args}"
	if [ $? -gt 0 ]
	then
	    echo
	    echo "Errors were reported during vacuum."
	    rc=3
	fi
	;;
esac

exit $rc
