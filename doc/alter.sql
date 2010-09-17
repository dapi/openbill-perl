
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

  subscribe_date date not null,
  unsubscribe_date date,

  unique (client_id, service_name)
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

 unique (period_id, client_id, service_name)
);


alter table charge add iptraff_summa double precision not null;
alter table charge add iptraff_summa_order double precision not null;

alter table charge add other_summa double precision not null;
alter table charge add other_summa_order double precision not null;

update table charge set iptraff_summa=summa, iptraff_summa_order=summa_order;


-- удалить все service_id из таблицы и программ

-- проверить сколько сервисов существует
alter table collector drop service_id;
alter table tariff drop service_id;
alter table period drop service_id;
alter table tariff_log drop service_id;
alter table activation_log drop service_id;
