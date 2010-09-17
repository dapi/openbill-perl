#!/usr/bin/bash

ROOT=/usr/local/openbill
KEYS_PATH=$ROOT/var/keys
#cd /home/danil/projects/openbill/var/keys/

shopt -s extglob

#routers="bridge2 bridge4 bridge5 bridge6 bridge7 bridge8 bridge9 bridge10 bridge11 bridge12 bridge14 bridge15 bridge16 bridge17 bridge19 bridge20 bridge21 bridge22 bridge23 bridge24 bridge25 bridge27 bridge128"
routers="bridge14";
cp -vr $ROOT/checkhost/* $ROOT/var/linux_router/etc/orionet/
for router in $routers; do
  echo "Copying to $router"
  rsync -e "ssh -oProtocol=2 -C -i $KEYS_PATH/$router" -avq $ROOT/var/linux_router/ root@$router:/
done
# --delete --force
# /mnt/www/mirror/ mirror@mirror.orionet.ru:/usr/local/nginx/www/mirror.orionet.ru/
