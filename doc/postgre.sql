create database openbill_example with encoding 'koi8';
connect openbill_example;

create table manager (
        manager_id serial primary key,
        password varchar(50),
	login varchar(50) unique,
	name varchar(255),
	comment varchar(255),
        is_admin boolean,
        unique (name)
);

create table manager_session (
  manager_id integer references manager,
  create_time datetime not null,
  session_id  varchar(200) unique
);

/* TODO переименовано street.name->street.street, building.number->building.building
*/

create table street (
  street varchar(255) unique
);

create table building (
  building varchar(255) not null,
  unique (street,building)
) inherits (street);

create table address (
  address_id serial primary key,
  room varchar(255) not null,
  comment varchar(255),
  unique (building,room)
) inherits (building);

create table client (
 client_id  serial primary key,
 address_id integer not null,
 name varchar(200) not null unique,
 is_firm boolean not null,
 firmname varchar(150) check (not is_firm OR  firmname is not null),
 inn varchar(150) unique,
 nick varchar(50) not null unique,
 telefon varchar(100) not null,
 email varchar(100),
 reg_date date not null default 'now',
 minimal_balance integer default 0,
 balance double precision not null,
 balance_changed timestamp not null,
 comment varchar(255),
 is_active boolean not null,
 can_deactivate boolean not null,
 FOREIGN KEY (address_id) REFERENCES address(address_id)
 ON DELETE NO ACTION
);

create table service (
 id serial primary key,
 name varchar(100) not null unique,
 comment varchar(255),
 module varchar(200) not null
);

create table collector (
 collector_id serial primary key,
 name varchar(100) unique,
 comment varchar(255),
 module varchar(200) not null,
 arc_dir varchar(200),
 work_dir varchar(200),
 service_id integer not null,
 FOREIGN KEY (service_id) REFERENCES service(id)
 ON DELETE NO ACTION
);

create table router (
 router_id serial primary key,
 am_lasttime timestamp,
 ip inet unique not null, /* TODO Проверить чтобыстрее этот, string или bigint */
 real_ip inet unique,
 hostname varchar(100) not null unique,
 shortname varchar(100) unique,
 comment varchar(255),
 is_active boolean,
 address_id integer not null unique,
 default_janitor_id integer not null,
 use_janitor integer not null,
 firstwork_time timestamp,
 lastwork_time timestamp,
 FOREIGN KEY (address_id) REFERENCES address(address_id)
 ON DELETE NO ACTION
);

create table router_ip (
 router_id integer not null,
 mask int unsigned not null,
/* Если 1 - считать ip адрес роутера,
        2 - считать real_ip роутера,
        3 - считать ip адреса всех роутеров
        4 - real_ip всех роутеров
        5 - адреса присоединённых ip */
 bits smallint not null,
 type set ('local','client') not null,
 comment varchar(255),
 unique (router_id,type,mask)
) type=innodb;

create table router_addr (
 router_id integer not null,
 addr inet not null,
 comment varchar(255),
 unique (router_id,addr)
) type=innodb;

create table router_collector (
 router_id integer not null,
 collector_id  integer not null,
 is_active integer,
 command_line varchar(255),
 comment varchar(255),
 unique (router_id, collector_id),
 index (collector_id)
) type=innodb;

create table host (
 ip int unsigned primary key,
 am_type set ('common') not null,
 am_name set ('active','deactive') not null,
 am_time timestamp,
 mac varchar(80),
 hostname varchar(100),
 address_id integer not null,
 router_id integer not null,
 comment varchar(255),
 createtime timestamp not null,
 janitor_id integer not null,
 firstwork_time timestamp,
 lastwork_time timestamp, /* TODO Парамет по которому никогда не отключать этот хост */
 INDEX address_id (address_id),
 INDEX router_id (router_id),
 INDEX ip_router (ip,router_id),
 unique (mac, router_id)
) type=innodb;

commit;

