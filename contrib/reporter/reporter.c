/*-
 * Copyright (c) 2007 orionet.ru 
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * Contributors
 * ============
 * 2007 Alexey Illarionov <littlesavage@orionet.ru>
 *
 */

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#include <errno.h>
#include <ctype.h>
#include <limits.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>
#include "radix.h"

#define MAX_GROUP_CNT 32
#define MAX_HOUR_CNT 31*24


struct t_ip_group {
	int num;
	const char *name;
	/* Значения трафика за 1 месяц за каждый час*/
	double traf_inb[MAX_HOUR_CNT];
	double traf_outb[MAX_HOUR_CNT];
};

struct table_entry {
	struct radix_node       rn[2]; 
	struct sockaddr_in      addr, mask;
	unsigned num;
	/* Флаг, устанавливается когда данный ип засветился в передаче к другой группе (локальный трафик) */
	unsigned flag_local;
};

struct t_ip_groups {
	struct radix_node_head *ips;
	/* Массив со статистикой по каждой группе */
	struct t_ip_group grp[MAX_GROUP_CNT];
	/* Номер последнего неициализированного элемента в массиве grp */
	int max;
	/* Время (час) которому соответствует 0 индекс в traf_inb и traf_outb */
	time_t start;
	/* Максимальный индекс traf_inb и traf_outb */
	int traf_max;

	/* Ширина канала, в битах */
	double bw;
#define MAX_MB_PER_HOUR(_bw) ( (60*60*(_bw))/(10*1000*1000)  )
#define BW_HOUR_BYTES_PERCENT(_bytes, _bw) ( ((100*(_bytes))/((3600*(_bw))/10)) )
};

void 
usage()
{
	printf("\nusage:  reporter [-12] [-c ip.cfg] [-f logfile]  \n\n"
		"-c file	- config with local ip's\n"
		"-f file	- logfile\n"
		"-m Mbit/s 	- channel bandwidth, Mbit per second (default: 4)\n"
		"-1		- print report1 (full log)\n"
		"-2		- print report2 (hour log)\n"
		"-3		- print report3 (unfirmatted report1)\n"
		);
}

time_t
tai642time_t(const char *tai)
{
	unsigned long long ull;
	time_t res;
	char *endptr;
	char s[17];

	if (tai == NULL)
		return (time_t)-1;

	if ((strlen(tai) != 25)
		|| tai[0] != '@')
		return (time_t)-1;

	endptr = (char *)tai;

	memcpy(s, &tai[1], 16);
	s[16] = '\0';
	ull = strtoull(s, &endptr, 16);
	if ( *endptr != '\0' )
		return (time_t)-1;
	ull -= 4611686018427387914ULL;

	res = (time_t)ull;

	return res;
}

/* Преобразование времени в индекс (возвращает кол-во часов между start и date) */
inline int
time2idx(time_t start, time_t date)
{
	double diff;

	if ( (start == (time_t)-1) || (date == (time_t)-1) )
		return (time_t)-1;
	if (date < start)
		return (time_t)-1;

	diff = difftime(date, start);

	return diff/3600.0;
}

time_t
idx2time(time_t start, int idx)
{
	double diff;

	diff = idx * 3600.0;

	return (time_t)start+diff;
}

int
find_n_init_group(struct t_ip_groups *groups, int gr_num)
{
	int i, j;

	if ( groups == NULL) 
		return -1;

	if ( gr_num > MAX_GROUP_CNT)
		return -1;

	if (groups->max > MAX_GROUP_CNT) {
		fprintf(stderr, "assert filed: groups->max >= MAX_GROUP_CNT");
		return -1;
	}

	if (groups->max == MAX_GROUP_CNT) {
		fprintf(stderr, "too much groups");
		return -1;
	}

	for (i = 0; i < groups->max; i++)
		if (groups->grp[i].num == gr_num)
			return i;

	/* Если группа не найдена, инициализируем новую */
	i = groups->max;
	groups->max++;
	groups->grp[i].num = gr_num;
	groups->grp[i].name = strdup("unnamed");
	for (j = 0; j < MAX_HOUR_CNT; j++) {
		groups->grp[i].traf_inb[j] = 0.0;
		groups->grp[i].traf_outb[j] = 0.0;
	}
	
	if ( groups->grp[i].name != NULL)
		return i;
	else
		return -1;

}

