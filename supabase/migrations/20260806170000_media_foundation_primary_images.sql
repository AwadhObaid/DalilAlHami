-- Dalil Al Hami
-- Phase 08A-1: media foundation, storage RLS, and dual advertisement images

begin;

alter table public.advertisements
  add column if not exists compact_image_path text;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'category-media',
  'category-media',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists storage_public_read_directory_media
  on storage.objects;
create policy storage_public_read_directory_media
on storage.objects
for select
to anon, authenticated
using (
  bucket_id in (
    'business-media',
    'avatars',
    'advertisements',
    'category-media'
  )
);

drop policy if exists storage_category_media_admin_insert
  on storage.objects;
create policy storage_category_media_admin_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'category-media'
  and public.is_admin()
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists storage_category_media_admin_update
  on storage.objects;
create policy storage_category_media_admin_update
on storage.objects
for update
to authenticated
using (
  bucket_id = 'category-media'
  and public.is_admin()
)
with check (
  bucket_id = 'category-media'
  and public.is_admin()
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists storage_category_media_admin_delete
  on storage.objects;
create policy storage_category_media_admin_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'category-media'
  and public.is_admin()
);

-- Admin-created businesses do not have an id until the first save. Draft
-- media is therefore isolated under drafts/<admin_uid>/ and remains writable
-- only by active administrators.
drop policy if exists storage_business_media_admin_draft_insert
  on storage.objects;
create policy storage_business_media_admin_draft_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'business-media'
  and public.is_admin()
  and (storage.foldername(name))[1] = 'drafts'
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

drop policy if exists storage_business_media_admin_draft_update
  on storage.objects;
