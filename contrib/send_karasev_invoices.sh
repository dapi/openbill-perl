#!/bin/bash

#$1 - month (2007.07)
#$2 - e-mail (ek@orionet.ru)
{
	boundary='simple boundary';
	echo "To: $2
From: root@billing.orionet.ru
Subject: $1 Invoices
Content-Type: multipart/mixed; boundary=\"$boundary\"
	 
This is a multi-part message in MIME format. 
--$boundary 
Content-Type: text/plain; charset=KOI8-R; format=flowed
Content-Transfer-Encoding: 8bit


Invoices. Date: $1


--$boundary 
Content-Type: text/plain; name=\"invoices.firm.txt\"
Content-Transfer-Encoding: 8bit
Content-Disposition: inline; filename=\"invoices.firm.txt\" 

	   
"
	/home/danil/projects/openbill/bin/obs_local.pl -l littlesavage -p fRtb842vtG list_charges month=$1 is_firm=1 tab=1 | iconv -f koi8-r -t cp1251//IGNORE | tail -n +3 

echo "
--$boundary 
Content-Type: text/plain; name=\"invoices.individual.txt\"
Content-Transfer-Encoding: 8bit
Content-Disposition: inline; filename=\"invoices.individual.txt\" 

"
	/home/danil/projects/openbill/bin/obs_local.pl -l littlesavage -p fRtb842vtG list_charges month=$1 is_firm=0 tab=1 | iconv -f koi8-r -t cp1251//IGNORE | tail -n +3 

echo
echo "--$boundary "

	} | /usr/sbin/sendmail -oi $2
