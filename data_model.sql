

create database heracles;

\c heracles 

create schema s0727;

CREATE TABLE s0727.config (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 line_token text,
 slack_url text,
 telegram_url text,
 telegram_group_id text,
 is_notify bool DEFAULT false
);

CREATE TABLE s0727.servers (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 name text,
 ip cidr DEFAULT '127.0.0.1',
 remark text
);

CREATE TABLE s0727.hardware_type (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 name text
);

CREATE TABLE s0727.hardware (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 type_id bigint REFERENCES s0727.hardware_type(id),
 server_id bigint REFERENCES s0727.servers(id),
 name text,
 hardware_info json,
 remark text
);

CREATE TABLE s0727.monitor_config (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 hardware_id bigint REFERENCES s0727.hardware(id),
 monitor_setting json,
 remark text
);

CREATE TABLE s0727.monitor_events (
 id bigint GENERATED ALWAYS AS IDENTITY,
 monitor_config_id bigint,
 event_remark text,
 created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE s0727.disk_data (
 id bigint GENERATED ALWAYS AS IDENTITY,
 hardware_id bigint,
 total_used_size bigint not null,
 created_at timestamptz not NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE s0727.notify (
 id bigint GENERATED ALWAYS AS IDENTITY,
 event_id bigint,
 created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE s0727.canned_messages (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 type_id bigint REFERENCES s0727.hardware_type(id),
 message text
);
