#!/usr/bin/bash

ROOT=/usr/local/openbill
KEYS_PATH=$ROOT/var/keys

shopt -s extglob
#for key in bridge6; do
src=$1
dst=$2
#excluded bridge26
# Нет бриджей:
# bridge18 - яркая жазинь
# bridge19 - калинина чердак
routers="vpn.orionet.ru bridge3 bridge4 bridge5 bridge7 bridge8 bridge9 bridge10 bridge11 bridge15 bridge16 bridge19 bridge20 bridge21 bridge22 bridge23 bridge24 bridge25 bridge26 bridge27 bridge28"
for router in $routers; do
  echo "Copying to $router"
  /usr/local/bin/scp -r -oProtocol=2 -C -i $KEYS_PATH/$router $src root@$router:$dst
#  /usr/local/bin/scp -oProtocol=2 -C -i $key $@ root@$key:/etc/orionet/bin/
#  echo -e "Result is $?\n"

done
