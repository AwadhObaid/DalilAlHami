-- Dalil Al Hami
-- Phase 08A-2 v5: storage ownership policies for final business media and avatars

begin;

-- Keep the two user-upload buckets available as public image buckets. Existing
-- buckets retain any larger size limit, while image MIME restrictions remain
-- explicit.
insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values
  (
    'business-media',
    'business-media',
    true,
    5242880,
    array['image/jpeg', 'image/png', 'image/webp']
  ),
  (
    'avatars',
    'avatars',
    true,
    5242880,
    array['image/jpeg', 'image/png', 'image/webp']
  )
on conflict (id) do update
set
  public = true,
  file_size_limit = greatest(
    coalesce(storage.buckets.file_size_limit, 0),
    excluded.file_size_limit
  ),
  allowed_mime_types = excluded.allowed_mime_types;

-- Storage object paths for saved businesses use:
--   <business_uuid>/<logo|cover|gallery>-<timestamp>.jpg
-- Resolve that first path segment through a security-definer helper so the
-- storage policy is not affected by the caller's businesses-table RLS.
create or replace function public.can_manage_business_storage_path(
  p_name text
)
returns boolean
language sql
stable
security definer
set search_path = public, storage, pg_temp
as $$
  select exists (
    select 1
    from public.businesses business
    where business.id::text = (storage.foldername(p_name))[1]
      and business.deleted_at is null
      and (
        business.owner_id = (select auth.uid())
        or public.is_admin()
      )
  );
$$;

revoke all on function public.can_manage_business_storage_path(text)
  from public;
grant execute on function public.can_manage_business_storage_path(text)
  to authenticated;

-- Saved-business media: owners may write only below a business they own.
-- Administrators are accepted by the same guarded helper.
drop policy if exists storage_business_media_owner_final_insert
  on storage.objects;
create policy storage_business_media_owner_final_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'business-media'
  and (storage.foldername(name))[2] is null
  and public.can_manage_business_storage_path(name)
);

drop policy if exists storage_business_media_owner_final_update
  on storage.objects;
create policy storage_business_media_owner_final_update
on storage.objects
for update
to authenticated
using (
  bucket_id = 'business-media'
  and (storage.foldername(name))[2] is null
  and public.can_manage_business_storage_path(name)
)
with check (
  bucket_id = 'business-media'
  and (storage.foldername(name))[2] is null
  and public.can_manage_business_storage_path(name)
);

drop policy if exists storage_business_media_owner_final_delete
  on storage.objects;
create policy storage_business_media_owner_final_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'business-media'
  and (storage.foldername(name))[2] is null
  and public.can_manage_business_storage_path(name)
);

-- Profile avatars use:
--   <authenticated_user_uuid>/avatar-<timestamp>.jpg
-- A user can never write to another user's folder.
drop policy if exists storage_avatar_owner_insert
  on storage.objects;
create policy storage_avatar_owner_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and (storage.foldername(name))[2] is null
);

drop policy if exists storage_avatar_owner_update
  on storage.objects;
create policy storage_avatar_owner_update
on storage.objects
for update
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and (storage.foldername(name))[2] is null
)
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and (storage.foldername(name))[2] is null
);

drop policy if exists storage_avatar_owner_delete
  on storage.objects;
create policy storage_avatar_owner_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and (storage.foldername(name))[2] is null
);

-- The guarded administrator orphan cleaner also needs to remove unreferenced
-- avatar objects. Candidate discovery and revalidation remain server-side.
drop policy if exists storage_avatar_admin_delete_all
  on storage.objects;
create policy storage_avatar_admin_delete_all
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'avatars'
  and public.is_admin()
);

comment on function public.can_manage_business_storage_path(text) is
  'Checks whether the current user owns or administrates the business folder in a storage object path.';

commit;
