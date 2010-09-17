#!/bin/bash

cd /home/danil/projects/openbill/var/keys/
shopt -s extglob
#for key in bridge+([0-9]); do
for key in bridge3 bridge5 bridge7 bridge8 bridge9 bridge11 bridge15 bridge19 bridge20 bridge22 bridge23 bridge24 bridge25 bridge26 bridge27 bridge28 bridge29 bridge32 bridge35 bridge36 bridge37; do
  echo "$key:"
  ssh -oProtocol=2 -C -i $key root@$key "$@"
  res=$?
  if [ "$res" -gt 0 ]; then
     echo "! Error is $res"
  else
    echo ""
  fi
done
