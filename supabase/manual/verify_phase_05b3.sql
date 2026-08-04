-- تحقق يدوي من المرحلة 05B-3
select
  to_regclass('public.directory_sync_conflicts') is not null
    as conflict_table_exists,
  to_regprocedure(
    'public.resolve_directory_sync_conflict(uuid,text,text)'
  ) is not null as conflict_resolution_rpc_exists,
  to_regprocedure(
    'public.process_directory_sync_operation(text,text,text,uuid,jsonb)'
  ) is not null as guarded_sync_rpc_exists;