int lookup_ip(const struct t_ip_groups *groups, struct in_addr ip, int *flag_local)
{
	struct sockaddr_in sa;
	struct table_entry *ent;
	struct radix_node_head *rnh;

	*((uint8_t *)&sa) = 8;
	sa.sin_addr = ip;
	rnh  = groups->ips;
	ent = (struct table_entry *)(rnh->rnh_lookup(&sa, NULL, rnh));
	if ( ent != NULL ) {
		if (flag_local)
			*flag_local = ent->flag_local;
		return ent->num;
	}

	return -1;
}

void
set_local_flag(const struct t_ip_groups *groups, struct in_addr ip, int flag_local)
{
	struct sockaddr_in sa;
	struct table_entry *ent;
	struct radix_node_head *rnh;

	*((uint8_t *)&sa) = 8;
	sa.sin_addr = ip;
	rnh  = groups->ips;
	ent = (struct table_entry *)(rnh->rnh_lookup(&sa, NULL, rnh));
	if ( ent != NULL ) {
		ent->flag_local = flag_local;
	}

	return ;
}

int
add_group_entry(struct t_ip_groups *groups, unsigned gr_num, const unsigned char *val)
{
	const char *str;
	struct sockaddr_in addr; 
	int gr_idx;
	uint8_t masklen;

	masklen = 0;
	
	gr_idx = find_n_init_group(groups, gr_num);

	if (gr_idx < 0) {
		fprintf(stderr, "can not init group on str %s", val);
		return -3;
	}

	str = strdup(val);
	/* Если первый символ второго поля - цифра, считаем что это ип адрес. Иначе - имя группы */
	if ( isdigit((int)str[0])) {
		/* поле - ип адрес */
		char *s_mask;
		s_mask = strpbrk(str, "/");
		if ( s_mask ) {
			*s_mask = '\0';
			masklen = atoi(s_mask+1);

			if ( masklen > 32) {
				fprintf(stderr, "wrong mask on str %s\n", val);
				free((void *)str);
				return -2;
			}
		}else
			masklen=32;

		if (inet_aton(str, &addr.sin_addr) == 0) {
			fprintf(stderr, "wrong ip addr %s\n", val);
			free((void *)str);
			return -1;
		}

		/* Добавляем ип с маской к группе */
		{
			struct table_entry *ent;
			struct radix_node_head *rnh;

			ent = malloc(sizeof(*ent));
			if (ent == NULL) {
				fprintf(stderr, "no memory");
				free((void *)str);
				return -4;
			}
			*((uint8_t *)&ent->addr) = 8; /* Первый байт в структуре - размер ключа (см. radix.c) */
			*((uint8_t *)&ent->mask) = 8;
			ent->mask.sin_addr.s_addr = htonl(masklen ? ~((1 << (32 - masklen)) - 1) : 0);
			ent->addr.sin_addr.s_addr = addr.sin_addr.s_addr & ent->mask.sin_addr.s_addr;
			ent->num = gr_idx;
			ent->flag_local = 0;

			rnh  = groups->ips;
			if ( rnh->rnh_addaddr(&ent->addr, &ent->mask, rnh, (void *)ent) == NULL ) {
				fprintf(stderr, "cannot add addr");
				free(ent);
				free((void *)str);
				return -5;
			}
		}

	}else {
		/* поле - имя группы */
		free((void *)groups->grp[gr_idx].name);
		groups->grp[gr_idx].name = strdup(str);
	}

	free((void *)str);
	return 0;
}

