#!/bin/sh

mysql -u openbill -p orionet -Bne "select host.client_id,INET_NTOA(host.ip) AS ip from host left join client on (client.client_id=host.client_id) where client.is_removed=0 and host.is_removed=0 and client.is_firm=1;" | sort -n -k 1
