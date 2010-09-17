create database openbill;

connect openbill;

create table mgroup (
id integer auto_increment primary key,
name varchar(100) not null unique,
is_admin integer not null default 0,
comment varchar(255)
) type=innodb;

insert into mgroup values (1,'admins',1,NULL);
insert into mgroup values (2,'operators',0,NULL);

create table mgroup_method (
id integer auto_increment primary key,
mgroup_id integer not null,
object varchar(100) not null,
method varchar(100),
params varchar(255),
comment varchar(255),
unique (object,method,mgroup_id)
) type=innodb;

insert into mgroup_method values (1,2,'client','makePayment',NULL,NULL);
insert into mgroup_method values (2,2,'client','get',NULL,NULL);
insert into mgroup_method values (3,2,'client','list',NULL,NULL);

create table manager (
        manager_id integer auto_increment primary key,
        password varchar(50),
	login varchar(50) unique,
	name varchar(255) not null unique,
        mgroup_id integer not null,
        is_active integer not null default 0,
	comment varchar(255)
) type=innodb;

insert into manager values (1,'admin','secret','Administrator',1,NULL);
commit;

create table system_param (
  param varchar(100) not null unique,
  value varchar(100)
);

create table bill_delivery (
 id integer auto_increment primary key,
 name varchar(100) not null unique,
 comment varchar(255)
);

create table manager_session (
  manager_id integer,
  create_time timestamp not null,
  soft varchar(255) not null,
  version varchar(255) not null,
  last_time datetime not null,
  session_id  varchar(128) not null unique,
  index (session_id)
);

create table city (
        city_id integer auto_increment not null,
	name varchar(255) unique,
	comment varchar(255),
        primary key (city_id)
) type=innodb;

create table city (
 id integer auto_increment not null,
 name varchar(255) unique,
 comment varchar(255),
 primary key (id)
)

create table street (
        street_id integer auto_increment not null,
        city_id integer not null,
	name varchar(255) unique,
	comment varchar(255),
        primary key (street_id),
        unique (city_id, name)
) type=innodb;

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

create table connection_type (
 id integer auto_increment not null,
 name varchar(200) not null unique,
 comment varchar(255),
 primary key (id)
);

create table building_holder (
 id integer auto_increment not null,
 name varchar(255) not null unique,
 address varchar(255) not null,
 contact_name varchar(100),
 contact_phone varchar(100),
 comment varchar(255),
 primary key (id)
);

create table geo_area (
 id integer auto_increment not null,
 name varchar(255) not null unique,
 comment varchar(255),
 primary key (id)
);

create table building (
 building_id  integer auto_increment not null,
 connection_type_id integer,

 area_id integer,
 street_id integer not null,
 number varchar(255) not null,
 building_holder_id not null,
 is_secret integer not null default 0,

 price integer,
 price_firm integer,

 date_connect varchar(100),
 connected date,

 is_connected integer not null default 0,

 description varchar(255),

 comment text,
 unique (street_id, number),
 primary key (building_id),
 INDEX street_ind (street_id),
 index building_holder (building_holder_id),
 FOREIGN KEY (street_id) REFERENCES street(street_id)
 ON DELETE NO ACTION
) type=innodb;

commit;

create table address (
 address_id  integer auto_increment not null,
 building_id integer not null,
 room varchar(255),
 comment varchar(255),
 unique (room,building_id),
 primary key (address_id),
 INDEX building_ind (building_id),
 FOREIGN KEY (building_id) REFERENCES building(building_id)
 ON DELETE NO ACTION
);

CREATE TABLE dealer (
  id int(11) NOT NULL auto_increment,
  address_id int(11) NOT NULL default '0',
  name varchar(200) NOT NULL default '',
  firmname varchar(150) default NULL,
  inn varchar(14) default NULL,
  is_firm int(11) default NULL,
  telefon varchar(100) NOT NULL default '',
  email varchar(100) default NULL,
  reg_date date NOT NULL default '0000-00-00',
  comment varchar(255) default NULL,
  is_removed integer not null default 0,
  PRIMARY KEY  (id),
  KEY address_ind (address_id)
) TYPE=InnoDB;

insert into dealer values (1,0,'self','self','',1,'','',now(),'',0);

