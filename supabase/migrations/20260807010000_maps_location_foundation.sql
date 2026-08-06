begin;

alter table public.businesses
  add column if not exists latitude numeric,
  add column if not exists longitude numeric;

create or replace function public.owner_set_business_location(
  p_business_id uuid,
  p_latitude numeric,
  p_longitude numeric
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_sync_version bigint;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.' using errcode = '42501';
  end if;

  if (p_latitude is null) <> (p_longitude is null) then
    raise exception 'Latitude and longitude must be provided together.'
      using errcode = '22023';
  end if;
  if p_latitude is not null and (p_latitude < -90 or p_latitude > 90) then
    raise exception 'Latitude is outside the valid range.'
      using errcode = '22023';
  end if;
  if p_longitude is not null and (p_longitude < -180 or p_longitude > 180) then
    raise exception 'Longitude is outside the valid range.'
      using errcode = '22023';
  end if;

  if not exists (
    select 1
    from public.businesses business
    where business.id = p_business_id
      and business.deleted_at is null
      and (
        business.owner_id = v_user_id
        or public.is_admin()
      )
  ) then
    raise exception 'Business location access is denied.'
      using errcode = '42501';
  end if;

  update public.businesses
  set
    latitude = p_latitude,
    longitude = p_longitude
  where id = p_business_id
    and (
      latitude is distinct from p_latitude
      or longitude is distinct from p_longitude
    );

  select business.sync_version
  into v_sync_version
  from public.businesses business
  where business.id = p_business_id;

  return jsonb_build_object(
    'business_id', p_business_id,
    'latitude', p_latitude,
    'longitude', p_longitude,
    'sync_version', coalesce(v_sync_version, 0)
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
        'latitude', b.latitude, 'longitude', b.longitude,
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


revoke all on function public.owner_set_business_location(
  uuid, numeric, numeric
) from public;
revoke all on function public.get_directory_changes(bigint) from public;

grant execute on function public.owner_set_business_location(
  uuid, numeric, numeric
) to authenticated;
grant execute on function public.get_directory_changes(bigint)
  to anon, authenticated;

comment on function public.owner_set_business_location(
  uuid, numeric, numeric
) is
  'Updates or clears a business location for its owner or an administrator.';

commit;
