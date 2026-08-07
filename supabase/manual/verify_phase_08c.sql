select
  column_name,
  data_type,
  is_nullable
from information_schema.columns
where table_schema = 'public'
  and table_name = 'profiles'
  and column_name in (
    'created_at',
    'updated_at',
    'suspended_at',
    'suspension_reason',
    'deleted_at'
  )
order by column_name;

select
  to_regclass('public.admin_user_actions') as audit_table,
  to_regprocedure(
    'public.admin_apply_user_change(uuid,uuid,text,text)'
  ) as management_rpc;

select
  routine_name,
  security_type
from information_schema.routines
where routine_schema = 'public'
  and routine_name = 'admin_apply_user_change';

select
  to_regprocedure('public.is_admin()') as active_admin_function,
  to_regprocedure('public.is_active_account()') as active_account_function,
  to_regprocedure(
    'public.enforce_active_account_mutation()'
  ) as mutation_guard_function;

select
  event_object_table,
  trigger_name
from information_schema.triggers
where trigger_schema = 'public'
  and trigger_name in (
    'profiles_active_account_update_guard',
    'businesses_active_account_write_guard',
    'business_images_active_account_write_guard'
  )
order by trigger_name;

select
  policyname,
  permissive,
  roles,
  cmd
from pg_policies
where schemaname = 'storage'
  and tablename = 'objects'
  and policyname = 'storage_active_account_access_guard';
