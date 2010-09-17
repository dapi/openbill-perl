#!/usr/bin/bash
echo "Move: $1";
find . -name "$1" -type f -exec mv {} /mnt/stats/work_trafd/ \;

echo "Bunzipping..";
cd /mnt/stats/work_trafd
find . -name "*bz2" -type f -exec bunzip2 {} \;