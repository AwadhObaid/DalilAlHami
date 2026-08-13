-- Dalil Al Hami
-- Admin system usage monitor v4
-- Read-only bucket distribution RPC that preserves Storage RLS.

create or replace function public.admin_system_bucket_usage()
returns jsonb
language plpgsql
stable
security invoker
set search_path = public, storage, pg_catalog
as $$
declare
  v_bucket_usage jsonb := '[]'::jsonb;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'ADMIN_ACCESS_REQUIRED' using errcode = '42501';
  end if;

  -- Do not depend on storage.buckets visibility. The application uses four
  -- known buckets, so aggregate the storage.objects rows visible through the
  -- existing Storage RLS policy and preserve zero-file buckets with VALUES.
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'bucket_id', usage.bucket_id,
        'file_count', usage.file_count,
        'bytes', usage.bytes
      )
      order by usage.bytes desc, usage.bucket_id
    ),
    '[]'::jsonb
  )
  into v_bucket_usage
  from (
    select
      bucket.bucket_id,
      count(object.id)::bigint as file_count,
      coalesce(
        sum(coalesce((object.metadata ->> 'size')::bigint, 0)),
        0
      )::bigint as bytes
    from (
      values
        ('business-media'::text),
        ('advertisements'::text),
        ('avatars'::text),
        ('category-media'::text)
    ) as bucket(bucket_id)
    left join storage.objects object
      on object.bucket_id = bucket.bucket_id
    group by bucket.bucket_id
  ) usage;

  return v_bucket_usage;
end;
$$;

revoke all on function public.admin_system_bucket_usage() from public;
revoke all on function public.admin_system_bucket_usage() from anon;
grant execute on function public.admin_system_bucket_usage() to authenticated;

comment on function public.admin_system_bucket_usage() is
  'Admin-only read-only bucket distribution for Dalil Al Hami system usage monitoring.';
