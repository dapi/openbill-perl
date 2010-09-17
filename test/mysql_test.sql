create database openbill_test;
connect database openbill_test;

create table shots       (
 shot_id int unsigned auto_increment not null,
 router_id int not null,
 filetime datetime not null,
 shottime datetime, /* Дата, когда данные этого файла полностью загружены */
 closetime datetime,  /* Дата, когда данные этого файла полностью обработаны (запиханы в minut, day_traffic */
 limittime datetime not null,
 bytes bigint unsigned not null,
 primary key (shot_id)
);

create table ulog (
 shot_id int unsigned not null,
 logtime int unsigned not null,
 packettime int unsigned not null,
 src_ip int unsigned not null,
 dst_ip int unsigned not null,
 bytes int unsigned not null,
 in_iface varchar(6) not null,
 out_iface varchar(6) not null,
 prefix varchar(10) not null
);

/* записи для одного времени и ip могут повторяться */

create table minut_traffic (
  router_id int not null,
  datetime datetime not null,
  ip varchar(16) not null,
  dip varchar(16) not null,
  class integer not null,
  direction enum ('in','out'),
  bytes int unsigned not null,
  index (datetime)
);

commit;

create table test (
 a int not null,
 t timestamp not null,
 d datetime not null,
 b char,
 index (a),
 index (t),
 index (d)
);

insert test values (1,2,3,4);
insert test values (2,12,23,4);
insert test values (2,22,33,4);
insert test values (2,32,432,4);
insert test values (2,42,532,4);
insert test values (2,52,63,4);


/*

select router_id, from_unixtime(logtime-mod(logtime,300)), src_ip, dst_ip, (3647713698=dst_ip or 3647713723=dst_ip or 3647713539=dst_ip or 3647713542=dst_ip or 3647713716=dst_ip or 3647713721=dst_ip or 3647713732=dst_ip or 2660 = dst_ip >> 16 or 49320 = dst_ip >> 16), sum(ulog.bytes)
from shots, ulog
where closetime is null and shots.shot_id=ulog.shot_id and (3647713698=src_ip or 3647713723=src_ip or 3647713539=src_ip or 3647713542=src_ip or 3647713716=src_ip or 3647713721=src_ip or 3647713732=src_ip or 2660 = src_ip >> 16) and not (3647713698=dst_ip or 3647713723=dst_ip or 3647713539=dst_ip or 3647713542=dst_ip or 3647713716=dst_ip or 3647713721=dst_ip or 3647713732=dst_ip or 2660 = dst_ip >> 16)
group by router_id, from_unixtime(logtime-mod(logtime,300)), src_ip, dst_ip

*/


create table m (
 key1 int not null,
 key2 int not null,
 bytes int not null,
 unique (key1,key2)
);

insert into m values (1,1,400);
insert into m values (1,2,400);

create table m2 (
 key1 int not null,
 key2 int not null,
 bytes int not null,
 unique (key1,key2)
);

create table u (
 key1 int not null,
 key2 int not null,
 bytes int not null
);


insert into u values (1,1,100);
insert into u values (1,1,200);
insert into u values (1,2,100);
insert into u values (1,2,200);
insert into u values (2,1,100);
insert into u values (2,1,200);
insert into u values (2,2,100);
insert into u values (2,2,200);


insert into u select m2.key1,m2.key2,sum(m.bytes)+sum(m2.bytes) from m2 left join m on m.key1=m2.key1 and m.key2=m2.key2 group by m2.key1, m2.key2;
insert into u select m.key1,m.key2,if(m2.bytes>0,0,m.bytes) from m left join m2 on m.key1=m2.key1 and m.key2=m2.key2 group by m.key1, m.key2;



select m.key1,m.key2,m.bytes+m2.bytes from m,m2 where m.key1=m2.key1 and m.key2=m2.key2
union
select m.key1, m.key2, m.bytes from m left join m2 on m2.key1=m.key1 and m2.key2=m.key2where m2.key1 is null and m2.key2 is null
union
select m2.key1, m2.key2, m2.bytes from m2 left join m1 where m1.key1 is null and m1.key2 is null