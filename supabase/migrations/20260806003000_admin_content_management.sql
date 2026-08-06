-- Dalil Al Hami
-- Phase 07C: secure administrator management for categories and businesses

begin;

create table if not exists public.admin_content_actions (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references auth.users(id) on delete set null,
  entity_type text not null check (entity_type in ('category', 'business')),
  entity_id uuid not null,
  action text not null,
  reason text,
  before_data jsonb,
  after_data jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists admin_content_actions_entity_created_idx
  on public.admin_content_actions(entity_type, entity_id, created_at desc);
create index if not exists admin_content_actions_actor_created_idx
  on public.admin_content_actions(actor_id, created_at desc);

alter table public.admin_content_actions enable row level security;

drop policy if exists admin_content_actions_admin_select
  on public.admin_content_actions;
create policy admin_content_actions_admin_select
on public.admin_content_actions
for select
to authenticated
using (public.is_admin());

revoke all on public.admin_content_actions from anon, authenticated;
grant select on public.admin_content_actions to authenticated;

create or replace function public.admin_record_content_action(
  p_entity_type text,
  p_entity_id uuid,
  p_action text,
  p_reason text,
  p_before_data jsonb,
  p_after_data jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Administrator access is required.' using errcode = '42501';
  end if;

  insert into public.admin_content_actions (
    actor_id,
    entity_type,
    entity_id,
    action,
    reason,
    before_data,
    after_data
  )
  values (
    (select auth.uid()),
    p_entity_type,
    p_entity_id,
    p_action,
    nullif(btrim(coalesce(p_reason, '')), ''),
    p_before_data,
    p_after_data
  );
end;
$$;

revoke all on function public.admin_record_content_action(
  text, uuid, text, text, jsonb, jsonb
) from public;

create or replace function public.admin_upsert_category(
  p_category_id uuid,
  p_name_ar text,
  p_slug text,
  p_icon_name text,
  p_image_url text,
  p_sort_order integer,
  p_display_group text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_category public.categories%rowtype;
  v_before jsonb;
  v_action text;
  v_name text := btrim(coalesce(p_name_ar, ''));
  v_slug text := lower(btrim(coalesce(p_slug, '')));
  v_icon text := btrim(coalesce(p_icon_name, 'category'));
  v_group text := coalesce(nullif(btrim(p_display_group), ''), 'services');
begin
  if not public.is_admin() then
    raise exception 'Administrator access is required.' using errcode = '42501';
  end if;
  if length(v_name) < 2 then
    raise exception 'Category name is required.' using errcode = '22023';
  end if;
  if v_slug !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' then
    raise exception 'Category slug is invalid.' using errcode = '22023';
  end if;
  if v_group not in ('services', 'transport') then
    raise exception 'Category display group is invalid.' using errcode = '22023';
  end if;

  if p_category_id is null then
    insert into public.categories (
      name_ar,
      slug,
      icon_name,
      image_url,
      sort_order,
      display_group,
      is_active
    )
    values (
      v_name,
      v_slug,
      coalesce(nullif(v_icon, ''), 'category'),
      nullif(btrim(coalesce(p_image_url, '')), ''),
      greatest(coalesce(p_sort_order, 0), 0),
      v_group,
      true
    )
    returning * into v_category;
    v_action := 'created';
    v_before := null;
  else
    select to_jsonb(category.*)
    into v_before
    from public.categories category
    where category.id = p_category_id
    for update;

    if not found then
      raise exception 'Category was not found.' using errcode = 'P0002';
    end if;

    update public.categories category
    set
      name_ar = v_name,
      slug = v_slug,
      icon_name = coalesce(nullif(v_icon, ''), 'category'),
      image_url = nullif(btrim(coalesce(p_image_url, '')), ''),
      sort_order = greatest(coalesce(p_sort_order, 0), 0),
      display_group = v_group
    where category.id = p_category_id
    returning category.* into v_category;
    v_action := 'updated';
  end if;

  perform public.admin_record_content_action(
    'category',
    v_category.id,
    v_action,
    null,
    v_before,
    to_jsonb(v_category)
  );

  return jsonb_build_object(
    'entity_id', v_category.id,
    'entity_type', 'category',
    'action', v_action,
    'message', case when v_action = 'created'
      then 'تمت إضافة القسم بنجاح.'
      else 'تم تحديث القسم بنجاح.'
    end
  );
end;
$$;

create or replace function public.admin_set_category_active(
  p_category_id uuid,
  p_is_active boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_category public.categories%rowtype;
  v_before jsonb;
  v_linked_count bigint;
  v_action text;
begin
  if not public.is_admin() then
    raise exception 'Administrator access is required.' using errcode = '42501';
  end if;

  select to_jsonb(category.*)
  into v_before
  from public.categories category
  where category.id = p_category_id
  for update;
  if not found then
    raise exception 'Category was not found.' using errcode = 'P0002';
  end if;

  if coalesce(p_is_active, false) = false then
    select count(*) into v_linked_count
    from public.businesses business
    where business.category_id = p_category_id
      and business.deleted_at is null;
    if v_linked_count > 0 then
      raise exception 'Category has linked businesses.' using errcode = '23503';
    end if;
  end if;

  update public.categories category
  set is_active = coalesce(p_is_active, false)
  where category.id = p_category_id
  returning category.* into v_category;

  v_action := case when v_category.is_active then 'restored' else 'archived' end;
  perform public.admin_record_content_action(
    'category', v_category.id, v_action, null, v_before, to_jsonb(v_category)
  );

  return jsonb_build_object(
    'entity_id', v_category.id,
    'entity_type', 'category',
    'action', v_action,
    'message', case when v_category.is_active
      then 'تم تفعيل القسم.'
      else 'تمت أرشفة القسم.'
    end
  );
end;
$$;

create or replace function public.admin_delete_category(p_category_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_before jsonb;
  v_linked_count bigint;
begin
  if not public.is_admin() then
    raise exception 'Administrator access is required.' using errcode = '42501';
  end if;

  select to_jsonb(category.*)
  into v_before
  from public.categories category
  where category.id = p_category_id
  for update;
  if not found then
    raise exception 'Category was not found.' using errcode = 'P0002';
  end if;

  select count(*) into v_linked_count
  from public.businesses business
  where business.category_id = p_category_id;
  if v_linked_count > 0 then
    raise exception 'Category has linked businesses.' using errcode = '23503';
  end if;

  delete from public.categories where id = p_category_id;
  perform public.admin_record_content_action(
    'category', p_category_id, 'deleted', null, v_before, null
  );

  return jsonb_build_object(
    'entity_id', p_category_id,
    'entity_type', 'category',
    'action', 'deleted',
    'message', 'تم حذف القسم نهائيًا.'
  );
end;
$$;

create or replace function public.admin_upsert_business(
  p_business_id uuid,
  p_category_id uuid,
  p_name text,
  p_description text,
  p_phone text,
  p_whatsapp text,
  p_address text,
  p_latitude numeric,
  p_longitude numeric,
  p_logo_url text,
  p_cover_url text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_business public.businesses%rowtype;
  v_before jsonb;
  v_action text;
  v_name text := btrim(coalesce(p_name, ''));
  v_phone text := btrim(coalesce(p_phone, ''));
  v_address text := coalesce(nullif(btrim(coalesce(p_address, '')), ''), 'الحامي');
  v_now timestamptz := timezone('utc', now());
begin
  if not public.is_admin() then
    raise exception 'Administrator access is required.' using errcode = '42501';
  end if;
  if length(v_name) < 2 or length(v_phone) < 5 then
    raise exception 'Business name and phone are required.' using errcode = '22023';
  end if;
  if p_latitude is not null and (p_latitude < -90 or p_latitude > 90) then
    raise exception 'Latitude is invalid.' using errcode = '22023';
  end if;
  if p_longitude is not null and (p_longitude < -180 or p_longitude > 180) then
    raise exception 'Longitude is invalid.' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.categories category
    where category.id = p_category_id
      and category.is_active = true
      and category.deleted_at is null
  ) then
    raise exception 'An active category is required.' using errcode = '22023';
  end if;

  if p_business_id is null then
    insert into public.businesses (
      owner_id,
      category_id,
      name,
      description,
      phone,
      whatsapp,
      address,
      latitude,
      longitude,
      logo_url,
      cover_url,
      status,
      rejection_reason,
      is_featured,
      is_active,
      approved_at,
      approved_by
    )
    values (
      null,
      p_category_id,
      v_name,
      btrim(coalesce(p_description, '')),
      v_phone,
      btrim(coalesce(p_whatsapp, '')),
      v_address,
      p_latitude,
      p_longitude,
      nullif(btrim(coalesce(p_logo_url, '')), ''),
      nullif(btrim(coalesce(p_cover_url, '')), ''),
      'approved',
      null,
      false,
      true,
      v_now,
      (select auth.uid())
    )
    returning * into v_business;
    v_action := 'created';
    v_before := null;
  else
    select to_jsonb(business.*)
    into v_before
    from public.businesses business
    where business.id = p_business_id
    for update;
    if not found then
      raise exception 'Business was not found.' using errcode = 'P0002';
    end if;

    update public.businesses business
    set
      category_id = p_category_id,
      name = v_name,
      description = btrim(coalesce(p_description, '')),
      phone = v_phone,
      whatsapp = btrim(coalesce(p_whatsapp, '')),
      address = v_address,
      latitude = p_latitude,
      longitude = p_longitude,
      logo_url = nullif(btrim(coalesce(p_logo_url, '')), ''),
      cover_url = nullif(btrim(coalesce(p_cover_url, '')), '')
    where business.id = p_business_id
    returning business.* into v_business;
    v_action := 'updated';
  end if;

  perform public.admin_record_content_action(
    'business', v_business.id, v_action, null, v_before, to_jsonb(v_business)
  );

  return jsonb_build_object(
    'entity_id', v_business.id,
    'entity_type', 'business',
    'action', v_action,
    'message', case when v_action = 'created'
      then 'تمت إضافة النشاط ونشره.'
      else 'تم تحديث بيانات النشاط.'
    end
  );
end;
$$;

create or replace function public.admin_manage_business(
  p_business_id uuid,
  p_action text,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_business public.businesses%rowtype;
  v_before jsonb;
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_message text;
  v_now timestamptz := timezone('utc', now());
begin
  if not public.is_admin() then
    raise exception 'Administrator access is required.' using errcode = '42501';
  end if;
  if p_action not in ('feature', 'unfeature', 'suspend', 'restore') then
    raise exception 'Invalid business action.' using errcode = '22023';
  end if;

  select to_jsonb(business.*)
  into v_before
  from public.businesses business
  where business.id = p_business_id
  for update;
  if not found then
    raise exception 'Business was not found.' using errcode = 'P0002';
  end if;

  select * into v_business
  from public.businesses business
  where business.id = p_business_id;

  if p_action = 'feature' then
    if v_business.status <> 'approved' or v_business.is_active = false then
      raise exception 'Only an active approved business can be featured.' using errcode = '22023';
    end if;
    update public.businesses set is_featured = true where id = p_business_id
      returning * into v_business;
    v_message := 'تم تمييز النشاط.';
  elsif p_action = 'unfeature' then
    update public.businesses set is_featured = false where id = p_business_id
      returning * into v_business;
    v_message := 'تم إلغاء تمييز النشاط.';
  elsif p_action = 'suspend' then
    if v_business.status <> 'approved' then
      raise exception 'Only an approved business can be suspended.' using errcode = '22023';
    end if;
    if length(coalesce(v_reason, '')) < 5 then
      raise exception 'A suspension reason is required.' using errcode = '22023';
    end if;
    update public.businesses
    set
      status = 'suspended',
      rejection_reason = v_reason,
      is_featured = false,
      is_active = false,
      approved_at = null,
      approved_by = null
    where id = p_business_id
    returning * into v_business;
    v_message := 'تم إيقاف النشاط.';
  else
    if v_business.status <> 'suspended' then
      raise exception 'Only a suspended business can be restored.' using errcode = '22023';
    end if;
    if not exists (
      select 1 from public.categories category
      where category.id = v_business.category_id
        and category.is_active = true
        and category.deleted_at is null
    ) then
      raise exception 'The business category must be active before restore.' using errcode = '22023';
    end if;
    update public.businesses
    set
      status = 'approved',
      rejection_reason = null,
      is_active = true,
      approved_at = v_now,
      approved_by = (select auth.uid())
    where id = p_business_id
    returning * into v_business;
    v_message := 'تمت استعادة النشاط ونشره.';
  end if;

  perform public.admin_record_content_action(
    'business', v_business.id, p_action, v_reason, v_before, to_jsonb(v_business)
  );

  return jsonb_build_object(
    'entity_id', v_business.id,
    'entity_type', 'business',
    'action', p_action,
    'message', v_message
  );
end;
$$;

create or replace function public.admin_delete_business(p_business_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_before jsonb;
begin
  if not public.is_admin() then
    raise exception 'Administrator access is required.' using errcode = '42501';
  end if;

  select to_jsonb(business.*)
  into v_before
  from public.businesses business
  where business.id = p_business_id
  for update;
  if not found then
    raise exception 'Business was not found.' using errcode = 'P0002';
  end if;

  delete from public.businesses where id = p_business_id;
  perform public.admin_record_content_action(
    'business', p_business_id, 'deleted', null, v_before, null
  );

  return jsonb_build_object(
    'entity_id', p_business_id,
    'entity_type', 'business',
    'action', 'deleted',
    'message', 'تم حذف النشاط نهائيًا.'
  );
end;
$$;

revoke all on function public.admin_upsert_category(
  uuid, text, text, text, text, integer, text
) from public;
revoke all on function public.admin_set_category_active(uuid, boolean) from public;
revoke all on function public.admin_delete_category(uuid) from public;
revoke all on function public.admin_upsert_business(
  uuid, uuid, text, text, text, text, text, numeric, numeric, text, text
) from public;
revoke all on function public.admin_manage_business(uuid, text, text) from public;
revoke all on function public.admin_delete_business(uuid) from public;

grant execute on function public.admin_upsert_category(
  uuid, text, text, text, text, integer, text
) to authenticated;
grant execute on function public.admin_set_category_active(uuid, boolean)
  to authenticated;
grant execute on function public.admin_delete_category(uuid)
  to authenticated;
grant execute on function public.admin_upsert_business(
  uuid, uuid, text, text, text, text, text, numeric, numeric, text, text
) to authenticated;
grant execute on function public.admin_manage_business(uuid, text, text)
  to authenticated;
grant execute on function public.admin_delete_business(uuid)
  to authenticated;

comment on table public.admin_content_actions is
  'Immutable administrator audit trail for category and business management.';

commit;
