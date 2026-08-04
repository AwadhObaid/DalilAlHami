select
  to_regclass('public.directory_sync_operation_receipts')
    as receipts_table,
  to_regprocedure(
    'public.process_directory_sync_operation(text,text,text,uuid,jsonb)'
  ) as process_function;

select
  operation_id,
  user_id,
  entity_type,
  operation_type,
  entity_id,
  created_at
from public.directory_sync_operation_receipts
order by created_at desc
limit 10;
