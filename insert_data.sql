 --- 設定發送通知平台
insert into s0727.config (line_token,slack_url,telegram_url,telegram_group_id,is_notify) 
values ('your_line_token'
,'your_slack_url'
,'your_telegram_url','your_telegram_group_id'
,false);

--- 被監控的硬體元件
insert into s0727.hardware_type (name) values ('disk');

--- 被監控的Server
insert into s0727.servers (name) values ('海克力斯測試機');

--- 建立硬體資訊清單
insert into s0727.hardware (type_id,name,hardware_info,server_id)
select id
     , '資料庫硬碟'
     , ('{"disk_type":"ssd","disk_size" : ' || s0727.disk_total_size() || '}')::json
     , (select id from s0727.servers where name = '海克力斯測試機')
  from s0727.hardware_type
 where name = 'disk';
 
--- 監控設定, 單位是 byte，如果設定 600GB 記得換算到 byte
insert into s0727.monitor_config (hardware_id,monitor_setting)
select id
     , '{"percentage":60,"size":200}'::json
  from s0727.hardware
 where id = 1;
 
--- 設定訊息格式
insert into s0727.canned_messages (type_id,message)
select id
     , '硬碟預警通知 總空間:{total_size} 使用總空間:{used_size} 剩餘空間:{free_size} 目前剩餘空間百分比:{free_percentage} 預警空間值:{size} 預警空間百分比:{percentage}'
  from s0727.hardware_type
 where name = 'disk';

