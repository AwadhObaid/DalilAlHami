select version
from supabase_migrations.schema_migrations
where version = '20260806003000';

select proname
from pg_proc
join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
where pg_namespace.nspname = 'public'
  and proname in (
    'admin_upsert_category',
    'admin_set_category_active',
    'admin_delete_category',
    'admin_upsert_business',
    'admin_manage_business',
    'admin_delete_business'
  )
order by proname;

select to_regclass('public.admin_content_actions') as audit_table;
