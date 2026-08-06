select
  to_regprocedure(
    'public.owner_set_business_location(uuid,numeric,numeric)'
  ) as owner_location_rpc,
  to_regprocedure('public.get_directory_changes(bigint)')
    as directory_changes_rpc;

select
  column_name,
  data_type,
  is_nullable
from information_schema.columns
where table_schema = 'public'
  and table_name = 'businesses'
  and column_name in ('latitude', 'longitude')
order by column_name;

select
  routine_name,
  security_type
from information_schema.routines
where routine_schema = 'public'
  and routine_name in (
    'owner_set_business_location',
    'get_directory_changes'
  )
order by routine_name;
