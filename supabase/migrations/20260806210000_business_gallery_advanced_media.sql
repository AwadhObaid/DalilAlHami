-- Dalil Al Hami
-- Phase 08A-2: business galleries, media finalization, and orphan cleanup

begin;

alter table public.business_images
  add column if not exists public_url text;
alter table public.business_images
  add column if not exists is_primary boolean not null default false;
alter table public.business_images
  add column if not exists updated_at timestamptz
    not null default timezone('utc', now());
alter table public.business_images
  add column if not exists deleted_at timestamptz;
alter table public.business_images
  add column if not exists sync_version bigint;

update public.business_images
set sync_version = nextval('public.directory_sync_version_seq')
where sync_version is null;

alter table public.business_images
  alter column sync_version set default 0;
alter table public.business_images
  alter column sync_version set not null;

-- Keep exactly one primary image for each non-empty gallery.
with preferred as (
  select distinct on (business_id)
    id,
    business_id
  from public.business_images
  where deleted_at is null
  order by business_id, is_primary desc, sort_order, created_at, id
)
update public.business_images image
set is_primary = image.id = preferred.id
from preferred
where image.business_id = preferred.business_id
  and image.deleted_at is null;

create unique index if not exists business_images_one_primary_idx
  on public.business_images(business_id)
  where is_primary = true and deleted_at is null;
create index if not exists business_images_sync_version_idx
  on public.business_images(sync_version);
create index if not exists business_images_visible_order_idx
  on public.business_images(business_id, is_primary desc, sort_order)
  where deleted_at is null;

drop policy if exists business_images_owner_insert on public.business_images;
drop policy if exists business_images_owner_update on public.business_images;
drop policy if exists business_images_owner_delete on public.business_images;

-- All gallery mutations go through guarded security-definer RPCs so the
-- five-image limit, primary-image invariant, and audit-safe soft delete cannot
-- be bypassed by direct table writes.
drop policy if exists business_images_select on public.business_images;
create policy business_images_select
on public.business_images
for select
to anon, authenticated
using (
  business_images.deleted_at is null
  and exists (
    select 1
    from public.businesses business
    where business.id = business_images.business_id
      and business.deleted_at is null
      and (
        (business.status = 'approved' and business.is_active = true)
        or business.owner_id = (select auth.uid())
        or public.is_admin()
      )
  )
);

create or replace function public.touch_business_image_sync_row()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  new.updated_at = timezone('utc', now());
  new.sync_version = nextval('public.directory_sync_version_seq');
  if new.deleted_at is not null then
    new.is_primary = false;
  end if;
  return new;
end;
$$;

drop trigger if exists business_images_directory_sync_touch
  on public.business_images;
create trigger business_images_directory_sync_touch
before insert or update on public.business_images
for each row execute function public.touch_business_image_sync_row();

select setval(
  'public.directory_sync_version_seq',
  greatest(
    (select last_value from public.directory_sync_version_seq),
    coalesce((select max(sync_version) from public.categories), 0),
    coalesce((select max(sync_version) from public.businesses), 0),
    coalesce((select max(sync_version) from public.business_images), 0),
    coalesce((select max(sync_version) from public.advertisements), 0),
    coalesce((select max(sync_version)
      from public.directory_sync_tombstones), 0),
    1
  ),
  true
);

create or replace function public.can_manage_business(
  p_business_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.businesses business
    where business.id = p_business_id
      and business.deleted_at is null
      and (
        business.owner_id = (select auth.uid())
        or public.is_admin()
      )
  );
$$;

create or replace function public.business_gallery_json(
  p_business_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', image.id,
        'business_id', image.business_id,
        'storage_path', image.storage_path,
        'public_url', image.public_url,
        'alt_text', image.alt_text,
        'sort_order', image.sort_order,
        'is_primary', image.is_primary,
        'created_at', image.created_at,
        'updated_at', image.updated_at,
        'deleted_at', image.deleted_at,
        'sync_version', image.sync_version
      )
      order by image.is_primary desc, image.sort_order, image.created_at
    ),
    '[]'::jsonb
  )
  from public.business_images image
  where image.business_id = p_business_id
    and image.deleted_at is null;