int
load_ip_config(FILE *f, struct t_ip_groups *groups)
{
	unsigned i;
	unsigned strnum;
	char s[200];

	if ( f == NULL) {
		fprintf(stderr, "load_ip_config: f is  NULL\n");
		return -1;
	}

	for ( i = 0; i < MAX_GROUP_CNT; i++) {
		groups->grp[i].name = NULL;
		groups->grp[i].num = -1;
	}

	groups->max = 0;
	groups->start = (time_t)-1;
	groups->traf_max = 0;

	/* Парсерим файл */

	for ( strnum = 1; fgets (s, sizeof(s), f) != NULL; strnum++) {
		char *start, *field2;
		unsigned long gr_num;

		start = (unsigned char *)s;

		/* Пропускаем комментарии и пустые строки*/
		while ( start[0] && isspace((int)start[0]) )
			start++;

		if ( (start[0] == '\0') 
				|| (start[0] == '#')
				|| (start[0] == ';')
		   )
			continue;

		field2 = NULL;
		/* Первое поле - номер группы */
		gr_num = strtoul(start, &field2, 10);

		if (start == field2) {
			fprintf(stderr, "field 1 is not group number  on line %u", strnum);
			return -2;
		}

		/* Ограничиваем номер группы сверху значением MAX_GROUP_CNT, не смотря на то что
		 * номера групп хранится в элментах groups->grp, и этого можно было бы и не делать */
		if ( gr_num < 1 || gr_num > MAX_GROUP_CNT ) {
			fprintf(stderr, "wrong group number(%lu) on line %u", gr_num, strnum);
			return -3;
		}

		if ( isspace((int)field2[0]) == 0 ) {
			fprintf(stderr, "unknown symbols after group number on line %u", strnum);
			return -4;
		}

		while (field2[0] && isspace((int)field2[0])) field2++;


		if (field2[0] == '\0') {
			fprintf(stderr, "no group definition on line %u", strnum);
			return -5;
		}

		for (i = strlen(field2) - 1; i && isspace((int)field2[0]); i--)
			field2[0] = '\0';

		if ( add_group_entry(groups, gr_num, field2) < 0 ) {
			fprintf(stderr, "cannot add group on line %u", strnum);
			return -6;
		}
	}

	if ( feof(f) == 0 ) {
		fprintf(stderr, "config error. line %u", strnum);
		return -2;
	}

	return 0;

}

inline int
add_logfile_entry(time_t date,
		struct in_addr src_ip,
		unsigned long src_port,
		struct in_addr dst_ip,
		unsigned long dst_port,
		double packets,
		double bytes,
		struct t_ip_groups *groups
		)
{
	char date_str[80];
	int src_grp, dst_grp;
	int traf_idx;
	int flag_local1, flag_local2;

	/* Если начальное время еще неопределено, берем его из перой строки */
	if (groups->start == (time_t)-1) {
		struct tm t;
		/* Округляем время на начало часа */
		localtime_r(&date, &t);
		t.tm_sec = 0;
		t.tm_min = 0;
		groups->start = mktime(&t);
		if ( groups->start == (time_t)-1 ) {
			fprintf(stderr, "cannot convert time\n");
			return -1;
		}
	}


	traf_idx = time2idx(groups->start, date);
	if ( traf_idx < 0 || traf_idx >= MAX_HOUR_CNT) {
		ctime_r(&groups->start, date_str);
		date_str[24]='\0';
		fprintf(stderr, "timedate out of range +Start time: %s, max num hour: %u\n", date_str, MAX_HOUR_CNT);
		return -2;
	}
	/* Максимальный индекс для опеределения с какого и по какое время выдавать результат */
	if ( groups->traf_max < traf_idx)
		groups->traf_max = traf_idx;

	src_grp = lookup_ip(groups, src_ip, &flag_local1);
	dst_grp = lookup_ip(groups, dst_ip, &flag_local2);

	if ( (src_grp == -1) && (dst_grp >= 0) ) {
		/* Входящий трафик (к клиенту) */
		groups->grp[dst_grp].traf_inb[traf_idx] += bytes;
	}else
		if ( (src_grp >= 0) && (dst_grp == -1)  ) {
			/* Исходящий трафик (от клиента) */
			groups->grp[src_grp].traf_outb[traf_idx] += bytes;
		}else
			if ( (src_grp >= 0) && (dst_grp >= 0) ) {
				/* 
				 * Локальный трафик (либо между узлами определенными в группах)
				 * Его надо либо не считать, либо записывать только в одну группу
				 * Если его записывать в обе группы, он испортит общую статистику 
				 * по загрузке. 
				 */
				/* groups->grp[dst_grp].traf_inb[traf_idx] += bytes; */

				/* Выводим трафик как локальный. local_flag устанавливается чтобы
				 * выводить меньше одинаковых строк локального трафика
				 */
				if ( !flag_local1 || !flag_local2 ) {
					char src_ip_str[16];
					char dst_ip_str[16];
					set_local_flag(groups, src_ip, 1);
					set_local_flag(groups, dst_ip, 1);
					strncpy(src_ip_str, inet_ntoa(src_ip), sizeof(src_ip_str) - 1);
					strncpy(dst_ip_str, inet_ntoa(dst_ip), sizeof(dst_ip_str) - 1);
					ctime_r(&date, date_str);
					date_str[24]='\0';
					fprintf(stderr, "local: %s(%i) from %s:%lu(%i) to %s:%lu(%i) - %lg packets %lg bytes\n", 
							date_str,
							traf_idx,
							src_ip_str,
							src_port,
							src_grp>=0?groups->grp[src_grp].num:src_grp,
							dst_ip_str,
							dst_port,
							dst_grp>=0?groups->grp[dst_grp].num:dst_grp,
							packets,
							bytes);
				}
			}else
				/*if ( (src_grp == -1 ) && (dst_grp == -1) ) */
			{ 
				/* Неопределенный трафик */
				char src_ip_str[16];
				char dst_ip_str[16];
				strncpy(src_ip_str, inet_ntoa(src_ip), sizeof(src_ip_str) - 1);
				strncpy(dst_ip_str, inet_ntoa(dst_ip), sizeof(dst_ip_str) - 1);
				ctime_r(&date, date_str);
				date_str[24]='\0';
				fprintf(stderr, "unknown: %s(%i) from %s:%lu(%i) to %s:%lu(%i) - %lg packets %lg bytes\n", 
						date_str,
						traf_idx,
						src_ip_str,
						src_port,
						src_grp>=0?groups->grp[src_grp].num:src_grp,
						dst_ip_str,
						dst_port,
						dst_grp>=0?groups->grp[dst_grp].num:dst_grp,
						packets,
						bytes);
			} 

	return 0;
}

