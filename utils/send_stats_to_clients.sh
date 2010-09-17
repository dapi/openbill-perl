#!/usr/bin/bash
/home/danil/projects/openbill/utils/check_traffic.sh month=today | grep bridge140 | sendmail stat_ucomm@orionet.ru
#/home/danil/projects/openbill/utils/check_traffic.sh | sendmail admin@orionet.ru
#/home/danil/projects/openbill/utils/check_traffic.sh router=14 group=client,class month=today | sendmail petrova_6@orionet.ru
#/home/danil/projects/openbill/utils/check_traffic.sh month=today | grep rc_cl6 | sendmail petrova_6@orionet.ru
#/home/danil/projects/openbill/utils/check_traffic.sh month=today | grep rc_cl5 | sendmail petrova_6@orionet.ru
#/home/danil/projects/openbill/utils/check_traffic.sh month=today | grep rc_cl4 | sendmail petrova_6@orionet.ru
