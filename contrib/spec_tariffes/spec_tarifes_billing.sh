#!/bin/sh

CLIENTS_SRC=${1:-"spec_tariffes.txt"}

OBS_LOCAL="/home/danil/projects/openbill/bin/obs_local.pl"
OBS_ACCOUNT="-l littlesavage -p fRtb842vtG"
tmpfile="/tmp/spec_tarrifes.tmp"


if [ ! -s ${CLIENTS_SRC} ]; then
	echo "file  ${CLIENTS_SRC} not found" >&2
	exit 0
fi

(
echo "#date: `date`"

cat $CLIENTS_SRC | while read str; do
	case "$str" in
	"#"*) 
		echo $str
		;;
	'')
		echo
		;;
	*)
		echo "$str" | while read is_deactive client_id traff_limit bw_below bw_above pipe_in pipe_out comment; do

		user_traff=`$OBS_LOCAL $OBS_ACCOUNT show_client $client_id | awk -F "|" ' /Учтённый трафик/{ split($2, a, "[ ,]"); if(index(a[3],"Мб")){gsub("\`","",a[2]); printf("%i\n", a[2]);}  exit}' `

		if [ -z "$user_traff" ];then user_traff='0'; fi

		if [ $user_traff -gt ${traff_limit} ]; then
			is_deactive='1';
		else
			is_deactive='0';
		fi

		printf "$is_deactive\t$client_id\t$traff_limit\t$bw_below\t$bw_above\t$pipe_in\t$pipe_out\t$comment ($user_traff mb)\n"
		done
		;;
	esac
done ) > ${tmpfile}

if [ -s ${tmpfile} ]; then
	cat ${tmpfile} | /usr/bin/ssh -i /usr/local/openbill/var/keys/vpn.orionet.ru root@vpn.orionet.ru /usr/local/openbill/janitors/spec_tarifes_vpn.sh -
fi