create policy storage_business_media_admin_draft_update
on storage.objects
for update
to authenticated
using (
  bucket_id = 'business-media'
  and public.is_admin()
  and (storage.foldername(name))[1] = 'drafts'
  and (storage.foldername(name))[2] = (select auth.uid())::text
)
with check (
  bucket_id = 'business-media'
  and public.is_admin()
  and (storage.foldername(name))[1] = 'drafts'
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

drop policy if exists storage_business_media_admin_draft_delete
  on storage.objects;
create policy storage_business_media_admin_draft_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'business-media'
  and public.is_admin()
  and (storage.foldername(name))[1] = 'drafts'
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

-- Remove the previous nine-argument RPC before publishing the media-aware
-- version. Parameter names are kept explicit for reliable PostgREST routing.
drop function if exists public.admin_upsert_advertisement(
  uuid, uuid, text, text, text, text, timestamptz, timestamptz, integer
);

create or replace function public.admin_upsert_advertisement(
  p_advertisement_id uuid,
  p_business_id uuid,
  p_title text,
  p_image_path text,
  p_compact_image_path text,
  p_target_url text,
  p_placement text,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_sort_order integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_advertisement public.advertisements%rowtype;
  v_before jsonb;
  v_action text;
  v_title text := btrim(coalesce(p_title, ''));
  v_image_path text := btrim(coalesce(p_image_path, ''));
  v_compact_image_path text := nullif(
    btrim(coalesce(p_compact_image_path, '')),
    ''
  );
  v_target_url text := nullif(btrim(coalesce(p_target_url, '')), '');
  v_placement text := coalesce(
    nullif(btrim(coalesce(p_placement, '')), ''),
    'home_top'
  );
begin
  if not public.is_admin() then
    raise exception 'Administrator access is required.' using errcode = '42501';
  end if;

  if length(v_title) < 2 then
    raise exception 'Advertisement title is required.' using errcode = '22023';
  end if;
  if length(v_image_path) < 3 then
    raise exception 'Advertisement image path is required.' using errcode = '22023';
  end if;
  if v_placement not in (
    'home_top', 'home_middle', 'category', 'business_list'
  ) then
    raise exception 'Advertisement placement is invalid.' using errcode = '22023';
  end if;
  if p_business_id is not null and v_target_url is not null then
    raise exception 'Advertisement can have only one target.' using errcode = '22023';
  end if;
  if v_target_url is not null and v_target_url !~* '^https?://[^[:space:]]+$' then
    raise exception 'Advertisement target URL is invalid.' using errcode = '22023';
  end if;
  if p_starts_at is not null and
      p_ends_at is not null and
      p_ends_at <= p_starts_at then
    raise exception 'Advertisement end must be after start.' using errcode = '22023';
  end if;
  if p_business_id is not null and not exists (
    select 1
    from public.businesses business
    where business.id = p_business_id
      and business.status = 'approved'
      and business.is_active = true
      and business.deleted_at is null
  ) then
    raise exception 'Advertisement business target is unavailable.' using errcode = '22023';
  end if;

  if p_advertisement_id is null then
    insert into public.advertisements (
      business_id,
      title,
      image_path,
      compact_image_path,
      target_url,
      placement,
      starts_at,
      ends_at,
      sort_order,
      is_active,
      created_by
    )
    values (
      p_business_id,
      v_title,
      v_image_path,
      v_compact_image_path,
      v_target_url,
      v_placement,
      p_starts_at,
      p_ends_at,
      greatest(coalesce(p_sort_order, 0), 0),
      true,
      (select auth.uid())
    )
    returning * into v_advertisement;
    v_before := null;
    v_action := 'created';
  else
    select to_jsonb(advertisement.*)
    into v_before
    from public.advertisements advertisement
    where advertisement.id = p_advertisement_id
    for update;

    if not found then
      raise exception 'Advertisement was not found.' using errcode = 'P0002';
    end if;

    update public.advertisements advertisement
    set
      business_id = p_business_id,
      title = v_title,
      image_path = v_image_path,
      compact_image_path = v_compact_image_path,
      target_url = v_target_url,
      placement = v_placement,
      starts_at = p_starts_at,
      ends_at = p_ends_at,
      sort_order = greatest(coalesce(p_sort_order, 0), 0)
    where advertisement.id = p_advertisement_id
    returning advertisement.* into v_advertisement;
    v_action := 'updated';
  end if;

  perform public.admin_record_content_action(
    'advertisement',
    v_advertisement.id,
    v_action,
    null,
    v_before,
    to_jsonb(v_advertisement)
  );

  return jsonb_build_object(
    'entity_id', v_advertisement.id,
    'entity_type', 'advertisement',
    'action', v_action,
    'message', case when v_action = 'created'
      then 'تمت إضافة الإعلان وتفعيله.'
      else 'تم تحديث الإعلان.'
    end
  );
end;
$$;

create or replace function public.get_directory_changes(
  p_after_version bigint default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_after_version bigint := greatest(coalesce(p_after_version, 0), 0);
  v_server_version bigint;
  v_is_full_snapshot boolean;
begin
  select greatest(
    coalesce((select max(sync_version) from public.categories), 0),
    coalesce((select max(sync_version) from public.businesses), 0),
    coalesce((select max(sync_version) from public.advertisements), 0),
    coalesce((
      select max(sync_version)
      from public.directory_sync_tombstones
    ), 0)
  )
  into v_server_version;

  if v_after_version > v_server_version then
    v_after_version := 0;
  end if;

  v_is_full_snapshot := v_after_version = 0;

  return jsonb_build_object(
    'server_version', v_server_version,
    'is_full_snapshot', v_is_full_snapshot,
    'categories', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', c.id,
          'name_ar', c.name_ar,
          'slug', c.slug,
          'icon_name', c.icon_name,
          'image_url', c.image_url,
          'sort_order', c.sort_order,
          'display_group', c.display_group,
          'updated_at', c.updated_at,
          'deleted_at', c.deleted_at,
          'sync_version', c.sync_version
        )
        order by c.sort_order, c.name_ar
      )
      from public.categories c
      where c.sync_version > v_after_version
        and c.sync_version <= v_server_version
        and c.is_active = true
        and c.deleted_at is null
    ), '[]'::jsonb),
    'deleted_category_ids', coalesce((
      select jsonb_agg(changes.entity_id order by changes.sync_version)
      from (
        select c.id::text as entity_id, c.sync_version
        from public.categories c
        where c.sync_version > v_after_version
          and c.sync_version <= v_server_version
          and (c.is_active = false or c.deleted_at is not null)
        union all
        select t.entity_id::text, t.sync_version
        from public.directory_sync_tombstones t
        where t.entity_type = 'categories'
          and t.sync_version > v_after_version
          and t.sync_version <= v_server_version
      ) changes
    ), '[]'::jsonb),
    'businesses', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', b.id,
          'category_id', b.category_id,
          'name', b.name,
          'description', b.description,
          'phone', b.phone,
          'whatsapp', b.whatsapp,
          'address', b.address,
          'logo_url', b.logo_url,
          'cover_url', b.cover_url,
          'is_featured', b.is_featured,
          'created_at', b.created_at,
          'updated_at', b.updated_at,
          'deleted_at', b.deleted_at,
          'sync_version', greatest(b.sync_version, c.sync_version),
          'categories', jsonb_build_object(
            'id', c.id,
            'name_ar', c.name_ar,
            'slug', c.slug,
            'icon_name', c.icon_name
          )
        )
        order by b.is_featured desc, b.created_at desc, b.name
      )
      from public.businesses b
      join public.categories c on c.id = b.category_id
      where greatest(b.sync_version, c.sync_version) > v_after_version
        and b.sync_version <= v_server_version
        and c.sync_version <= v_server_version
        and b.status = 'approved'
        and b.is_active = true
        and b.deleted_at is null
        and c.is_active = true
        and c.deleted_at is null
    ), '[]'::jsonb),
    'deleted_business_ids', coalesce((
      select jsonb_agg(changes.entity_id order by changes.sync_version)
      from (
        select
          b.id::text as entity_id,
          greatest(b.sync_version, c.sync_version) as sync_version
        from public.businesses b
        join public.categories c on c.id = b.category_id
        where greatest(b.sync_version, c.sync_version) > v_after_version
          and b.sync_version <= v_server_version
          and c.sync_version <= v_server_version
          and not (
            b.status = 'approved'
            and b.is_active = true
            and b.deleted_at is null
            and c.is_active = true
            and c.deleted_at is null
          )
        union all
        select t.entity_id::text, t.sync_version
        from public.directory_sync_tombstones t
        where t.entity_type = 'businesses'
          and t.sync_version > v_after_version
          and t.sync_version <= v_server_version
      ) changes
    ), '[]'::jsonb),
    'advertisements', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', a.id,
          'business_id', a.business_id,
          'title', a.title,
          'image_path', a.image_path,
          'compact_image_path', a.compact_image_path,
          'target_url', a.target_url,
          'placement', a.placement,
          'sort_order', a.sort_order,
          'is_active', a.is_active,
          'starts_at', a.starts_at,
          'ends_at', a.ends_at,
          'updated_at', a.updated_at,
          'deleted_at', a.deleted_at,
          'sync_version', a.sync_version
        )
        order by a.sort_order, a.created_at
      )
      from public.advertisements a
      where a.sync_version > v_after_version
        and a.sync_version <= v_server_version
        and a.is_active = true
        and a.deleted_at is null
    ), '[]'::jsonb),
    'deleted_advertisement_ids', coalesce((
      select jsonb_agg(changes.entity_id order by changes.sync_version)
      from (
        select a.id::text as entity_id, a.sync_version
        from public.advertisements a
        where a.sync_version > v_after_version
          and a.sync_version <= v_server_version
          and (a.is_active = false or a.deleted_at is not null)
        union all
        select t.entity_id::text, t.sync_version
        from public.directory_sync_tombstones t
        where t.entity_type = 'advertisements'
          and t.sync_version > v_after_version
          and t.sync_version <= v_server_version
      ) changes
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.admin_upsert_advertisement(
  uuid, uuid, text, text, text, text, text,
  timestamptz, timestamptz, integer
) from public;
revoke all on function public.get_directory_changes(bigint) from public;

grant execute on function public.admin_upsert_advertisement(
  uuid, uuid, text, text, text, text, text,
  timestamptz, timestamptz, integer
) to authenticated;
grant execute on function public.get_directory_changes(bigint)
  to anon, authenticated;

comment on column public.advertisements.compact_image_path is
  'Optional wide image used by the collapsed sticky advertisement header.';
comment on function public.admin_upsert_advertisement(
  uuid, uuid, text, text, text, text, text,
  timestamptz, timestamptz, integer
) is 'Creates or updates an advertisement with expanded and compact media.';

commit;
