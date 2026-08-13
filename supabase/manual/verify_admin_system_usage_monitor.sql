-- Run in the Supabase SQL editor as a privileged operator.
-- This verification does not modify data.

select
  has_function_privilege(
    'authenticated',
    'public.admin_system_usage_snapshot()',
    'EXECUTE'
  ) as authenticated_can_execute,
  has_function_privilege(
    'anon',
    'public.admin_system_usage_snapshot()',
    'EXECUTE'
  ) as anon_can_execute;

select
  pg_database_size(current_database()) as database_bytes,
  pg_size_pretty(pg_database_size(current_database())) as database_pretty;

select
  bucket.id as bucket_id,
  count(object.id) as file_count,
  coalesce(sum(coalesce((object.metadata ->> 'size')::bigint, 0)), 0) as bytes
from storage.buckets bucket
left join storage.objects object on object.bucket_id = bucket.id
where bucket.id in (
  'business-media',
  'advertisements',
  'avatars',
  'category-media'
)
group by bucket.id
order by bytes desc;
