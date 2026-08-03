-- دليل الحامي
-- المرحلة 05B-1: المزامنة التزايدية وإشارات الحذف

begin;

create sequence if not exists public.directory_sync_version_seq
  as bigint
  start with 1
  increment by 1
  minvalue 1
  cache 1;

alter sequence public.directory_sync_version_seq cache 1;

alter table public.categories
  add column if not exists deleted_at timestamptz;
alter table public.categories
  add column if not exists sync_version bigint;

alter table public.businesses
  add column if not exists deleted_at timestamptz;
alter table public.businesses
  add column if not exists sync_version bigint;

alter table public.advertisements
  add column if not exists deleted_at timestamptz;
alter table public.advertisements
  add column if not exists sync_version bigint;

update public.categories
set sync_version = nextval('public.directory_sync_version_seq')
where sync_version is null;

update public.businesses
set sync_version = nextval('public.directory_sync_version_seq')
where sync_version is null;

update public.advertisements
set sync_version = nextval('public.directory_sync_version_seq')
where sync_version is null;

select setval(
  'public.directory_sync_version_seq',
  greatest(
    (select last_value from public.directory_sync_version_seq),
    coalesce((select max(sync_version) from public.categories), 0),
    coalesce((select max(sync_version) from public.businesses), 0),
    coalesce((select max(sync_version) from public.advertisements), 0),
    1
  ),
  true
);

update public.categories
set deleted_at = coalesce(deleted_at, updated_at)
where is_active = false
  and deleted_at is null;

update public.businesses
set deleted_at = coalesce(deleted_at, updated_at)
where is_active = false
  and deleted_at is null;

update public.advertisements
set deleted_at = coalesce(deleted_at, updated_at)
where is_active = false
  and deleted_at is null;

alter table public.categories
  alter column sync_version set default 0;
alter table public.categories
  alter column sync_version set not null;

alter table public.businesses
  alter column sync_version set default 0;
alter table public.businesses
  alter column sync_version set not null;

alter table public.advertisements
  alter column sync_version set default 0;
alter table public.advertisements
  alter column sync_version set not null;

create table if not exists public.directory_sync_tombstones (
  entity_type text not null
    check (entity_type in ('categories', 'businesses', 'advertisements')),
  entity_id uuid not null,
  deleted_at timestamptz not null default timezone('utc', now()),
  sync_version bigint not null
    default nextval('public.directory_sync_version_seq'),
  primary key (entity_type, entity_id)
);

select setval(
  'public.directory_sync_version_seq',
  greatest(
    (select last_value from public.directory_sync_version_seq),
    coalesce((select max(sync_version) from public.categories), 0),
    coalesce((select max(sync_version) from public.businesses), 0),
    coalesce((select max(sync_version) from public.advertisements), 0),
    coalesce((
      select max(sync_version)
      from public.directory_sync_tombstones
    ), 0),
    1
  ),
  true
);

create index if not exists categories_sync_version_idx
  on public.categories(sync_version);
create index if not exists businesses_sync_version_idx
  on public.businesses(sync_version);
create index if not exists advertisements_sync_version_idx
  on public.advertisements(sync_version);
create index if not exists directory_sync_tombstones_version_idx
  on public.directory_sync_tombstones(sync_version);

alter table public.directory_sync_tombstones enable row level security;
revoke all on table public.directory_sync_tombstones
  from anon, authenticated;
revoke all on sequence public.directory_sync_version_seq
  from anon, authenticated;

create or replace function public.touch_directory_sync_row()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  new.updated_at = timezone('utc', now());
  new.sync_version = nextval('public.directory_sync_version_seq');

  if new.is_active = true then
    new.deleted_at = null;
  else
    new.deleted_at = coalesce(
      new.deleted_at,
      timezone('utc', now())
    );
  end if;

  return new;
end;
$$;

create or replace function public.record_directory_tombstone()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.directory_sync_tombstones (
    entity_type,
    entity_id,
    deleted_at,
    sync_version
  )
  values (
    tg_table_name,
    old.id,
    timezone('utc', now()),
    nextval('public.directory_sync_version_seq')
  )
  on conflict (entity_type, entity_id) do update
  set
    deleted_at = excluded.deleted_at,
    sync_version = excluded.sync_version;

  return old;
end;
$$;

create or replace function public.clear_directory_tombstone()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  delete from public.directory_sync_tombstones
  where entity_type = tg_table_name
    and entity_id = new.id;

  return new;
end;
$$;

drop trigger if exists categories_directory_sync_touch
  on public.categories;
create trigger categories_directory_sync_touch
before insert or update on public.categories
for each row execute function public.touch_directory_sync_row();

drop trigger if exists businesses_directory_sync_touch
  on public.businesses;
create trigger businesses_directory_sync_touch
before insert or update on public.businesses
for each row execute function public.touch_directory_sync_row();

drop trigger if exists advertisements_directory_sync_touch
  on public.advertisements;
create trigger advertisements_directory_sync_touch
before insert or update on public.advertisements
for each row execute function public.touch_directory_sync_row();

drop trigger if exists categories_directory_sync_delete
  on public.categories;
create trigger categories_directory_sync_delete
after delete on public.categories
for each row execute function public.record_directory_tombstone();

drop trigger if exists businesses_directory_sync_delete
  on public.businesses;
create trigger businesses_directory_sync_delete
after delete on public.businesses
for each row execute function public.record_directory_tombstone();

drop trigger if exists advertisements_directory_sync_delete
  on public.advertisements;
create trigger advertisements_directory_sync_delete
after delete on public.advertisements
for each row execute function public.record_directory_tombstone();

drop trigger if exists categories_directory_sync_restore
  on public.categories;
create trigger categories_directory_sync_restore
after insert or update on public.categories
for each row execute function public.clear_directory_tombstone();

drop trigger if exists businesses_directory_sync_restore
  on public.businesses;
create trigger businesses_directory_sync_restore
after insert or update on public.businesses
for each row execute function public.clear_directory_tombstone();

drop trigger if exists advertisements_directory_sync_restore
  on public.advertisements;
create trigger advertisements_directory_sync_restore
after insert or update on public.advertisements
for each row execute function public.clear_directory_tombstone();

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
          'title', a.title,
          'image_path', a.image_path,
          'target_url', a.target_url,
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

revoke all on function public.get_directory_changes(bigint)
  from public;
grant execute on function public.get_directory_changes(bigint)
  to anon, authenticated;

commit;
