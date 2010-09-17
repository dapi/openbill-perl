#!/usr/bin/bash
/usr/local/openbill/sbin/archivelogs.pl /mnt/stats/archive_trafd/ /mnt/stats/history/
/usr/local/openbill/sbin/archivelogs.pl /mnt/stats/archive/ /mnt/stats/history/
/home/danil/projects/openbill/bin/obs.pl -l checker -p rjsalxzcjsad delete_old_traffic force=1