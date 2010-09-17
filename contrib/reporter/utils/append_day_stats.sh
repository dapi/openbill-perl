#!/bin/sh

#$1 - date (2007-10-01)

utils/get_stats.sh day $1 -3 >> /mnt/stats/bandwidth_usage/stats-${1:0:7}.txt