$$;

create or replace function public.manage_business_gallery(
  p_business_id uuid,
  p_action text,
  p_image_id uuid default null,
  p_storage_path text default null,
  p_public_url text default null,
  p_alt_text text default '',
  p_make_primary boolean default false,
  p_ordered_ids uuid[] default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_action text := lower(btrim(coalesce(p_action, '')));
  v_image public.business_images%rowtype;
  v_active_count integer;
  v_order_count integer;
  v_distinct_count integer;
  v_was_primary boolean := false;
begin
  if not exists (
    select 1 from public.businesses where id = p_business_id
  ) then
    raise exception 'Business was not found.' using errcode = 'P0002';
  end if;
  if not public.can_manage_business(p_business_id) then
    raise exception 'Business media access is denied.' using errcode = '42501';
  end if;

  if v_action = 'add' then
    select count(*) into v_active_count
    from public.business_images
    where business_id = p_business_id and deleted_at is null;
    if v_active_count >= 5 then
      raise exception 'The maximum business gallery size is five images.'
        using errcode = '22023';
    end if;
    if nullif(btrim(coalesce(p_storage_path, '')), '') is null then
      raise exception 'Storage path is required.' using errcode = '22023';
    end if;

    insert into public.business_images (
      business_id,
      storage_path,
      public_url,
      alt_text,
      sort_order,
      is_primary,
      deleted_at
    )
    values (
      p_business_id,
      btrim(p_storage_path),
      nullif(btrim(coalesce(p_public_url, '')), ''),
      left(btrim(coalesce(p_alt_text, '')), 120),
      coalesce((
        select max(sort_order) + 1
        from public.business_images
        where business_id = p_business_id and deleted_at is null
      ), 0),
      false,
      null
    )
    on conflict (business_id, storage_path) do update
    set
      public_url = excluded.public_url,
      alt_text = excluded.alt_text,
      deleted_at = null
    returning * into v_image;

    if p_make_primary or v_active_count = 0 then
      update public.business_images
      set is_primary = false
      where business_id = p_business_id
        and deleted_at is null
        and id <> v_image.id
        and is_primary = true;
      update public.business_images
      set is_primary = true
      where id = v_image.id;
    end if;

  elsif v_action in ('primary', 'alt', 'delete', 'replace') then
    select * into v_image
    from public.business_images
    where id = p_image_id
      and business_id = p_business_id
      and deleted_at is null
    for update;
    if not found then
      raise exception 'Gallery image was not found.' using errcode = 'P0002';
    end if;

    if v_action = 'primary' then
      update public.business_images
      set is_primary = false
      where business_id = p_business_id
        and deleted_at is null
        and id <> v_image.id
        and is_primary = true;
      update public.business_images set is_primary = true
      where id = v_image.id;
    elsif v_action = 'alt' then
      update public.business_images
      set alt_text = left(btrim(coalesce(p_alt_text, '')), 120)
      where id = v_image.id;
    elsif v_action = 'replace' then
      if nullif(btrim(coalesce(p_storage_path, '')), '') is null then
        raise exception 'Storage path is required.' using errcode = '22023';
      end if;
      update public.business_images
      set
        storage_path = btrim(p_storage_path),
        public_url = nullif(btrim(coalesce(p_public_url, '')), ''),
        alt_text = left(btrim(coalesce(p_alt_text, v_image.alt_text)), 120)
      where id = v_image.id;
    else
      v_was_primary := v_image.is_primary;
      update public.business_images
      set deleted_at = timezone('utc', now()), is_primary = false
      where id = v_image.id;
      if v_was_primary then
        update public.business_images
        set is_primary = true
        where id = (
          select id
          from public.business_images
          where business_id = p_business_id
            and deleted_at is null
          order by sort_order, created_at, id
          limit 1
        );
      end if;
    end if;

  elsif v_action = 'reorder' then
    if p_ordered_ids is null then
      raise exception 'Ordered image ids are required.' using errcode = '22023';
    end if;
    select count(*) into v_active_count
    from public.business_images
    where business_id = p_business_id and deleted_at is null;
    v_order_count := coalesce(array_length(p_ordered_ids, 1), 0);
    select count(distinct value) into v_distinct_count
    from unnest(p_ordered_ids) value;
    if v_order_count <> v_active_count or
       v_distinct_count <> v_active_count or
       exists (
         select 1 from unnest(p_ordered_ids) value
         where not exists (
           select 1 from public.business_images image
           where image.id = value
             and image.business_id = p_business_id
             and image.deleted_at is null
         )
       ) then
      raise exception 'Ordered gallery ids are invalid.' using errcode = '22023';
    end if;

    update public.business_images image
    set sort_order = ordered.ordinality - 1
    from unnest(p_ordered_ids) with ordinality ordered(id, ordinality)
    where image.id = ordered.id
      and image.business_id = p_business_id;
  else
    raise exception 'Gallery action is invalid.' using errcode = '22023';
  end if;

  return jsonb_build_object(
    'business_id', p_business_id,
    'action', v_action,
    'gallery', public.business_gallery_json(p_business_id)
  );
end;
$$;

create or replace function public.finalize_owner_business_media(
  p_business_id uuid,
  p_logo_url text default null,
  p_cover_url text default null,
  p_gallery jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_item jsonb;
  v_index integer := 0;
  v_count integer;
  v_primary_id uuid;
  v_existing_deleted_at timestamptz;
begin
  if not public.can_manage_business(p_business_id) then
    raise exception 'Business media access is denied.' using errcode = '42501';
  end if;
  if jsonb_typeof(coalesce(p_gallery, '[]'::jsonb)) <> 'array' then
    raise exception 'Gallery payload must be an array.' using errcode = '22023';
  end if;
  if jsonb_array_length(coalesce(p_gallery, '[]'::jsonb)) > 5 then
    raise exception 'The maximum business gallery size is five images.'
      using errcode = '22023';
  end if;

  update public.businesses
  set
    logo_url = case
      when nullif(btrim(coalesce(p_logo_url, '')), '') is null then logo_url
      else btrim(p_logo_url)
    end,
    cover_url = case
      when nullif(btrim(coalesce(p_cover_url, '')), '') is null then cover_url
      else btrim(p_cover_url)
    end
  where id = p_business_id;

  select count(*) into v_count
  from public.business_images
  where business_id = p_business_id and deleted_at is null;

  for v_item in
    select value from jsonb_array_elements(coalesce(p_gallery, '[]'::jsonb))
  loop
    if nullif(btrim(coalesce(v_item->>'storage_path', '')), '') is null then
      continue;
    end if;

    v_primary_id := null;
    v_existing_deleted_at := null;
    select image.id, image.deleted_at
    into v_primary_id, v_existing_deleted_at
    from public.business_images image
    where image.business_id = p_business_id
      and image.storage_path = btrim(v_item->>'storage_path')
    limit 1;

    if v_primary_id is null then
      if v_count >= 5 then
        exit;
      end if;
      insert into public.business_images (
        business_id,
        storage_path,
        public_url,
        alt_text,
        sort_order,
        is_primary,
        deleted_at
      )
      values (
        p_business_id,
        btrim(v_item->>'storage_path'),
        nullif(btrim(coalesce(v_item->>'public_url', '')), ''),
        left(btrim(coalesce(v_item->>'alt_text', '')), 120),
        coalesce(
          nullif(v_item->>'sort_order', '')::integer,
          v_count
        ),
        false,
        null
      )
      returning id into v_primary_id;
      v_count := v_count + 1;
    else
      if v_existing_deleted_at is not null then
        if v_count >= 5 then
          continue;
        end if;
        v_count := v_count + 1;
      end if;
      update public.business_images
      set
        public_url = nullif(btrim(coalesce(v_item->>'public_url', '')), ''),
        alt_text = left(btrim(coalesce(v_item->>'alt_text', '')), 120),
        sort_order = coalesce(
          nullif(v_item->>'sort_order', '')::integer,
          sort_order
        ),
        deleted_at = null
      where id = v_primary_id;
    end if;

    if coalesce(nullif(v_item->>'is_primary', '')::boolean, false) or
       (v_count = 1 and v_index = 0) then
      update public.business_images
      set is_primary = false
      where business_id = p_business_id
        and deleted_at is null
        and id <> v_primary_id
        and is_primary = true;
      update public.business_images set is_primary = true
      where id = v_primary_id;
    end if;
    v_index := v_index + 1;
  end loop;

  return jsonb_build_object(
    'business_id', p_business_id,
    'gallery', public.business_gallery_json(p_business_id)
  );
end;
$$;

-- Owners may prepare media before the queued business operation is finalized.
drop policy if exists storage_business_media_owner_draft_insert
  on storage.objects;
create policy storage_business_media_owner_draft_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'business-media'
  and (storage.foldername(name))[1] = 'drafts'
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

drop policy if exists storage_business_media_owner_draft_update
  on storage.objects;
create policy storage_business_media_owner_draft_update
on storage.objects
for update
to authenticated
using (
  bucket_id = 'business-media'
  and (storage.foldername(name))[1] = 'drafts'
  and (storage.foldername(name))[2] = (select auth.uid())::text
)
with check (
  bucket_id = 'business-media'
  and (storage.foldername(name))[1] = 'drafts'
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

drop policy if exists storage_business_media_owner_draft_delete
  on storage.objects;
create policy storage_business_media_owner_draft_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'business-media'
  and (storage.foldername(name))[1] = 'drafts'
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

drop policy if exists storage_business_media_admin_delete_all
  on storage.objects;
create policy storage_business_media_admin_delete_all
on storage.objects
for delete
to authenticated
using (bucket_id = 'business-media' and public.is_admin());

create or replace function public.admin_get_media_overview()
returns jsonb
language plpgsql
security definer
set search_path = public, storage, pg_temp
as $$
begin
  if not public.is_admin() then
    raise exception 'Administrator access is required.' using errcode = '42501';
  end if;

  return jsonb_build_object(
    'profile_avatars', (select count(*) from public.profiles
      where nullif(btrim(coalesce(avatar_url, '')), '') is not null),
    'category_images', (select count(*) from public.categories
      where nullif(btrim(coalesce(image_url, '')), '') is not null),
    'business_logos', (select count(*) from public.businesses
      where deleted_at is null
        and nullif(btrim(coalesce(logo_url, '')), '') is not null),
    'business_covers', (select count(*) from public.businesses
      where deleted_at is null
        and nullif(btrim(coalesce(cover_url, '')), '') is not null),
    'gallery_images', (select count(*) from public.business_images
      where deleted_at is null),
    'advertisement_images', (select count(*) from public.advertisements
      where deleted_at is null
        and nullif(btrim(coalesce(image_path, '')), '') is not null),
    'compact_advertisement_images', (select count(*)
      from public.advertisements
      where deleted_at is null
        and nullif(btrim(coalesce(compact_image_path, '')), '') is not null),
    'draft_objects', (select count(*) from storage.objects object
      where object.bucket_id in (
        'business-media', 'category-media', 'advertisements', 'avatars'
      )
        and (object.name like 'drafts/%'
          or object.name like '%/drafts/%')),
    'recent_gallery', coalesce((
      select jsonb_agg(row_data order by row_data->>'updated_at' desc)
      from (
        select jsonb_build_object(
          'id', image.id,
          'business_id', image.business_id,
          'business_name', business.name,
          'storage_path', image.storage_path,
          'public_url', image.public_url,
          'alt_text', image.alt_text,
          'sort_order', image.sort_order,
          'is_primary', image.is_primary,
          'updated_at', image.updated_at
        ) row_data
        from public.business_images image
        join public.businesses business on business.id = image.business_id
        where image.deleted_at is null
        order by image.updated_at desc
        limit 20
      ) recent
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.admin_media_cleanup_candidates()
returns jsonb
language plpgsql
security definer
set search_path = public, storage, pg_temp
as $$
declare
  v_result jsonb;
begin
  if not public.is_admin() then
    raise exception 'Administrator access is required.' using errcode = '42501';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'bucket_id', candidate.bucket_id,
    'storage_path', candidate.name,
    'created_at', candidate.created_at,
    'reason', candidate.reason
  )), '[]'::jsonb)
  into v_result
  from (
    select
      object.bucket_id,
      object.name,
      object.created_at,
      case
        when object.name like 'drafts/%'
          or object.name like '%/drafts/%' then 'expired_draft'
        else 'unreferenced'
      end reason
    from storage.objects object
    where object.bucket_id in (
      'business-media', 'category-media', 'advertisements', 'avatars'
    )
      and (
        ((object.name like 'drafts/%'
            or object.name like '%/drafts/%')
          and object.created_at < timezone('utc', now()) - interval '24 hours')
        or (
          object.name not like 'drafts/%'
          and object.name not like '%/drafts/%'
          and case object.bucket_id
            when 'business-media' then
              not exists (
                select 1 from public.business_images image
                where image.deleted_at is null
                  and image.storage_path = object.name
              )
              and not exists (
                select 1 from public.businesses business
                where business.deleted_at is null
                  and (
                    business.logo_url like '%' || object.name
                    or business.cover_url like '%' || object.name
                  )
              )
            when 'category-media' then
              not exists (
                select 1 from public.categories category
                where category.deleted_at is null
                  and category.image_url like '%' || object.name
              )
            when 'advertisements' then
              not exists (
                select 1 from public.advertisements advertisement
                where advertisement.deleted_at is null
                  and (
                    advertisement.image_path like '%' || object.name
                    or advertisement.compact_image_path like '%' || object.name
                  )
              )
            when 'avatars' then
              not exists (
                select 1 from public.profiles profile
                where right(
                  coalesce(profile.avatar_url, ''),
                  length(object.name)
                ) = object.name
              )
            else false
          end
        )
      )
    order by object.created_at
    limit 250
  ) candidate;

  return v_result;
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
    coalesce((select max(sync_version) from public.business_images), 0),
    coalesce((select max(sync_version) from public.advertisements), 0),
    coalesce((select max(sync_version)
      from public.directory_sync_tombstones), 0)
  ) into v_server_version;

  if v_after_version > v_server_version then
    v_after_version := 0;
  end if;
  v_is_full_snapshot := v_after_version = 0;

  return jsonb_build_object(
    'server_version', v_server_version,
    'is_full_snapshot', v_is_full_snapshot,
    'categories', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', c.id, 'name_ar', c.name_ar, 'slug', c.slug,
        'icon_name', c.icon_name, 'image_url', c.image_url,
        'sort_order', c.sort_order, 'display_group', c.display_group,
        'updated_at', c.updated_at, 'deleted_at', c.deleted_at,
        'sync_version', c.sync_version
      ) order by c.sort_order, c.name_ar)
      from public.categories c
      where c.sync_version > v_after_version
        and c.sync_version <= v_server_version
        and c.is_active = true and c.deleted_at is null
    ), '[]'::jsonb),
    'deleted_category_ids', coalesce((
      select jsonb_agg(changes.entity_id order by changes.sync_version)
      from (
        select c.id::text entity_id, c.sync_version
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
      select jsonb_agg(jsonb_build_object(
        'id', b.id, 'category_id', b.category_id, 'name', b.name,
        'description', b.description, 'phone', b.phone,
        'whatsapp', b.whatsapp, 'address', b.address,
        'logo_url', b.logo_url, 'cover_url', b.cover_url,
        'is_featured', b.is_featured, 'created_at', b.created_at,
        'updated_at', b.updated_at, 'deleted_at', b.deleted_at,
        'sync_version', greatest(
          b.sync_version, c.sync_version, media.sync_version
        ),
        'categories', jsonb_build_object(
          'id', c.id, 'name_ar', c.name_ar,
          'slug', c.slug, 'icon_name', c.icon_name
        ),
        'business_images', media.gallery
      ) order by b.is_featured desc, b.created_at desc, b.name)
      from public.businesses b
      join public.categories c on c.id = b.category_id
      left join lateral (
        select
          coalesce(max(image.sync_version), 0) sync_version,
          coalesce(jsonb_agg(jsonb_build_object(
            'id', image.id,
            'business_id', image.business_id,
            'storage_path', image.storage_path,
            'public_url', image.public_url,
            'alt_text', image.alt_text,
            'sort_order', image.sort_order,
            'is_primary', image.is_primary,
            'created_at', image.created_at,
            'updated_at', image.updated_at,
            'deleted_at', image.deleted_at,
            'sync_version', image.sync_version
          ) order by image.is_primary desc, image.sort_order, image.created_at)
            filter (where image.deleted_at is null), '[]'::jsonb) gallery
        from public.business_images image
        where image.business_id = b.id
      ) media on true
      where greatest(b.sync_version, c.sync_version, media.sync_version)
          > v_after_version
        and b.sync_version <= v_server_version
        and c.sync_version <= v_server_version
        and media.sync_version <= v_server_version
        and b.status = 'approved' and b.is_active = true
        and b.deleted_at is null and c.is_active = true
        and c.deleted_at is null
    ), '[]'::jsonb),
    'deleted_business_ids', coalesce((
      select jsonb_agg(changes.entity_id order by changes.sync_version)
      from (
        select b.id::text entity_id,
          greatest(b.sync_version, c.sync_version,
            coalesce((select max(image.sync_version)
              from public.business_images image
              where image.business_id = b.id), 0)) sync_version
        from public.businesses b
        join public.categories c on c.id = b.category_id
        where greatest(b.sync_version, c.sync_version,
            coalesce((select max(image.sync_version)
              from public.business_images image
              where image.business_id = b.id), 0)) > v_after_version
          and greatest(b.sync_version, c.sync_version,
            coalesce((select max(image.sync_version)
              from public.business_images image
              where image.business_id = b.id), 0)) <= v_server_version
          and not (
            b.status = 'approved' and b.is_active = true
            and b.deleted_at is null and c.is_active = true
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
      select jsonb_agg(jsonb_build_object(
        'id', a.id, 'business_id', a.business_id, 'title', a.title,
        'image_path', a.image_path,
        'compact_image_path', a.compact_image_path,
        'target_url', a.target_url, 'placement', a.placement,
        'sort_order', a.sort_order, 'is_active', a.is_active,
        'starts_at', a.starts_at, 'ends_at', a.ends_at,
        'updated_at', a.updated_at, 'deleted_at', a.deleted_at,
        'sync_version', a.sync_version
      ) order by a.sort_order, a.created_at)
      from public.advertisements a
      where a.sync_version > v_after_version
        and a.sync_version <= v_server_version
        and a.is_active = true and a.deleted_at is null
    ), '[]'::jsonb),
    'deleted_advertisement_ids', coalesce((
      select jsonb_agg(changes.entity_id order by changes.sync_version)
      from (
        select a.id::text entity_id, a.sync_version
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

revoke all on function public.can_manage_business(uuid) from public;
revoke all on function public.business_gallery_json(uuid) from public;
revoke all on function public.manage_business_gallery(
  uuid, text, uuid, text, text, text, boolean, uuid[]
) from public;
revoke all on function public.finalize_owner_business_media(
  uuid, text, text, jsonb
) from public;
revoke all on function public.admin_get_media_overview() from public;
revoke all on function public.admin_media_cleanup_candidates() from public;
revoke all on function public.get_directory_changes(bigint) from public;

grant execute on function public.can_manage_business(uuid) to authenticated;
-- Internal helper only: callers use guarded RPCs or directory sync.
grant execute on function public.manage_business_gallery(
  uuid, text, uuid, text, text, text, boolean, uuid[]
) to authenticated;
grant execute on function public.finalize_owner_business_media(
  uuid, text, text, jsonb
) to authenticated;
grant execute on function public.admin_get_media_overview() to authenticated;
grant execute on function public.admin_media_cleanup_candidates()
  to authenticated;
grant execute on function public.get_directory_changes(bigint)
  to anon, authenticated;

comment on table public.business_images is
  'Ordered business gallery with one optional primary image per business.';
comment on function public.manage_business_gallery(
  uuid, text, uuid, text, text, text, boolean, uuid[]
) is 'Adds, deletes, reorders, labels, or selects the primary gallery image.';
comment on function public.admin_media_cleanup_candidates() is
  'Returns expired draft and unreferenced storage objects for admin cleanup.';

commit;
