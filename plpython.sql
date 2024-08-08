 --- 讀取硬碟空間總共多大
CREATE OR REPLACE FUNCTION s0727.disk_total_size()
 RETURNS numeric
AS $$
  import os
  from decimal import Decimal
  return Decimal(os.popen("cd / | df --output=size | awk '{if(NR>1) sum+=$1} END {print sum}'").read()) * 1024
$$ LANGUAGE plpython3u;

--- 硬碟空間總共使用了多少
CREATE OR REPLACE FUNCTION s0727.disk_total_used_size()
 RETURNS numeric
AS $$
  import os
  from decimal import Decimal
  return Decimal(os.popen("cd / | df --output=used | awk '{if(NR>1) sum+=$1} END {print sum}'").read()) * 1024
$$ LANGUAGE plpython3u;

--- 讀取現在硬碟資訊並且轉成JSON格式
CREATE OR REPLACE FUNCTION s0727.disk_info()
 RETURNS text
AS $$
  import os
  import json
  # 執行 df 命令並獲取輸出
  output = os.popen("cd / | df").read().split('\n')
  output.pop()
  # 獲取列的標題
  keys = output[0].split()
  # 將列的標題轉換為英文
  keys = ["FileSystem", "1K_blocks", "Used", "Available", "UsePercentage", "MountedOn"]
  # 創建一個空列表來存儲結果
  result = []
  # 遍歷每一行
  for line in output[1:]:
   # 分割行並創建一個字典
   values = line.split()
   row_dict = dict(zip(keys, values))
   # 將字典添加到結果列表中
   result.append(row_dict)
   # 返回 JSON 格式的結果
  return json.dumps(result)
$$ LANGUAGE plpython3u;

--- 將 JSON 內容作為 view 呈現
create view s0727.disk_info_view as
select *
  from json_to_recordset(s0727.disk_info()::json)
    as x(
        "FileSystem" text
        , "1K_blocks" text
        , "Used" text
        , "Available" text
        , "UsePercentage" text
        , "MountedOn" text
       );
 
--- 可以查檢一下 s0727.disk_info_view
select sum("1K_blocks"::int) as total_size
     , sum("Used"::int) as total_used_size
     , sum("Available"::int) as total_free_size
  from s0727.disk_info_view;
  
--- Slack 訊息通知
CREATE OR REPLACE FUNCTION s0727.slack_notify(message text, url text)
  RETURNS VOID
AS $$
  import os
  os.system(f"curl -X POST -H 'Content-type: application/json' --data '{{\"text\":\"{message}\"}}' {url}")
$$ LANGUAGE plpython3u;

--- LINE 訊息通知
CREATE OR REPLACE FUNCTION s0727.line_notify(message text, token text)
  RETURNS VOID
AS $$
  import os
  os.system(f"curl -X POST -H 'Authorization: Bearer {token}' -F 'message={message}' https://notify-api.line.me/api/notify")
$$ LANGUAGE plpython3u;

--- Telegram 訊息通知
CREATE OR REPLACE FUNCTION s0727.telegram_notify(message text, url text, telegram_group_id text)
  RETURNS VOID
AS $$
  import os
  os.system(f"curl -X POST -H 'Content-type: application/json' --data '{{\"chat_id\":\"{telegram_group_id}\",\"text\":\"{message}\"}}' {url}")
$$ LANGUAGE plpython3u;

