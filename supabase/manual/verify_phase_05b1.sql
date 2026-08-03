-- دليل الحامي
-- فحص المرحلة 05B-1 للقراءة فقط

select
  'categories' as entity_type,
  count(*) as total,
  max(sync_version) as latest_version
from public.categories
union all
select
  'businesses',
  count(*),
  max(sync_version)
from public.businesses
union all
select
  'advertisements',
  count(*),
  max(sync_version)
from public.advertisements;

select
  entity_type,
  entity_id,
  deleted_at,
  sync_version
from public.directory_sync_tombstones
order by sync_version desc
limit 20;

select public.get_directory_changes(0) as full_snapshot;

with sync_state as (
  select greatest(
    coalesce((select max(sync_version) from public.categories), 0),
    coalesce((select max(sync_version) from public.businesses), 0),
    coalesce((select max(sync_version) from public.advertisements), 0),
    coalesce((
      select max(sync_version)
      from public.directory_sync_tombstones
    ), 0)
  ) as latest_version
)
select public.get_directory_changes(
  greatest(latest_version - 5, 0)
) as recent_changes
from sync_state;