CREATE TABLE subscribes (
  client_id int(11) NOT NULL,
  service_name varchar(100) not null,

  -- Минимальный баланс при достижении которого сообщать об этом
  -- сервису
  minimal_balance int(11) default 0,

  -- Тип последнего собщения
  -- 0 - значит в последний раз сообщали что баланс больше или равен
  -- 1 - значит в последний раз сообщени что баланс меньше
  last_balance_notify integer not null default 0,
  last_balance_timestamp timestamp, -- время последнего сообщения

  is_subscribed integer not null default 1,

  subscribe_date date not null default now(),
  unsubscribe_date date,

  unique (client_id, service_name)
);

CREATE TABLE client (
  client_id int(11) NOT NULL auto_increment,
  address_id int(11) NOT NULL default '0',
  can_chat integer not null default 0,
  name varchar(200) NOT NULL default '',
  firmname varchar(150) default NULL,
  dealer_id integer not null,
  inn varchar(14) default NULL,
  nick varchar(50) NOT NULL default '',
  is_firm int(11) default NULL,
  telefon varchar(100) NOT NULL default '',
  email varchar(100) default NULL,
  reg_date date NOT NULL default '0000-00-00',
  new_contract_date date,

  months integer not null default 1,

  comment varchar(255) default NULL,
  minimal_balance int(11) default '0',

  new_balance_method int(11) default '0',

  do_alert integer not null default 0,
  balance_to_alert int(11) default '0',
  alert_email varchar(100),
  balance_alerted_time datetime default null, /* Время последнего отсыла сообщения */
  balance_to_off int(11) default '0',

  unpayed_days_to_off int(11) default '0', /* Количество дней с момента последнего оплаченного дня (payed_to_date) */
  unpayed_days_to_alert int(11) default '0',
  unpayed_days_alerted_time datetime default null,  /* Время последнего отсыла сообщения. Стирается при оплате. */

  credit_balance int(11) default null, /* Минимальный баланс при кредите = balance-credit_summ */
  credit_summ int(11) default '100' not null, /* Максимальная сумма для кредита */
  credit_days int(11) default '2' not null, /* Максимальное колличество дней для кредита */
  credit_timestamp datetime default null, /* Если кредит запущен, то время его запуска. Максимальное число дней считается с этого момент */
  credit_manager_id int(11) default null,

  payed_to_date date,

  lastwork_time datetime,

  balance double NOT NULL default '0',
  old_balance double NOT NULL default '0',
  start_balance double NOT NULL default '0',
  balance_changed datetime NOT NULL default '0000-00-00 00:00:00',
  is_active int(11) NOT NULL default '0',
  can_deactivate int(11) NOT NULL default 1,
  deactivation_type integer not null default 0,
/* за что отключен:
   0 - вручную менеджером;
   1 - баланс отрицательный (автомат);
   2 - нарушение правил;
   3 - вирусы и вродоносные программы
   4 - превышен лимит кредита
   5 - превышен период кредита
   6 - превышен период оплаты
*/
  activation_time datetime default NULL,
  activation_done datetime default NULL,

/* -- deprecated
  last_positive_balance_time datetime,
  spend_money_speed double not null default 0,
  alert_balance double not null default 300,
  send_alert integer not null default 0,
*/

  is_removed integer not null default 0,
  bill_delivery_id integer,
  payment_method_id integer,
  manager_id integer,
  status_id integer, -- статус VIP, обычный и тп.

  order_connection_summ decimal,
  real_connection_summ decimal,
  connection_credit varchar(100), -- not null если имеет кредит, в этой строке он описывается
  has_connection_credit integer not null default 0,

  -- использовать ночной режим.
  -- ночной трафик не считать
  -- ночью увеличивать скорость
  night_speed integer not null default 0,

  -- Ограничение скорости в указанном периоде
  period_month date not null default '2007-01-01',
  period_traffic_mb integer, -- полный интернет трафик в периоде
  period_limited integer not null default 0, -- ограничен ли доступ (согласно безлимитному тарифу)
  period_tariff_id integer,

 -- Программа лояльности
  is_good_month integer not null default 0, -- Подходил ли месяц под программу лояльности
  good_month_cnt integer not null default 0, -- Кол-во месяцев лояльности на конец периода
  good_month_period_id integer not null default 0, -- ID периода для которого действительны значения 

  PRIMARY KEY  (client_id),
  UNIQUE KEY nick (nick),
  key dealer (dealer_id),
  key balance (balance),
  key can_deactivate (can_deactivate),
  KEY address (address_id)
) TYPE=InnoDB;

