#!/usr/bin/bash
date=`date +"%Y-%m-%d-%H:%M"`
db="openbill"
file="$db-$date.sql"

/usr/local/mysql/bin/mysqldump -uopenbill -prerfhfxf $db \
 access_mode        activation_log     address            building          \
 charge             client             collector          host              \
 host_am            host_attach_log    invoice            janitor           \
 manager            message            message_log        notice            \
 payment            period             prov_router       \
 resource           router             router_collector   router_ip         \
 service            street             tariff             tariff_log        \
 building_holder    dealer             payment_method     \
 topic              user               manager_session   | grep -v "INSERT INTO manager_session" > $file