int
load_ip_stats(FILE *f, struct t_ip_groups *groups)
{
	unsigned strnum;
	char s[200];
	char *p, *pp;

	char *datetime;
	time_t t_datetime;
	struct in_addr src_ip, dst_ip;
	unsigned long src_port, dst_port;
	double packets, bytes;


	if ( f == NULL) {
		fprintf(stderr, "load_ip_stats: f is  NULL\n");
		return -1;
	}

	for ( strnum = 1; fgets (s, sizeof(s), f) != NULL; strnum++) {
		p = s;
		/* Дата время */
		while ( *p && isspace(*p) ) p++;
		datetime = strsep(&p, "\t\r\n ");
		if ((p == NULL) || (*p == '\0')) {
			fprintf(stderr, "cannot parse filetime on str %u\n", strnum);
			return -3;
		}
		if (( t_datetime = tai642time_t(datetime)) < 0) {
			fprintf(stderr, "wrong datetime '%s' on str %u\n", s, strnum);
			return -2;
		}
		/* src_ip */
		while ( *p && isspace(*p) ) p++;
		pp = strsep(&p, "\t\r\n ");
		if ((pp == NULL) || (*pp == '\0')) {
			fprintf(stderr, "cannot find src_ip on str %u\n", strnum);
			return -4;
		}
		if (inet_aton(pp, &src_ip) == 0) {
			fprintf(stderr, "cannot parse src_ip on str %u\n", strnum);
			 return -5;
		}

		/* src_port */
		while ( *p && isspace(*p) ) p++;
		pp = strsep(&p, "\t\r\n ");
		if ((pp == NULL) || (*pp == '\0')) {
			fprintf(stderr, "cannot find src_ip on str %u\n", strnum);
			return -4;
		}
		src_port = strtoull(pp, NULL, 10);
		if ( src_port >= 65536) {
			fprintf(stderr, "wrong src_port on str %u\n", strnum);
			return -5;
		}

		/* dst_ip */
		while ( *p && isspace(*p) ) p++;
		pp = strsep(&p, "\t\r\n ");
		if ((pp == NULL) || (*pp == '\0')) {
			fprintf(stderr, "cannot find dst_ip on str %u\n", strnum);
			return -6;
		}
		if (inet_aton(pp, &dst_ip) == 0) {
			fprintf(stderr, "cannot parse dst_ip on str %u\n", strnum);
			return -7;
		}

		/* dst-port */
		while ( *p && isspace(*p) ) p++;
		pp = strsep(&p, "\t\r\n ");
		if ((pp == NULL) || (*pp == '\0')) {
			fprintf(stderr, "cannot find dst_port on str %u\n", strnum);
			return -8;
		}

		dst_port = strtoull(pp, NULL, 10);
		if ( dst_port >= 65536) {
			fprintf(stderr, "wrong dst_port on str %u\n", strnum);
			return -9;
		}

		/* proto */
		while ( *p && isspace(*p) ) p++;
		pp = strsep(&p, "\t\r\n ");
		if ((pp == NULL) || (*pp == '\0')) {
			fprintf(stderr, "cannot find proto on str %u\n", strnum);
			return -15;
		}

		/* packets */
		while ( *p && isspace(*p) ) p++;
		pp = strsep(&p, "\t\r\n ");
		if ((pp == NULL) || (*pp == '\0')) {
			fprintf(stderr, "cannot find packets param on str %u\n", strnum);
			return -10;
		}

		packets = strtoull(pp, NULL, 10);
		if (packets <= 0) {
			fprintf(stderr, "wrong packets on str %u\n", strnum);
			return -11;
		}

		/* bytes */
		while ( *p && isspace(*p) ) p++;
		pp = strsep(&p, "\t\r\n ");
		if ((pp == NULL) || (*pp == '\0')) {
			fprintf(stderr, "cannot find bytes param on str %u\n", strnum);
			return -12;
		}
		bytes=strtoull(pp, NULL, 10);
		if (bytes <= 0) {
			fprintf(stderr, "wrong bytes on str %u\n", strnum);
			return -14;
		}

		while ( *p && isspace(*p) ) p++;

		if ( *p && (*p != '\n')) {
			fprintf(stderr, "extra bytes at the end of the string %u: %s\n", strnum, p);
		}

		if ( add_logfile_entry(t_datetime, src_ip, src_port, dst_ip, dst_port, packets, bytes, groups) < 0) {
			fprintf(stderr, "cannot handle string %u\n", strnum);
			return -16;
		}

	}

	if ( feof(f) == 0 ) {
		fprintf(stderr, "config error. line %u", strnum);
		return -2;
	}


	return 0;
}