create table client_status (
  id int(11) NOT NULL auto_increment,
  name varchar(100) not null unique,
  bgcolor varchar(10),
  fgcolor varchar(10),
  PRIMARY KEY  (id)
);

insert into client_status values (1,'VIP','blue','white');
insert into client_status values (2,'Друзья','green','white');
insert into client_status values (3,'Черный список','black','white');

create table client_email (
  client_id integer not null,
  email varchar(255) not null unique,
  createtime datetime not null,
  comment varchar(255)
);

create table service (
 id integer auto_increment primary key,
 name varchar(100),
 comment varchar(255),
 module varchar(200)
) type=innodb;

commit;

create table collector (
 collector_id integer auto_increment primary key,
 name varchar(100),
 comment varchar(255),
 module varchar(200),
 arc_dir varchar(200),
 work_dir varchar(200),
 command_line varchar(250),
 traflog_line varchar(250),
 ext  varchar(80),
 service_id integer not null,
 unique service_module  (service_id, module),
 INDEX service_ind (service_id)
) type=innodb;

create table router (
 router_id integer auto_increment primary key,
 am_lasttime datetime,
 ip int unsigned unique,
 real_ip int unsigned unique,
 client_ip_min int unsigned,
 client_ip_max int unsigned,
 hostname varchar(100) not null unique,
 shortname varchar(100) unique,
 comment varchar(255),
 is_active integer,
 address_id integer not null unique,
 default_janitor_id integer,
 use_janitor integer not null,
 collector_id integer,
 firstwork_time datetime,
 lastwork_time datetime,
 altitude integer,
 login varchar(50),
 mac varchar(80),
 INDEX address_ind (address_id)
) type=innodb;

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

create table ip_class (
 class integer not null default 1,
 net varchar(20) not null,
 comment varchar(255),
 unique (class,net)
);

create table ip_client (
 router_id integer not null default 0,
 net varchar(20) not null,
 comment varchar(255),
 unique (router_id,net)
);


create table router_collector (
 router_id integer not null,
 collector_id  integer not null,
 is_active integer,
 command_line varchar(255),
 exclude_ifaces varchar(200),
 comment varchar(255),
 unique (router_id, collector_id),
 index (collector_id)
) type=innodb;

/* TODO add attach_time */

create table host (
 host_id integer auto_increment primary key,
 ip int unsigned,
 bits smallint not null,
 am_type varchar(100) not null,
 am_name set ('active','deactive','deny') not null,
 am_time datetime,

 is_vpn integer not null default 0,
 -- hostname используется как логин
 password varchar(40),

 mac varchar(80),

 hostname varchar(100),

 manager_id integer not null, -- зарегистрировавший
 address_id integer not null,
 router_id integer not null,
 janitor_router_id integer not null,
 comment varchar(255),
 createtime timestamp not null,
 modifytime timestamp not null,
 janitor_id integer,
 is_removed integer not null default 0,
 is_deactive integer not null default 0,
 firstwork_time datetime,
 lastwork_time datetime, /* TODO Парамет по которому никогда не отключать этот хост */
 client_id integer,

-- переведен на ночной режим
-- is_night_mode integer not null default 0,

-- переведен на режим порогового ограничения
 is_limited integer not null default 0,

-- текущая скорость ограничения
 current_speed integer,

 INDEX address_id (address_id),
 INDEX router_id (router_id),
 INDEX ip_router (ip,router_id),
 unique (ip, router_id),
 unique (hostname, router_id)
) type=innodb;

create table host_attach_log (
 changetime timestamp not null,
 client_id integer not null,
 from_ym timestamp(4) not null,
 to_ym timestamp(4),
 host_id integer not null,
 attach_done_time datetime, /* Время, когда аттачмент хостя переведён в host_access и для соответвующего абонента сделан recharge */
 deattach_done_time datetime,
 comment varchar(255),
 unique (host_id,from_ym), /* TODO Ввести attach_done и deattach_done */
 index (client_id,from_ym),
 index (client_id),
 index (client_id,to_ym)
) type=innodb;

create table host_log (
 timestamp timestamp not null default now(),
 host_id integer not null,
 text text,
 manager_id integer not null
);


commit;

create table access_mode (
  id integer auto_increment primary key,
  janitor_id integer not null,
  type varchar(100) not null,
  name set ('active','deactive','deny') not null,
  comment varchar(255),
  rules text,
  index janitor_name_type (janitor_id, name, type)
) type=innodb;

