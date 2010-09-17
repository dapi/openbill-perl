#!/bin/sh
#������ ��� ����������� �������� ��� ���������� ������� �������� �� ���� ��������,
#��� ������� �� ���� �������� ���� ������� � �����.
#���������:
#1. ��� �������� ���
#2. ��� ���������� ���� �� �������� � ��������
#3. ����������� ����� �� ������� �� �����


#���� � ����� �� �������� �� ���� ��������. ����������� � ��������
#������: #�����_��������(1/0) #������� �����_�������_�� bw_��_������_kbps bw_�����_kbps pipe_in pipe_out comment
#���� #�������,�����_������� � comment �� ������������
spec_tarifes_file="/usr/local/etc/spec_tariffes.txt"
spec_tarifes_file_bak="/usr/local/etc/spec_tariffes.txt.bak"

fw="/sbin/ipfw -q"
logger="/usr/bin/logger -p local4.notice -t $0"

update_rules ()
{
	if [ ! -s ${spec_tarifes_file} ]; then
		$logger "spec_tarifes file not found: ${spec_tarifes_file}"
		return 1
	fi
	
	cat ${spec_tarifes_file} | awk  \
		'
		/^#.*/{next}
		NF>=7{ 
			bw = ($1 == "0")?$4:$5;
			pipe_in = $6;
			pipe_out = $7;
			printf("%i %i %i\n", pipe_in, pipe_out, bw);
		}' | while read pipe_in pipe_out bw;
	do
		$fw pipe $pipe_in config bw ${bw}Kbit/s | $logger
		$logger "$fw pipe $pipe_in config bw ${bw}Kbit/s"
		$fw pipe $pipe_out config bw ${bw}Kbit/s
		$logger "$fw pipe $pipe_out config bw ${bw}Kbit/s"
	done
}



$logger "sync_tarrifes"
if [ ! -z "$1" ]; then
	cp -f $spec_tarifes_file $spec_tarifes_file_bak
	cat $1 > $spec_tarifes_file
fi

update_rules