create table access_mode (
  id integer auto_increment primary key,
  janitor_id integer not null,
  type set ('common') not null,
  name set ('active','deactive') not null,
  comment varchar(255),
  rules text,
  index janitor_name_type (janitor_id, name, type)
) type=innodb;

create table host_attach (
 changetime timestamp not null,
 client_id integer not null,
 from_ym timestamp(4) not null,
 to_ym timestamp(4),
 ip int unsigned  not null,
 attach_done_time timestamp, /* Время, когда аттачмент хостя переведён в host_access и для соответвующего абонента сделан recharge */
 deattach_done_time timestamp,
 comment varchar(255),
 unique (ip,from_ym), /* TODO Ввести attach_done и deattach_done */
 index (client_id,from_ym),
 index (client_id),
 index (client_id,to_ym)
) type=innodb;

create table janitor (
 id integer auto_increment primary key,
 name varchar(255) unique,
 module varchar(200),
 comment varchar(255),
) type=innodb;

commit;

create table tariff (
 id integer auto_increment primary key,
 service_id integer not null,
 name varchar(200),
 is_hidden integer not null default 0,
 is_active integer not null,
 serialized varchar(255),
 comment varchar(250),
 index (service_id),
 unique (name, is_active)
) type=innodb;

create table invoice (
 id integer auto_increment primary key,
 client_id integer not null,
 date timestamp not null,
 num varchar(30) not null,
 summa double precision not null,
 comment varchar(255)
) type=innodb;

create table payment (
 id integer auto_increment primary key,
 client_id integer not null,
 invoice_id integer,
 summa double precision not null check (summa>0),
 summa_order double precision check (summa_order>0),
 form set ('cash','order') not null default "cash",
 type integer not null, /* 0 - за подключение, 1 - абонплата или трафик */
 date timestamp not null,
 comment varchar(250),
 primary key (id)
) type=innodb;

create table period (
 id integer auto_increment primary key,  /* TODO Стоит заменить на smallint. Периодов не будет так много, а вот индексы уменьшаться?? */
 create_time timestamp,
 service_id integer not null,
 start date not null,
 end date not null,
 comment varchar(255),
 is_closed integer not null default 0, /* Если период закрыт, значит никаких изменений в  нм и charges производить нельзя */
 /* Параметры, свойственны только сервису IPTraff */
 season_date date,
 dayshot_id integer,

 unique (service_id,start,end)
) type=innodb;

create table tariff_log (
 changetime timestamp not null,
 client_id integer not null,
 tariff_id integer not null,
 service_id integer not null,
 from_ym timestamp(4) not null,
 donetime timestamp,
 comment varchar(255),
 primary key (client_id, from_ym, service_id),
 index (from_ym)
) type=innodb;

create table activation (
 client_id integer not null,
 service_id integer not null,
 is_active integer not null,
 days integer not null,
 date date not null,
 comment varchar(255),
 done_time timestamp,
 type integer not null default 0,  /* 0 - ручная, 1 - автоматическая из-за баланса */
 primary key  (client_id, service_id, date)
) type=innodb;

create table notice (
 client_id integer not null,
 timestamp timestamp not null,
 count integer not null default 1,
 type set ('warning','debt'),
 index (client_id)
) type=innodb;

create table message_log (
 client_id integer not null,
 timestamp timestamp not null,
 template varchar(255) not null,
 date text,
 index (client_id)
) type=innodb;

create table charge (
 charge_time timestamp not null,
 period_id integer not null,
 client_id integer not null,
 tariff_id integer,
 summa double precision not null,

 total_days integer, /* сколько дней активен. Генерируется из activations */
 act_log varchar(35), /* журнал активаций */

 /* Параметры, свойственны только сервису IPTraff */
 traffic varchar(255),
 traffic_summa double precision,
 traffic_free bigint,

 season_summa double precision,

 primary key (period_id, client_id),
);


commit;

