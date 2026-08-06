select
  to_regclass('public.business_images') as business_images_table,
  to_regprocedure('public.manage_business_gallery(uuid,text,uuid,text,text,text,boolean,uuid[])')
    as manage_gallery_rpc,
  to_regprocedure('public.finalize_owner_business_media(uuid,text,text,jsonb)')
    as finalize_media_rpc,
  to_regprocedure('public.admin_get_media_overview()')
    as media_overview_rpc,
  to_regprocedure('public.admin_media_cleanup_candidates()')
    as cleanup_candidates_rpc;

select
  column_name,
  data_type,
  is_nullable
from information_schema.columns
where table_schema = 'public'
  and table_name = 'business_images'
  and column_name in (
    'public_url', 'is_primary', 'updated_at', 'deleted_at', 'sync_version'
  )
order by column_name;

select
  indexname,
  indexdef
from pg_indexes
where schemaname = 'public'
  and tablename = 'business_images'
order by indexname;

select
  to_regprocedure('public.can_manage_business_storage_path(text)')
    as business_storage_guard;

select
  policyname,
  cmd,
  roles,
  qual,
  with_check
from pg_policies
where schemaname = 'storage'
  and tablename = 'objects'
  and policyname in (
    'storage_business_media_owner_final_insert',
    'storage_business_media_owner_final_update',
    'storage_business_media_owner_final_delete',
    'storage_avatar_owner_insert',
    'storage_avatar_owner_update',
    'storage_avatar_owner_delete',
    'storage_avatar_admin_delete_all'
  )
order by policyname;
