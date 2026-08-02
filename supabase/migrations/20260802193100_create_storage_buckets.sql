-- دليل الحامي
-- المرحلة 03A: حاويات التخزين وسياسات الوصول

begin;

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
    2097152,
    array['image/jpeg', 'image/png', 'image/webp']
  ),
  (
    'advertisements',
    'advertisements',
    true,
    5242880,
    array['image/jpeg', 'image/png', 'image/webp']
  )
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- القراءة العامة للصور المنشورة
create policy storage_public_read_directory_media
on storage.objects
for select
to anon, authenticated
using (
  bucket_id in ('business-media', 'avatars', 'advertisements')
);

-- صور الأنشطة:
-- يجب أن يبدأ المسار بمعرف النشاط:
-- <business_uuid>/<file_name.webp>
create policy storage_business_media_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'business-media'
  and exists (
    select 1
    from public.businesses b
    where b.id::text = (storage.foldername(name))[1]
      and (
        b.owner_id = (select auth.uid())
        or public.is_admin()
      )
  )
);

create policy storage_business_media_update
on storage.objects
for update
to authenticated
using (
  bucket_id = 'business-media'
  and exists (
    select 1
    from public.businesses b
    where b.id::text = (storage.foldername(name))[1]
      and (
        b.owner_id = (select auth.uid())
        or public.is_admin()
      )
  )
)
with check (
  bucket_id = 'business-media'
  and exists (
    select 1
    from public.businesses b
    where b.id::text = (storage.foldername(name))[1]
      and (
        b.owner_id = (select auth.uid())
        or public.is_admin()
      )
  )
);

create policy storage_business_media_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'business-media'
  and exists (
    select 1
    from public.businesses b
    where b.id::text = (storage.foldername(name))[1]
      and (
        b.owner_id = (select auth.uid())
        or public.is_admin()
      )
  )
);

-- الصور الشخصية:
-- يجب أن يبدأ المسار بمعرف المستخدم:
-- <auth_user_uuid>/<file_name.webp>
create policy storage_avatars_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy storage_avatars_update
on storage.objects
for update
to authenticated
using (
  bucket_id = 'avatars'
  and (
    owner_id = (select auth.uid())::text
    or public.is_admin()
  )
)
with check (
  bucket_id = 'avatars'
  and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or public.is_admin()
  )
);

create policy storage_avatars_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'avatars'
  and (
    owner_id = (select auth.uid())::text
    or public.is_admin()
  )
);

-- صور الإعلانات: المدير فقط
create policy storage_advertisements_admin_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'advertisements'
  and public.is_admin()
);

create policy storage_advertisements_admin_update
on storage.objects
for update
to authenticated
using (
  bucket_id = 'advertisements'
  and public.is_admin()
)
with check (
  bucket_id = 'advertisements'
  and public.is_admin()
);

create policy storage_advertisements_admin_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'advertisements'
  and public.is_admin()
);

commit;
