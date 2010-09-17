#!/bin/sh

#Скрипт для смены скорости анлимщикам

fw="/sbin/ipfw -q"
logger="/usr/bin/logger -p local4.notice -t $0"

while read ip inb outb;
do {
	if [ -z "$ip" ]; then
		$logger "undefined ip"
		echo "DONE: ERROR" >&2
		exit 1;
	fi

	if [ -z "$inb" ]; then
		$logger "undefined inboud speed"
		exit 1;
	fi

	if [ -z "$outb" ]; then
		outb=$inb;
	fi

	#Интерфейс, на котором висит клиент с данным ип
	iface=`ifconfig -u | fgrep -B 1 "$ip " | awk -F ":" '/^ng/{print $1; exit}'`

	if [ -z "$iface" ]; then
		echo "DONE: OK" >&2
		exit
	fi

	#Номера пайпов клиента
	pipein=`$fw list 10000-50000 \
	| awk -v ng=$iface ' /^.+ pipe .+ in via/{if ($NF == ng) print $3}'`
	pipeout=`$fw list 10000-50000 \
	| awk -v ng=$iface ' /^.+ pipe .+ out via/{if ($NF == ng) print $3}'`

	#Скорости пайпов
	if [ ! -z "$pipein" ]; then
		spdin=`$fw pipe $pipein list | awk '{printf "%i\n", $2; exit}'`
	else
		spdin="unlim"
	fi

	if [ ! -z "$pipeout" ]; then
		spdout=`$fw pipe $pipeout list | awk '{printf "%i\n", $2; exit}'`
	else
		spdout="unlim"
	fi

	#Если первый параметр - show, просто показываем скорости.
	#Считаем что с параметрами скрипт не будет запускаться из биллинга.
	if [ "$1" = "show" ]; then
		echo "$ip	in: $spdin  out: $spdout"
		exit
	fi

	$logger "ip: $ip spdin: $spdin spdout: $spdout new_spdin: $inb new_spdout: $outb"

	case "$inb" in
		"0" )
		# Выключаем клиента
		${fw} table 84 add ${ip} | $logger
		;;
		* )
		${fw} table 84 delete ${ip} | $logger
		${fw} pipe $pipein config bw $inb | $logger	
		${fw} pipe $pipeout config bw $outb | $logger	
		;;
	esac
}
done

echo "DONE: OK" >&2
exit