create table janitor (
 id integer auto_increment primary key,
 name varchar(255) unique,
 module varchar(200),
 comment varchar(255)
) type=innodb;

commit;

create table tariff (
 id integer auto_increment primary key,
 service_id integer not null,
 name varchar(200),
 is_hidden integer not null default 0,
 is_active integer not null,
 is_firm integer not null,

 need_whole_update integer not null default 0,

 is_unlim integer not null default 0,
 speed integer not null default 0,-- 64, 128, 256

-- возможное количество vpn-хостов на тарифе
 hosts_limit inreger not null default 999,

-- ночная скорость
 night_speed integer not null default 0,

 -- дневное ограничение по скорости в случае достижения предельного трафика
 limit_speed integer not null default 16, --32


-- есть различия в ночном и днемном режиме?
 has_night_mode integer not null default 0,

 serialized varchar(255),
 comment varchar(250),
 index (service_id),

 price integer not null,

 traffic_mb0 integer not null,
 traffic_mb1 integer,
 traffic_mb2 integer,
 traffic_mb3 integer,
 traffic_mb4 integer,
 traffic_mb5 integer,
 traffic_mb6 integer,
 traffic_mb7 integer,
 traffic_mb8 integer,
 traffic_mb9 integer,
 traffic_mb10 integer,
 traffic_mb11 integer,

 price_mb0 decimal (12,2) not null,
 price_mb1 decimal (12,2),
 price_mb2 decimal (12,2),
 price_mb3 decimal (12,2),
 price_mb4 decimal (12,2),
 price_mb5 decimal (12,2),
 price_mb6 decimal (12,2),
 price_mb7 decimal (12,2),
 price_mb8 decimal (12,2),
 price_mb9 decimal (12,2),
 price_mb10 decimal (12,2),
 price_mb11 decimal (12,2)

 unique (name, is_active)
) type=innodb;


create table invoice (
 id integer auto_increment primary key,
 client_id integer not null,
 date timestamp not null,
 num varchar(30) not null,
 summa decimal (12,2) not null,
 comment varchar(255)
) type=innodb;

create table payment_method (
 id integer auto_increment primary key,
 name varchar(255) not null unique,
 templ varchar(100) not null,
 is_default integer not null default 0,
 comment varchar(255),
 tax decimal (8,8) default 0
);

create table payment (
 id integer auto_increment primary key,
 timestamp timestamp not null,
 client_id integer,
 invoice_id integer,
 summa decimal (12,2) not null,
 summa_order decimal (12,2),
 payment_method_id integer not null,
 type integer not null, /* 0 - за подключение, 1 - абонплата или трафик, 2 - реализация, 3 - другое, -1 абонплата при подключении */
 date datetime not null,
 manager_id integer not null,
 confirm_datetime datetime,
 balance double, /* Баланса на момент платежа timestamp */
 comment varchar(250),
 secret_comment varchar(250),
 index(date)
) type=innodb;

create table payment_log (
 id integer auto_increment primary key,
 payment_id integer not null,
 manager_id integer not null,
 timestamp datetime not null,

 client_id integer,
 summa decimal (12,2) not null,
 summa_order decimal (12,2),
 payment_method_id integer not null,
 type integer not null, /* 0 - за подключение, 1 - абонплата или трафик, 2 - другое */
 date datetime not null,
 comment varchar(250),

 new_client_id integer,
 new_summa decimal (12,2) not null,
 new_summa_order decimal (12,2),
 new_payment_method_id integer not null,
 new_type integer not null, /* 0 - за подключение, 1 - абонплата или трафик, 2 - другое */
 new_date datetime not null,
 new_comment varchar(250),

 modify_comment varchar(250) not null,
);


create table period (
 id integer auto_increment primary key,  /* TODO Стоит заменить на smallint. Периодов не будет так много, а вот индексы уменьшаться?? */
 create_time datetime,
 service_id integer not null,
 start date not null,
 end date not null,
 comment varchar(255),
 is_closed integer not null default 0, /* Если период закрыт, значит никаких изменений в  нм и charges производить нельзя */
 /* Параметры, свойственны только сервису IPTraff */
 season_date date,
 dayshot_id integer,

 unique (service_id,start,end)
 index(start)
) type=innodb;

