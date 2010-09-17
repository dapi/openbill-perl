#!/bin/sh

#Некоторые запроссы, выполняемые напрямую к базе
MYSQL="/usr/bin/mysql -u openbill -ppfrjkljdfyysq orionet -NB "

#Все ип адреса хостов - юр лиц
GET_ISFIRM_HOSTS='select host.client_id,INET_NTOA(host.ip) AS ip
		  from host left join client on (client.client_id=host.client_id)
		  where client.is_removed=0 and host.is_removed=0 and client.is_firm=1;'

#Все клиенты: #клиента, адрес, баланс. XXX: зачем тут chrage? :)
GET_ALL_CLIENTS='select distinct client.client_id,client.name,client.firmname,
			street.name,building.number,address.room,client.is_firm,client.balance
		from charge
		left join client on client.client_id=charge.client_id
		left join address on address.address_id=client.address_id
		left join building on address.building_id=building.building_id
		left join street on building.street_id=street.street_id
		where client.is_removed=0 order by client_id;'

#Все клиенты + суммы их начислений кааждый месяц за последние 3 месяца (сентябрь-октябрь-ноябрь 2007).
GET_ALL_CLIENTS_PAYMENTS='
		SELECT client.client_id,client.name,client.firmname,
			street.name,building.number,
			address.room,ROUND(client.balance),
			IFNULL(ROUND(summs_09.summa),0)  AS summ_09,
			IFNULL(ROUND(summs_10.summa),0)  AS summ_10,
			IFNULL(ROUND(summs_11.summa),0)  AS summ_11
		FROM client
		LEFT JOIN ( SELECT client_id,SUM(payment.summa) AS summa
		   FROM payment WHERE date BETWEEN "2007-09-01" and "2007-09-31"
		   GROUP BY client_id ) AS summs_09
		  ON client.client_id=summs_09.client_id
		LEFT JOIN ( SELECT client_id,SUM(payment.summa) AS summa
		   FROM payment WHERE date BETWEEN "2007-10-01" and "2007-10-31" 
		   GROUP BY client_id ) AS summs_10
		  ON client.client_id=summs_10.client_id
		LEFT JOIN ( SELECT client_id,SUM(payment.summa) AS summa
		   FROM payment WHERE date BETWEEN "2007-11-01" and "2007-11-31"
		   GROUP BY client_id ) AS summs_11
		  ON client.client_id=summs_11.client_id
		LEFT JOIN address on address.address_id=client.address_id
		LEFT JOIN building on address.building_id=building.building_id
		LEFT JOIN street on building.street_id=street.street_id
		WHERE client.is_removed=0 ORDER BY client_id;'

#Все клиенты на радио (client_id name firmname address balance)
GET_ALL_RADIO_CLIENTS='SELECT host.client_id,host.router_id,client.name,client.firmname,
		street.name,
		building.number,address.room,ROUND(client.balance)
		FROM host
		LEFT JOIN client ON client.client_id=host.client_id
		LEFT JOIN address ON address.address_id=client.address_id
		LEFT JOIN building on address.building_id=building.building_id
		LEFT JOIN street on building.street_id=street.street_id
		WHERE client.is_removed=0 AND client.status_id!=4 AND host.is_vpn=0 AND host.router_id!=5 AND host.router_id!=36
		GROUP BY host.client_id,host.router_id
		ORDER BY host.client_id;'

GET_ALL_CLIENTS_LAST_NEGATIVE_TIME='
		SELECT payment.client_id,DATE(date) AS last_negative
		FROM payment 
		WHERE balance < 0
		GROUP BY payment.client_id 
		ORDER_BY client_id,date DESC
'


mysql_output_format="-B"

usage()
{
	echo
	echo "usage: `basename $0` [-e email] [-xch]"
	echo "-h	list hosts of all firms (client_id - firm)"
	echo "-c	list all clients"
	echo "-p	list client payments for last 3 month"
	echo "-r	list all clients on radio"
	echo "-x	xml output"
	echo "-e email	send result to email (broken)"
}

list_all_clients()
{
	$MYSQL $mysql_output_format -e "$GET_ALL_CLIENTS"
}

list_all_radio_clients()
{
	$MYSQL $mysql_output_format -e "$GET_ALL_RADIO_CLIENTS"
}

list_all_firm_hosts()
{
	$MYSQL $mysql_output_format -e "$GET_ISFIRM_HOSTS" | sort -n -k 1
}

get_client_payments()
{
	$MYSQL $mysql_output_format -e "$GET_ALL_CLIENTS_PAYMENTS"
}

output_result()
{
	email=$1

	if [ -z "$email" ]; then
		while read str; do
			echo "$str"
		done
	fi

}

if [ $# -lt 1 ]; then
	usage
	exit
fi

while getopts "chxie:pr" command; do
	case $command in
		x) mysql_output_format="-X" ;;
		c) list_all_clients | output_result $send_to_email;;
		h) list_all_firm_hosts | output_result $send_to_email ;;
		e) send_to_email=$GETOPT;;
		p) get_client_payments;;
		r) list_all_radio_clients | output_result $send_to_email;;
		*) usage;;
	esac
done