CREATE RULE minut_traffic_insert AS ON INSERT TO minut_traffic2
WHERE exists (select * from minut_traffic2
where router_id=NEW.router_id and date=NEW.date and time=NEW.time and ip=NEW.ip and dip=NEW.dip and class=NEW.class)
DO INSTEAD
UPDATE minut_traffic2 set bytes_in=bytes_in+NEW.bytes_in, bytes_out=bytes_out+NEW.bytes_out
where router_id=NEW.router_id and date=NEW.date and time=NEW.time and ip=NEW.ip and dip=NEW.dip and class=NEW.class;

create table iptraff_minut_dst (
  router_id smallint not null,
  ip inet not null,
  date date not null,
  time time not null,
  dip inet not null,
  class smallint not null,
  bytes_in bigint not null,
  bytes_out bigint not null,
  unique (router_id,ip,date,time,dip)
);

create table iptraff_minut (
  router_id smallint not null,
  ip inet not null,
  date date not null,
  time time not null,
  class smallint not null,
  bytes_in bigint not null,
  bytes_out bigint not null,
  unique (router_id,ip,date,time)
);

create table iptraff_day (
  router_id smallint not null,
  ip inet not null,
  client_id int,
  date date not null,
  class smallint not null,
  bytes_in bigint not null,
  bytes_out bigint not null,
  unique (router_id,ip,date)
);

// status set ('charged','unknown','fresh'),

CREATE INDEX minut_traffic_dtri unique ON minut_traffic (date,time,router_id,ip);
CREATE INDEX minut_traffic_dtc ON minut_traffic (date,time,client_id);

create table day_shot (
 id int unsigned auto_increment not null primary key,
 shottime timestamp,
 dfrom date,
 dto date,
 from_mshot_id int,
 to_mshot_id int not null,
 bytes bigint unsigned,
 index (shottime,id)
);


create table day_traffic (
  shot_id int not null,
  date date not null,
  router_id int not null,
  ip int unsigned not null,
  class integer not null default 0,
  bytes bigint unsigned not null,
  index (shot_id), /* применяется при удалении конкретного снимка */
  index (date,ip,class),
  index (date,router_id), /* Трафик роутера за определённый период */
  index (ip,class) /* Работает при выборке тарифа для расчёта вместо period,ip,class */
);

CREATE TABLE `trafshot` (
  `shot_id` int(10) unsigned NOT NULL auto_increment,
  `router_id` int(11) NOT NULL default '0',
  `collector_id` int not null,
  `filetime` timestamp NOT NULL default '0000-00-00 00:00:00',
  `shottime` timestamp default NULL,  /* Дата, когда данные этого файла полностью загружены. */
  `maxlogtime` timestamp default NULL, /* Дата самого старшего пакета */
  `minlogtime` timestamp default NULL, /* Дата самого младшего пакета */
  count_max int, /* Количество пакетов старше границы  */
  count_min int, /* Количество пакетов младше границы */
  `bytes` bigint(20) unsigned NOT NULL default '0',
  `is_removed` int(11) NOT NULL default '0',
  PRIMARY KEY  (`shot_id`),
  UNIQUE KEY `router_id` (`router_id`,`filetime`,`type`),
  KEY `shottime` (`shottime`),
  index (maxlogtime),
  index (minlogtime)
);

/* записи для одного времени и ip могут повторяться */

create table traflog (
 shot_id int not null,
 router_id int,
 logtime timestamp not null,
 src_ip inet not null,
 dst_ip inet not null,
 bytes int not null,
 in_iface smallint not null,
 out_iface smallint not null,
 prefix smallint not null
);


GRANT select, insert, update, delete, create, lock tables
ON openbill.*
TO openbill@localhost IDENTIFIED BY 'CHANGE_ME';


create table locker (
  name varchar(80) not null,
  action varchar(10),
  record integer,
  timestamp timestamp not null,
  pid integer not null,
  comment varchar(255),
  unique (name,action,record),
  index (pid)
)  type=myisam;
