--- 建立一個使用者 記得給密碼 postgrest需要用到
CREATE USER heracles_viewer WITH PASSWORD 'heracles_viewer_test';
--- 這邊先給他管理員權限
ALTER ROLE heracles_viewer SUPERUSER;

---記得把連線到資料庫的權線給 heracles_viewer 使用者
grant connect on database heracles to heracles_viewer;

---並把 s0727 schema使用權 給 heracles_viewer 使用者
grant usage on schema s0727 to heracles_viewer;

--- config 可以參考 mywebapi.conf