void
print_header(FILE *f, const char *header, struct t_ip_groups *groups)
{
	struct tm t1, t2;
	time_t tt1;
	int i;
	char time1[80];
	char time2[80];
	char format[400];

	tt1 = idx2time(groups->start, groups->traf_max);
	localtime_r(&groups->start, &t1);
	localtime_r(&tt1, &t2);
	strftime(time1, sizeof(time1), "%c", &t1);
	strftime(time2, sizeof(time2), "%c", &t2);
	fprintf(f, "# %s\n", header);
	fprintf(f, "# Обрабатаные данные: c %s по %s\n\n", time1, time2);
	strcpy(format, "format: time\t");
	i = 0;
	for (; i < groups->max; i++){
		strcat(format, groups->grp[i].name);
		char *s;
		s = format + strlen(format) - 1;
		while ( (s != format) && (*s == '\n') ) *s-- = '\t';
	}
	fprintf(f, "%s\n", format);
	fprintf(f, "# Формат столбца: %% - GB\n");

}

/* Вывод полного лога */
int
print_full_time_log(FILE *f, struct t_ip_groups *groups)
{
	struct tm t2;
	time_t tt1;
	int i,j;
	double summ;
	char time2[80];

	print_header(f, "Полная статистика", groups);
	fprintf(f, "\nИсходящий трафик\n-----\n");
	for (i = 0; i <= groups->traf_max; i++) {
		tt1 = idx2time(groups->start, i);
		localtime_r(&tt1, &t2);
		strftime(time2, sizeof(time2), "%c", &t2);
		fprintf(f, "%s ", time2);
		summ = 0;
		for (j=0; j < groups->max; j++) {
			summ += groups->grp[j].traf_outb[i];
			fprintf(f, "%.2lf - %.3lf  \t", 
					BW_HOUR_BYTES_PERCENT(groups->grp[j].traf_outb[i], groups->bw),
					groups->grp[j].traf_outb[i] / 1000000000);
		}
		fprintf(f, "%.2lf - %.3lf\n", 
				BW_HOUR_BYTES_PERCENT(summ, groups->bw),
				summ / 1000000000);
	}

	fprintf(f, "-----\n\n");

	fprintf(f, "\nВходящий трафик\n-----\n");
	for (i = 0; i <= groups->traf_max; i++) {
		tt1 = idx2time(groups->start, i);
		localtime_r(&tt1, &t2);
		strftime(time2, sizeof(time2), "%c", &t2);
		fprintf(f, "%s\t", time2);
		summ = 0;
		for (j=0; j < groups->max; j++) {
			summ += groups->grp[j].traf_inb[i];
			fprintf(f, "%.2lf - %.3lf  \t", 
					BW_HOUR_BYTES_PERCENT(groups->grp[j].traf_inb[i], groups->bw),
					groups->grp[j].traf_inb[i] / 1000000000);
		}
		fprintf(f, "%.2lf - %.3lf\n",
				BW_HOUR_BYTES_PERCENT(summ, groups->bw),
				summ / 1000000000);
	}
	fprintf(f, "-----\n\n");

	return 0;
}

