# Copyright (c) 2007 orionet.ru 
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# Contributors
# ============
# 2007 Alexey Illarionov <littlesavage@orionet.ru>
#
#

#XXX: gawk
#usage: cat file_stats | gawk -f getstats.awk
#�� ����� ������� �������� ����� ����:
#format: time    other                   unlim_256               unlim_64
#1190232000      82748767.0/227410819.0  207710.0/1508221.0      26767135.0/113016144.0 
#1190235600      47851412.0/153985090.0  161486.0/1220354.0      23645962.0/118514520.0
#format: time other
#1190232000      82748767.0/227410819.0
#1190235600      47851412.0/153985090.0
#...
#������ ������ (format: ) - ������ ��������
#������ ������� - ����� � unix time.
#��������� - ������ � ������: ��������/���������
#
#������ ������������ ��� ��� ���� � ������� �������
#������������� ������� �� ������ ���.
#������� �������� ��������� � ���������� � � % ��
#����������� ���������� ������� ��� ������ ������ bw ���

BEGIN{
	# ������ ������ � �����
	if (bw == 0)
		bw = 4000000;
	columns[0] = "time";
}

# ���������� ��������
/^#/{
	next;
}

NF <= 1{
	next;
}

#
# ������ ������������ � format: �������� ��� ����� �������� �����
# ����: format: time    other   unlim_256       unlim_64        unlim_128 ...
# ��� ����� �������� � columns (columns[0] = "time", columns[1] = "other" ...)
# ������ ������� ������ ���� "time"  - unix time �����
#
/format: /{
	if ($2 != "time"){
		print "format: first column is not time";
		exit;
	}
	for ( fld = 3; fld <= NF; fld++ ) {
		columns[fld-1] =$fld 
		columns_txt[$fld] = 1;
	}
	next
}


#start_time - ����������� ������������� �����
#end_time - ������������
function update_start_end_time(time)
{
	if ( (time < start_time) || (start_time == 0))
		start_time = time;
	if ( time > end_time )
		end_time = time;
}

#������ ���� ���������
{
	# %u - ���� ������ (1 �� - 7 ���), %H - ��� (0 - 23)
	weekday_num = strftime("%u", $1);
	hour_num = strftime("%H", $1);

	if (weekday_num < 1 || weekday_num > 7) {
		printf ("unknown time (weekday_num). num = %u, str: %s\n", weekday_num, $0);
		exit
	}

	if ( hour_num < 0 || hour_num > 23) {
		printf ("unknown time (hour_num). num = %u, str: %s\n", hour_num, $0);
		exit
	}

	#����������� params_start_time � params_end_time ����� ������ ����������� �� �������
	#�� ������� ����� ������������� ����������.
	#����� ������ ���� � unix timestamp.
	if (($1 < params_start_time) || ( params_end_time && ($1 > params_end_time) ))
		next;

	update_start_end_time($1);

	for (f = 2; f <= NF; f++) {
		column_name = columns[f];
		if ( column_name == "") {
			printf ("unknown column name. column_num: %u, str: %s\n", f, $0);
			exit
		}
		if ( split ($f, inout, "/") != 2 ) {
			printf("unknown value. value: %s, string: %s\n", $f, $0);
			exit
		}
		if ( (weekday_num == 6) || (weekday_num == 7)) {
			weekends_out[column_name, hour_num] += inout[1];
			weekends_in[column_name, hour_num] += inout[2];
			weekends_counts[column_name, hour_num] += 1;
		}else {
			weekdays_out[column_name, hour_num] += inout[1];
			weekdays_in[column_name, hour_num] += inout[2];
			weekdays_counts[column_name, hour_num] += 1;
		}
		day_stat_out[column_name, hour_num] = inout[1];
		day_stat_in[column_name, hour_num] = inout[2];
		day_stat_counts[column_name, hour_num] += 1;
	}
}

function bytes2percents(bytes, bandwidth, print_percents)
{
	if ( print_percents )
		return (100*bytes)/(3600*bandwidth/10);
	else
		return bytes / 1000000000;
}

function print_day_arr(str, arr, arr_counts, print_percents)
{
	printf("%s", str);
	printf("time\t");
	
	arr_size = 0;

	# ��������� ������ ��������, ����� for var in array ���������� �� � ���������� �������
	for ( col_name in columns_txt)
	    col_names[++arr_size] = col_name;    
	asort(col_names);
	    
	# �����
	for (i = 1; i <= arr_size; i++ )
	    printf("%s\t", col_names[i]);
	printf("summ\n");

	for (h = 0; h <= 23; h++) {
	    summ=0.0;
	    hh = sprintf ("%.2u", h);
	    printf("%s\t", hh);
	    for ( i = 1; i <= arr_size; i++){
		    if ( arr_counts[col_names[i], hh] == 0 )
			    val = -1;
		    else
			    val = arr[col_names[i], hh] / arr_counts[col_names[i], hh];
		    summ += val;
		    printf ("%2.2f\t", bytes2percents(val,bw,print_percents));
	    }
	    printf("%2.2f\n", bytes2percents(summ, bw, print_percents));
	}
	printf("\n");
}

function print_stats()
{

	# ������������ ��� ������� 2 ����
	if ( end_time - start_time < 60*60*2){
		printf "no enough data\n"
		return
	}else
	if (end_time - start_time < 60*60*26) {
		printf ("���������� �� 1 ����.\tC: %s\t��: %s\n", strftime("%c", start_time), strftime("%c",end_time));
		print_day_arr("�������� ������ (� %)\n", day_stat_in, day_stat_counts, 1);
		print_day_arr("�������� ������ (� ����������)\n", day_stat_in, day_stat_counts, 0);
		print_day_arr("��������� ������ (� %)\n", day_stat_out, day_stat_counts, 1);
		print_day_arr("��������� ������ (� ����������)\n", day_stat_out, day_stat_counts, 0);
	}else {
		printf ("���������� \tC: %s\t��: %s\n", strftime("%c", start_time), strftime("%c",end_time));
		print_day_arr("�����. �������� ������ (� %)\n", weekdays_in, weekdays_counts, 1);
		print_day_arr("�����. �������� ������ (� ����������)\n", weekdays_in, weekdays_counts, 0);
		print_day_arr("�����. ��������� ������ (� %)\n", weekdays_out, weekdays_counts, 1);
		print_day_arr("�����. ��������� ������ (� ����������)\n", weekdays_out, weekdays_counts, 0);

		print_day_arr("��������. �������� ������ (� %)\n", weekends_in, weekends_counts, 1);
		print_day_arr("��������. �������� ������ (� ����������)\n", weekends_in, weekends_counts, 0);
		print_day_arr("��������. ��������� ������ (� %)\n", weekends_out, weekends_counts, 1);
		print_day_arr("��������. ��������� ������ (� ����������)\n", weekends_out, weekends_counts, 0);
	}
}


END{
	print_stats();
}

