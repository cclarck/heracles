--- every 1 mintues checking hard disk 

select cron.schedule('*/1 * * * *', $$select add_disk_data()$$);

--- every 1 mintues send notification
select cron.schedule('*/1 * * * *', $$select send_and_record_notify()$$);

