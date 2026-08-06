select version
from supabase_migrations.schema_migrations
where version = '20260806133000';

select proname
from pg_proc
join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
where pg_namespace.nspname = 'public'
  and proname in (
    'admin_upsert_advertisement',
    'admin_set_advertisement_active',
    'admin_delete_advertisement',
    'get_directory_changes'
  )
order by proname;

select conname, pg_get_constraintdef(oid)
from pg_constraint
where conrelid = 'public.admin_content_actions'::regclass
  and conname = 'admin_content_actions_entity_type_check';