int
print_unformatted_time_log(FILE *f, struct t_ip_groups *groups)
{
	struct tm t2;
	time_t tt1;
	int i,j;
	double summ;
	char time2[80];

	print_header(f, "Полная статистика (unformatted)", groups);
	for (i = 0; i <= groups->traf_max; i++) {
		tt1 = idx2time(groups->start, i);
		localtime_r(&tt1, &t2);
		strftime(time2, sizeof(time2), "%s", &t2);
		fprintf(f, "%s\t", time2);
		summ = 0;
		for (j=0; j < groups->max; j++) {
			summ += groups->grp[j].traf_outb[i];
			fprintf(f, "%.1f/%.1f\t", 
					groups->grp[j].traf_outb[i], groups->grp[j].traf_inb[i]);
		}
		fprintf(f, "\n");
	}
	return 0;
}

int
calc_n_print_hour_log(FILE *f, struct t_ip_groups *groups)
{
	struct t_elm {
		double bytes;
		float cnt;
	};

	struct t_hour_traf {
		double inb;
		double outb;
		float cnt;
	};

	struct t_day_traf {
		struct t_hour_traf h[24];
	};

	int i,j;

	/* Статистика в будни и в выходные */
	struct t_day_traf *weekdays, *weekends;

	weekdays = malloc(sizeof(struct t_day_traf)*(groups->max));
	weekends = malloc(sizeof(struct t_day_traf)*(groups->max));

	if ((weekdays == NULL) || (weekends == NULL)) {
		free(weekdays);
		free(weekends);
		return -1;
	}

	for (i = 0; i < groups->max; i++) {
		for (j=0; j < 23; j++) {
			weekdays[i].h[j].inb = 0;
			weekdays[i].h[j].outb = 0;
			weekdays[i].h[j].cnt = 0;
			weekends[i].h[j].inb = 0;
			weekends[i].h[j].outb = 0;
			weekends[i].h[j].cnt = 0;

		}
	}

	for (i = 0; i <= groups->traf_max; i++) {
		struct tm t;
		time_t tt1;
		int hour;

		tt1 = idx2time(groups->start, i);
		localtime_r(&tt1, &t);
		hour = t.tm_hour;

		if ( (t.tm_wday == 0) || (t.tm_wday == 6) ) {
			/* Выходные */
			for (j = 0; j < groups->max; j++) {
				weekends[j].h[hour].inb += groups->grp[j].traf_inb[i];
				weekends[j].h[hour].outb += groups->grp[j].traf_outb[i];
				weekends[j].h[hour].cnt++;
			}
		}else {
			/* Будни */
			for (j = 0; j < groups->max; j++) {
				weekdays[j].h[hour].inb += groups->grp[j].traf_inb[i];
				weekdays[j].h[hour].outb += groups->grp[j].traf_outb[i];
				weekdays[j].h[hour].cnt++;
			}
		}
	}

	{
		/* Вывод данных */
		double summ, cnt, avg;
		struct t_day_traf *days;
		int k;

		print_header(f, "Статистика по часам", groups);
		for (k = 0; k < 4; k++) {
			switch (k) {
				case 0:
					fprintf(f, "\nИсходящий трафик, будни\n-----\n");
					days = weekdays;
					break;
				case 1:
					fprintf(f, "\nИсходящий трафик, выходные\n-----\n");
					days = weekends;
				break;
				case 2:
					fprintf(f, "\nВходящий трафик, будни\n-----\n");
					days = weekdays;
				break;
				default:
					fprintf(f, "\nВходящий трафик, выходные\n-----\n");
					days = weekends;
				break;
			}
			for (i = 0; i < 24; i++) {
				fprintf(f, "%.2i:00\t", i);
				summ  = 0;
				cnt = 0;
				avg = 0;
				for (j = 0; j < groups->max; j++) {
					if ( days[j].h[i].cnt) {
						avg = k < 2 ? days[j].h[i].outb : days[j].h[i].inb;
						avg /= days[j].h[i].cnt;
						summ += avg;
						cnt ++;
						fprintf(f, "%.2lf - %.3lf  \t", 
								BW_HOUR_BYTES_PERCENT(avg, groups->bw),
								avg/ 1000000000);
					}else
						fprintf(f,"-\t");
				}
				if ( cnt )  {
					fprintf(f, "%.2lf - %.3lf\n",
							BW_HOUR_BYTES_PERCENT(summ, groups->bw),
							summ / 1000000000);
				}else
					fprintf(f, "-\n");

			}// for 24
			fprintf(f, "-----\n\n");
		} // for k

	}
	free(weekends);
	free(weekdays);
	return 0;

}