create table tariff_log (
 changetime timestamp not null,
 client_id integer not null,
 tariff_id integer not null,
 service_id integer not null,
 from_ym date not null,
 manager_id integer not null,
 donetime datetime,
 comment varchar(255),
 primary key (client_id, from_ym, service_id),
 index (from_ym)
) type=innodb;

CREATE INDEX ndx_tariff_log ON tariff_log (from_ym, client_id);

create table activation_log (
 client_id integer not null,
 manager_id integer not null,
 service_id integer not null,
 is_active integer not null,
 days integer not null,
 date date not null,
 comment varchar(255),
 done_time datetime,
 type integer not null default 0,  /* 0 - ручная, 1 - автоматическая из-за баланса */
 primary key  (client_id, service_id, date)
) type=innodb;

create table notice (
 client_id integer not null,
 datetime datetime not null,
 count integer not null default 1,
 type set ('warning','debt'),
 index (client_id)
) type=innodb;

create table message_log (
 id integer auto_increment primary key,
 message_type integer,
 /* 0 - просто сообщение;
    1 - отключение;
    2 - отрицательный баланс;
    3 - скоро возможно отключение;
    4 - включение;
    5 - смена тарифа;
    6 - закрытие периода;
    7 - регистрация;
    8 - оплата;
 */
 client_id integer not null,
 datetime datetime not null,
 template varchar(255) not null,
 data text,
 index (client_id,datetime)
) type=innodb;


create table charge (
 charge_time timestamp not null,
 period_id integer not null,
 client_id integer not null,

 -- Полная сумма съема за все сервисы
 summa double precision not null,
 summa_order double precision,

 -- Сумма с других сервисов (сумма subscriber_charge)
 other_summa double precision not null,
 other_summa_order double precision not null,

 -- Все, что касается трафика (базовый сервис iptraff)
 tariff_id integer,

 -- Полная сумма только за трафик
 iptraff_summa double precision not null,
 iptraff_summa_order double precision not null,

 total_days integer, /* сколько дней активен. Генерируется из activations */
 act_log varchar(35), /* журнал активаций */

 /* Параметры, свойственны только сервису IPTraff */
 traffic varchar(255),
 traffic_summa double precision,
 traffic_free bigint,

 season_summa double precision,

 -- Программа лояльности
 is_good_month integer not null default 0, -- Подходил ли месяц под программу лояльности
 good_month_cnt integer not null default 0, -- Кол-во месяцев лояльности на конец периода

 primary key (period_id, client_id),
);

create table subscriber_charge (
 id integer auto_increment primary key,

-- последнее время дергания
 timestamp timestamp not null default now(),
 period_id integer not null,

 client_id integer not null,
 service_name varchar(100) not null,

 summa double precision not null,

 is_closed integer not null default 0,

 service_charge text, -- dump данных с сервиса

 primary key (period_id, client_id, service_name)
);

commit;

create table minut_shot (
 id int unsigned auto_increment not null primary key,
 shottime datetime,
 dfrom date not null,
 dto date not null,
 from_ushot_id int,
 to_ushot_id int not null,
 bytes bigint unsigned,
 lost_bytes bigint unsigned,
 index (shottime)
);

CREATE TABLE `minut_traffic` (
  `shot_id` int(11) NOT NULL default '0',
  `router_id` int(11) NOT NULL default '0',
  `date` date NOT NULL default '0000-00-00',
  `time` time NOT NULL default '00:00:00',
  `datetime` datetime NOT NULL default '0000-00-00 00:00:00',
  `ip` int(10) unsigned NOT NULL default '0',
  `dip` int(10) unsigned NOT NULL default '0',
  `class` int(11) NOT NULL default '0',
  `direction` enum('in','out') default NULL,
  `bytes` int(10) unsigned NOT NULL default '0',
  `client_id` int(11) default NULL,
  KEY `shot_id` (`shot_id`),
  KEY `router_ip` (`router_id`,`ip`),
  KEY `date_client` (`date`,`client_id`)
) TYPE=MyISAM;

--  index (date,ip),
--  index (shot_id),
--  index (router_id),
--  index shot_ip_datetime (shot_id,ip,datetime), /* надо при установке firtwork_time, lastwork_time для host*/
--  index shot_router_datetime (shot_id,router_id,datetime), /* надо при установке firtwork_time, lastwork_time для router */

