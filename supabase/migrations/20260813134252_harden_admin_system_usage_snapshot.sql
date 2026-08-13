-- Dalil Al Hami
-- Admin system & usage monitor - hardened read-only RPC.

create or replace function public.admin_system_usage_snapshot()
returns jsonb
language plpgsql
security invoker
set search_path = public, storage, pg_catalog
as $$
declare
  v_database_bytes bigint := 0;
  v_storage_bytes bigint := 0;
  v_bucket_usage jsonb := '[]'::jsonb;
  v_table_usage jsonb := '[]'::jsonb;
  v_top_files jsonb := '[]'::jsonb;
  v_counts jsonb := '{}'::jsonb;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'ADMIN_ACCESS_REQUIRED' using errcode = '42501';
  end if;

  v_database_bytes := pg_database_size(current_database());

  select coalesce(
    sum(coalesce((object.metadata ->> 'size')::bigint, 0)),
    0
  )::bigint
    into v_storage_bytes
  from storage.objects object
  where object.bucket_id in (
    'business-media',
    'advertisements',
    'avatars',
    'category-media'
  );

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
      bucket.id as bucket_id,
      count(object.id)::bigint as file_count,
      coalesce(
        sum(coalesce((object.metadata ->> 'size')::bigint, 0)),
        0
      )::bigint as bytes
    from storage.buckets bucket
    left join storage.objects object
      on object.bucket_id = bucket.id
    where bucket.id in (
      'business-media',
      'advertisements',
      'avatars',
      'category-media'
    )
    group by bucket.id
  ) usage;

  -- pg_stat_user_tables gives metadata estimates without bypassing RLS or
  -- exposing row contents from tables whose normal SELECT policy is user-scoped.
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'table_name', stats.relname,
        'row_count', greatest(stats.n_live_tup, 0)::bigint,
        'bytes', pg_total_relation_size(stats.relid)::bigint
      )
      order by pg_total_relation_size(stats.relid) desc, stats.relname
    ),
    '[]'::jsonb
  )
  into v_table_usage
  from pg_stat_user_tables stats
  where stats.schemaname = 'public'
    and stats.relname in (
      'profiles',
      'categories',
      'businesses',
      'business_images',
      'advertisements',
      'app_notifications',
      'app_notification_reads',
      'favorites',
      'business_ratings',
      'reports',
      'device_tokens',
      'push_notification_devices'
    );

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'bucket_id', file.bucket_id,
        'name', file.name,
        'bytes', file.bytes,
        'created_at', file.created_at
      )
      order by file.bytes desc, file.created_at desc
    ),
    '[]'::jsonb
  )
  into v_top_files
  from (
    select
      object.bucket_id,
      object.name,
      coalesce((object.metadata ->> 'size')::bigint, 0)::bigint as bytes,
      object.created_at
    from storage.objects object
    where object.bucket_id in (
      'business-media',
      'advertisements',
      'avatars',
      'category-media'
    )
    order by
      coalesce((object.metadata ->> 'size')::bigint, 0) desc,
      object.created_at desc
    limit 10
  ) file;

  -- These tables already expose all rows to an authenticated administrator via
  -- their existing RLS policies, so exact content counts remain RLS-respecting.
  select jsonb_build_object(
    'registered_users',
      (select count(*)::bigint
       from public.profiles
       where deleted_at is null),
    'active_users',
      (select count(*)::bigint
       from public.profiles
       where deleted_at is null
         and is_active = true),
    'categories',
      (select count(*)::bigint
       from public.categories
       where deleted_at is null),
    'businesses',
      (select count(*)::bigint
       from public.businesses
       where deleted_at is null),
    'advertisements',
      (select count(*)::bigint
       from public.advertisements
       where deleted_at is null),
    'business_images',
      (select count(*)::bigint
       from public.business_images
       where deleted_at is null)
  )
  into v_counts;

  return jsonb_build_object(
    'captured_at', timezone('utc', now()),
    'database_bytes', v_database_bytes,
    'storage_bytes', v_storage_bytes,
    'bucket_usage', v_bucket_usage,
    'table_usage', v_table_usage,
    'top_files', v_top_files,
    'counts', v_counts
  );
end;
$$;

revoke all on function public.admin_system_usage_snapshot() from public;
revoke all on function public.admin_system_usage_snapshot() from anon;
grant execute on function public.admin_system_usage_snapshot() to authenticated;

comment on function public.admin_system_usage_snapshot() is
  'Admin-only read-only snapshot for Dalil Al Hami database and Storage usage monitoring.';