FILE *my_fopen(const char *name)
{
	if ((name == NULL)
		|| ( name[0] == '\0'))
		return NULL;

	if (( name[0] == '-')
		&& (name[1] == '\0'))
		return freopen(NULL, "r", stdin);
	else
		return fopen(name, "r+");
}

int 
main(int argc, char **argv)
{
	/* 32 таблицы ип локальных адресов */
	struct t_ip_groups groups;
	char ch;
	struct sockaddr_in tmp;

	const struct {
		char *local_ips_name;
		char *logfile_name;
		double bw;
		int print_report1;
		int print_report2;
		int print_report3;
	} defaults = {"locals.txt", "-", 4*1000000, 0, 0, 0};

	struct {
		const char *local_ips_name;
		FILE *local_ips;
		const char *logfile_name;
		FILE *logfile;
		double bw;
		int print_report1;
		int print_report2;
		int print_report3;
	}params;

	params.local_ips_name = strdup(defaults.local_ips_name);
	params.logfile_name = strdup(defaults.logfile_name);
	params.bw = defaults.bw;
	params.print_report1 = defaults.print_report1;
	params.print_report2 = defaults.print_report2;
	params.print_report3 = defaults.print_report3;

	while ((ch = getopt(argc, argv, "123c:f:m:")) != -1) {
		switch (ch) {
			case '1':
				params.print_report1 = 1;
				break;
			case '2':
				params.print_report2 = 1;
				break;
			case '3':
				params.print_report3 = 1;
				break;
			case 'c':
				free((void *)params.local_ips_name);
				params.local_ips_name=strdup(optarg);
				break;
			case 'f':
				free((void *)params.logfile_name);
				params.logfile_name = strdup(optarg);
				break;
			case 'm':
				sscanf(optarg, "%lf", &params.bw);
				params.bw = params.bw*1000000;
				break;
			case 'h':
			case '?':
			default:
				usage();
				return 0;
				break;
		}
	}
	argc -= optind;
	argv += optind;

	params.local_ips = my_fopen(params.local_ips_name);
	if ( params.local_ips == NULL) {
		char buf[80];
		snprintf(buf, sizeof(buf), "cannot open config file %s", params.local_ips_name);
		perror (buf);
		return -1;
	}

	rn_init();
	if ( !rn_inithead((void **)&groups.ips, ((uint8_t *)&tmp.sin_addr - (uint8_t *)&tmp) * 8)) {
		fprintf(stderr, "cannot init group");
		return -1;
	}

	if ( load_ip_config(params.local_ips, &groups) < 0) {
		fprintf(stderr, "can not load config file\n");
		return -2;
	}

	params.logfile = my_fopen(params.logfile_name);
	if ( params.logfile == NULL) {
		char buf[80];
		snprintf(buf, sizeof(buf), "cannot open log file %s", params.logfile_name);
		perror (buf);
		return -3;
	}

	if ( load_ip_stats(params.logfile, &groups) < 0) {
		fprintf(stderr, "cannot load stats file\n");
		return -4;
	}
	groups.bw = params.bw;

	if (params.print_report1)
		print_full_time_log(stdout, &groups);
	if (params.print_report2)
		calc_n_print_hour_log(stdout, &groups);
	if (params.print_report3)
		print_unformatted_time_log(stdout, &groups);

	fclose(params.local_ips);
	fclose(params.logfile);
	return 0;
}