create table day_shot (
 id int unsigned auto_increment not null primary key,
 shottime datetime,
 dfrom date,
 dto date,
 from_mshot_id int,
 to_mshot_id int not null,
 bytes bigint unsigned,
 index (shottime,id)
);

CREATE TABLE `day_traffic` (
  `shot_id` int(11) NOT NULL default '0',
  `date` date NOT NULL default '0000-00-00',
  `router_id` int(11) NOT NULL default '0',
  `ip` int(10) unsigned NOT NULL default '0',
  `class` int(11) NOT NULL default '0',
  `bytes` bigint(20) unsigned NOT NULL default '0',
  `client_id` int(11) default NULL,
  KEY `shot_id` (`shot_id`),
  KEY `date_client` (`date`,`client_id`)
) TYPE=MyISAM;

#  index (shot_id), /* применяется при удалении конкретного снимка */
#  index (date,ip,class),
#  index (date,router_id), /* Трафик роутера за определённый период */
#  index (ip,class) /* Работает при выборке тарифа для расчёта вместо period,ip,class */

CREATE TABLE viruslog (
  shot_id int(10) unsigned NOT NULL default '0',
  date date not null,
  ip int(10) unsigned NOT NULL default '0',
  port int(10) unsigned NOT NULL default '0',
  bytes int(10) unsigned NOT NULL default '0',
  records int(10) unsigned NOT NULL default '0',
  packets int(10) unsigned NOT NULL default '0',
  unique (shot_id,date,ip,port)
) TYPE=MyISAM;


CREATE TABLE `traflog` (
  `shot_id` int(10) unsigned NOT NULL default '0',
  `logtime` int(10) unsigned NOT NULL default '0',
  `packettime` int(10) unsigned NOT NULL default '0',
  `src_ip` int(10) unsigned NOT NULL default '0',
  `dst_ip` int(10) unsigned NOT NULL default '0',
  `bytes` int(10) unsigned NOT NULL default '0',
  `in_iface` varchar(6) NOT NULL default '',
  `out_iface` varchar(6) NOT NULL default '',
  `prefix` varchar(10) NOT NULL default '',
  KEY `shot_id` (`shot_id`)
) TYPE=MyISAM;

CREATE TABLE `log_shot` (
  `shot_id` int(10) unsigned NOT NULL auto_increment,
  `router_id` int(11) NOT NULL default '0',
  filename varchar(80) not null,
  `filetime` datetime NOT NULL default '0000-00-00 00:00:00',
  `shottime` datetime default NULL,
  `maxlogtime` datetime default NULL,
  `minlogtime` datetime default NULL,
  `bytes` bigint(20) unsigned NOT NULL default '0',
  `virus_bytes` bigint(20) unsigned NOT NULL default '0',
  `is_removed` int(11) NOT NULL default '0',
  `count_max` int(11) default NULL,
  `count_min` int(11) default NULL,
  `type` set('ulog','trafd') default NULL,
  `collector_id` int(11) NOT NULL default '0',
  `iface` varchar(10) default NULL,
  PRIMARY KEY  (`shot_id`),
  KEY `shottime` (`shottime`),
  unique (filename),
  KEY `maxlogtime` (`maxlogtime`),
  KEY `minlogtime` (`minlogtime`),
  unique (router_id,filetime,collector_id,iface),
) TYPE=MyISAM;

commit;

create table prov_router (
  id integer auto_increment primary key,
  router_id integer,
  name varchar(100) not null,
  ip int unsigned,
  lasttime timestamp not null,
  is_checked integer not null default 0,
  do_not_check integer not null default 0,
  comment varchar(255),
);

create table prov_day_traffic (
  date date not null,
  prov_router_id int not null,
  class integer not null default 0,
  bytes bigint unsigned not null,
  index (date,class),
  index (date,prov_router_id)
);

create table order_extract (
 id integer auto_increment primary key,
 datedk date,
 dateex date,
 nm integer,
 summa decimal (12,2) not null,

 innd varchar(14) not null,
 rsd varchar(20),
 namd varchar(160),
 ksd varchar(20),
 bikd varchar(9),
 bankd varchar(50),
 cityd varchar(25),

 inn varchar(14),
 rs varchar(20),
 nam varchar(160),
 ks varchar(20),
 bik varchar(9),
 bank varchar(50),
 city varchar(25),

 naznpl varchar(250) not null,
 comment varchar(255)

);

commit;
