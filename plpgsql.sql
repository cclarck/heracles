--- 硬碟剩餘空間總共多少
CREATE OR REPLACE FUNCTION s0727.disk_total_free_size()
 RETURNS numeric
AS $$
BEGIN
RETURN (SELECT s0727.disk_total_size() - s0727.disk_total_used_size());
END;
$$ LANGUAGE plpgsql;

--- 讀取硬碟剩餘空間百分比
CREATE OR REPLACE FUNCTION s0727.disk_free_percentage()
 RETURNS double precision
AS $$
BEGIN
RETURN (SELECT s0727.disk_total_free_size()::float / s0727.disk_total_size()::float * 100);
END;
$$ LANGUAGE plpgsql;

--- 建立寫入硬碟數值的 function
CREATE OR REPLACE FUNCTION s0727.add_disk_data()
 RETURNS void
AS $$
BEGIN
   BEGIN
       INSERT INTO s0727.disk_data (hardware_id, total_used_size)
       SELECT id
            , s0727.disk_total_used_size()
         FROM s0727.hardware h;
   EXCEPTION WHEN others THEN
       -- 在這裡處理錯誤，例如，您可以選擇記錄錯誤信息
       -- RAISE NOTICE 'An error occurred: %', SQLERRM;
       RETURN;
   END;
END;
$$ LANGUAGE plpgsql;

--- 取得還未發送的 events
CREATE OR REPLACE FUNCTION s0727.get_unnotified_events()
RETURNS TABLE(id bigint, monitor_config_id bigint, event_remark text, created_at timestamptz)
AS $$
BEGIN
 RETURN QUERY
 SELECT e.id
      , e.monitor_config_id
      , e.event_remark
      , e.created_at
 FROM s0727.monitor_events e
 LEFT JOIN s0727.notify n
   ON e.id = n.event_id
WHERE n.event_id IS NULL;
END;
$$ LANGUAGE plpgsql;

--- 發訊息函式
CREATE OR REPLACE FUNCTION s0727.heracles_fn_notify()
 RETURNS void
AS $$
DECLARE
  local_config_row s0727.config%ROWTYPE;
  local_message_text text;
  local_total_size numeric;
  local_used_size numeric;
  local_free_size numeric; --- 剩於空間
  local_free_size_human_read float; --- 剩於空間，轉型
  local_free_percentage float; --- 剩於空間百分比
  local_free_percentage_human_read float; --- 剩於空間百分比，轉型
  local_monitor_setting_json json;
  local_size numeric;
  local_percentage float; --- 預警空間百分比
  local_percentage_human_read float; --- 預警空間百分比，轉型
BEGIN
  SELECT * INTO local_config_row
    FROM s0727.config
   WHERE is_notify is true;
IF local_config_row.is_notify THEN
  SELECT "message" INTO local_message_text
    FROM s0727.canned_messages
   WHERE type_id = 1;
  local_total_size := s0727.disk_total_size();
  local_used_size := s0727.disk_total_used_size();
  local_free_size := s0727.disk_total_free_size();
  local_free_size_human_read = round(local_free_size::double precision);
  local_free_percentage := s0727.disk_free_percentage();
  local_free_percentage_human_read = round(local_free_percentage::double precision);
  SELECT monitor_setting INTO local_monitor_setting_json
    FROM s0727.monitor_config
   WHERE hardware_id = 1;
  local_size := (local_monitor_setting_json->>'size')::numeric;
  local_percentage := (local_monitor_setting_json->>'percentage')::double precision;
  local_percentage_human_read = round(local_percentage);

  local_message_text := REPLACE(local_message_text, '{total_size}',
  pg_size_pretty(local_total_size));

  local_message_text := REPLACE(local_message_text, '{used_size}',
  pg_size_pretty(local_used_size));

  local_message_text := REPLACE(local_message_text, '{free_size}',
  pg_size_pretty(local_free_size));

  local_message_text := REPLACE(local_message_text, '{free_percentage}',
  local_free_percentage_human_read::text || '%');

  local_message_text := REPLACE(local_message_text, '{size}', pg_size_pretty(local_size));

  local_message_text := REPLACE(local_message_text, '{percentage}',
  local_percentage_human_read::text || '%');

  IF local_config_row.slack_url IS NOT NULL THEN
    PERFORM s0727.slack_notify(local_message_text, local_config_row.slack_url);
  END IF;
  IF local_config_row.line_token IS NOT NULL THEN
    PERFORM s0727.line_notify(local_message_text, local_config_row.line_token);
  END IF;
  IF local_config_row.telegram_url IS NOT NULL THEN
    PERFORM s0727.telegram_notify(local_message_text,local_config_row.telegram_url,local_config_row.telegram_group_id);
  END IF;
END IF;
END;
$$ LANGUAGE plpgsql;

--- 未發送的發送並且寫到 heracles_fn_notify
CREATE OR REPLACE FUNCTION s0727.send_and_record_notify()
RETURNS VOID
AS $$
DECLARE
 event_row RECORD;
BEGIN
 FOR event_row IN SELECT *
                    FROM s0727.get_unnotified_events()
 LOOP
   PERFORM s0727.heracles_fn_notify();
   INSERT INTO s0727.notify (event_id)
   VALUES (event_row.id);
 END LOOP;
END;
$$ LANGUAGE plpgsql;

--- Trigger：建立檢查硬碟使用情況之 function，接著設定 trigger 呼叫function 檢查硬碟使用情況
CREATE OR REPLACE FUNCTION s0727.check_disk_usage()
RETURNS TRIGGER AS $$
DECLARE
monitor_setting_json json;
total_used_size bigint;
size bigint;
percentage bigint;
hardware_type_name text;
monitor_config_id bigint;
BEGIN
-- Get the total used size from the new disk data
total_used_size := NEW.total_used_size;
-- Get the monitor setting
SELECT monitor_setting INTO monitor_setting_json
 FROM s0727.monitor_config
WHERE hardware_id = NEW.hardware_id;

SELECT id INTO monitor_config_id
 FROM s0727.monitor_config
WHERE hardware_id = NEW.hardware_id;

size := (monitor_setting_json->>'size')::bigint;
percentage := (monitor_setting_json->>'percentage')::bigint;

-- Check if the total used size exceeds the size or percentage in the monitor setting
IF total_used_size >= size OR s0727.disk_free_percentage() >= percentage THEN
-- Get the hardware type name
SELECT hardware_type.name INTO hardware_type_name
  FROM s0727.monitor_config
  JOIN s0727.hardware
    ON monitor_config.hardware_id = hardware.id
  JOIN s0727.hardware_type ON hardware_type.id = hardware.type_id
 WHERE hardware.id = NEW.hardware_id;
 -- Insert a new event into the monitor_events table
INSERT INTO s0727.monitor_events (monitor_config_id, event_remark)
VALUES (monitor_config_id, hardware_type_name);
END IF;

RETURN NEW;
EXCEPTION
WHEN OTHERS THEN
  RAISE NOTICE '錯誤訊息：%', SQLERRM;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

--- 設定 Trigger
CREATE TRIGGER disk_data_inserted
AFTER INSERT ON s0727.disk_data
FOR EACH ROW
EXECUTE FUNCTION s0727.check_disk_usage();



