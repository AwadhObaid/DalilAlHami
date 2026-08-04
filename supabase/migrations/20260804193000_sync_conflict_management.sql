-- دليل الحامي
-- المرحلة 05B-3: اكتشاف تعارضات المزامنة وحفظ نسختيها وحلها

begin;

create table if not exists public.directory_sync_conflicts (
  id uuid primary key default gen_random_uuid(),
  operation_id text not null unique,
  user_id uuid not null references auth.users(id) on delete cascade,
  entity_type text not null
    check (entity_type in ('business')),
  operation_type text not null
    check (operation_type in (
      'update',
      'delete',
      'submit_for_review'
    )),
  entity_id uuid not null,
  expected_sync_version bigint not null default 0,
  server_sync_version bigint not null default 0,
  local_payload jsonb not null default '{}'::jsonb,
  server_snapshot jsonb not null default '{}'::jsonb,
  status text not null default 'pending'
    check (status in (
      'pending',
      'resolved_keep_local',
      'resolved_use_server'
    )),
  resolution_operation_id text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  resolved_at timestamptz
);

create index if not exists directory_sync_conflicts_user_status_idx
  on public.directory_sync_conflicts(user_id, status, created_at desc);

alter table public.directory_sync_conflicts enable row level security;

revoke all on table public.directory_sync_conflicts
  from public, anon, authenticated;

create or replace function public.process_directory_sync_operation(
  p_operation_id text,
  p_entity_type text,
  p_operation_type text,
  p_entity_id uuid default null,
  p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_receipt_user_id uuid;
  v_existing_result jsonb;
  v_business public.businesses%rowtype;
  v_result jsonb;
  v_category_id uuid;
  v_expected_sync_version bigint;
  v_conflict_id uuid;
  v_server_snapshot jsonb;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.'
      using errcode = '42501';
  end if;

  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise exception 'The operation payload must be a JSON object.'
      using errcode = '22023';
  end if;

  if p_operation_id is null
      or length(trim(p_operation_id)) < 8
      or length(p_operation_id) > 180 then
    raise exception 'Invalid operation ID.'
      using errcode = '22023';
  end if;

  if p_entity_type is distinct from 'business' then
    raise exception 'Unsupported entity type: %', p_entity_type
      using errcode = '22023';
  end if;

  if p_operation_type is null
      or p_operation_type not in (
        'create',
        'update',
        'delete',
        'submit_for_review'
      ) then
    raise exception 'Unsupported operation type: %', p_operation_type
      using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_operation_id, 0));

  select receipt.user_id, receipt.result
  into v_receipt_user_id, v_existing_result
  from public.directory_sync_operation_receipts receipt
  where receipt.operation_id = p_operation_id;

  if found then
    if v_receipt_user_id <> v_user_id then
      raise exception 'Operation ID belongs to another user.'
        using errcode = '42501';
    end if;

    return v_existing_result || jsonb_build_object('replayed', true);
  end if;

  if p_operation_type <> 'create' then
    if p_entity_id is null then
      raise exception 'entity_id is required for this operation.'
        using errcode = '22023';
    end if;

    select business.*
    into v_business
    from public.businesses business
    where business.id = p_entity_id
      and (
        business.owner_id = v_user_id
        or public.is_admin()
      );

    if not found then
      raise exception 'The business is not available for this user.'
        using errcode = '42501';
    end if;

    if p_payload ? '_base_sync_version' then
      begin
        v_expected_sync_version :=
          nullif(trim(p_payload ->> '_base_sync_version'), '')::bigint;
      exception
        when invalid_text_representation then
          raise exception 'Invalid base sync version.'
            using errcode = '22023';
      end;
    end if;

    if v_expected_sync_version is not null
        and v_expected_sync_version <> v_business.sync_version then
      select jsonb_build_object(
        'id', v_business.id,
        'owner_id', v_business.owner_id,
        'category_id', v_business.category_id,
        'category_name', category.name_ar,
        'name', v_business.name,
        'description', v_business.description,
        'phone', v_business.phone,
        'whatsapp', v_business.whatsapp,
        'address', v_business.address,
        'logo_url', v_business.logo_url,
        'cover_url', v_business.cover_url,
        'status', v_business.status,
        'rejection_reason', v_business.rejection_reason,
        'is_active', v_business.is_active,
        'sync_version', v_business.sync_version,
        'updated_at', v_business.updated_at
      )
      into v_server_snapshot
      from public.categories category
      where category.id = v_business.category_id;

      if v_server_snapshot is null then
        v_server_snapshot := to_jsonb(v_business);
      end if;

      insert into public.directory_sync_conflicts (
        operation_id,
        user_id,
        entity_type,
        operation_type,
        entity_id,
        expected_sync_version,
        server_sync_version,
        local_payload,
        server_snapshot,
        status,
        updated_at
      )
      values (
        p_operation_id,
        v_user_id,
        p_entity_type,
        p_operation_type,
        p_entity_id,
        coalesce(v_expected_sync_version, 0),
        v_business.sync_version,
        p_payload,
        v_server_snapshot,
        'pending',
        timezone('utc', now())
      )
      on conflict (operation_id) do update
      set
        expected_sync_version = excluded.expected_sync_version,
        server_sync_version = excluded.server_sync_version,
        local_payload = excluded.local_payload,
        server_snapshot = excluded.server_snapshot,
        status = 'pending',
        updated_at = timezone('utc', now()),
        resolved_at = null,
        resolution_operation_id = null
      returning id into v_conflict_id;

      v_result := jsonb_build_object(
        'operation_id', p_operation_id,
        'entity_type', p_entity_type,
        'operation_type', p_operation_type,
        'entity_id', p_entity_id,
        'remote_status', 'conflict',
        'conflict_id', v_conflict_id,
        'expected_sync_version', coalesce(v_expected_sync_version, 0),
        'server_sync_version', v_business.sync_version,
        'server_snapshot', v_server_snapshot,
        'processed_at', timezone('utc', now()),
        'replayed', false
      );

      insert into public.directory_sync_operation_receipts (
        operation_id,
        user_id,
        entity_type,
        operation_type,
        entity_id,
        result
      )
      values (
        p_operation_id,
        v_user_id,
        p_entity_type,
        p_operation_type,
        p_entity_id,
        v_result
      );

      return v_result;
    end if;
  end if;

  if p_operation_type = 'create' then
    if nullif(trim(p_payload ->> 'category_id'), '') is null
        or nullif(trim(p_payload ->> 'name'), '') is null
        or nullif(trim(p_payload ->> 'phone'), '') is null then
      raise exception 'category_id, name and phone are required.'
        using errcode = '22023';
    end if;

    v_category_id := (p_payload ->> 'category_id')::uuid;

    if not exists (
      select 1
      from public.categories category
      where category.id = v_category_id
        and category.is_active = true
    ) then
      raise exception 'The selected category is not active.'
        using errcode = '23503';
    end if;

    insert into public.businesses (
      id,
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
      status
    )
    values (
      coalesce(p_entity_id, gen_random_uuid()),
      v_user_id,
      v_category_id,
      trim(p_payload ->> 'name'),
      coalesce(p_payload ->> 'description', ''),
      trim(p_payload ->> 'phone'),
      coalesce(p_payload ->> 'whatsapp', ''),
      coalesce(nullif(trim(p_payload ->> 'address'), ''), 'الحامي'),
      case
        when nullif(trim(p_payload ->> 'latitude'), '') is null then null
        else (p_payload ->> 'latitude')::numeric
      end,
      case
        when nullif(trim(p_payload ->> 'longitude'), '') is null then null
        else (p_payload ->> 'longitude')::numeric
      end,
      nullif(trim(p_payload ->> 'logo_url'), ''),
      nullif(trim(p_payload ->> 'cover_url'), ''),
      case
        when lower(coalesce(p_payload ->> 'submit_for_review', 'false'))
          in ('true', '1', 'yes', 'on')
          then 'pending'
        else 'draft'
      end
    )
    returning * into v_business;

  elsif p_operation_type = 'update' then
    if p_payload ? 'name'
        and nullif(trim(p_payload ->> 'name'), '') is null then
      raise exception 'name cannot be empty.'
        using errcode = '22023';
    end if;

    if p_payload ? 'phone'
        and nullif(trim(p_payload ->> 'phone'), '') is null then
      raise exception 'phone cannot be empty.'
        using errcode = '22023';
    end if;

    if p_payload ? 'category_id' then
      if nullif(trim(p_payload ->> 'category_id'), '') is null then
        raise exception 'category_id cannot be empty.'
          using errcode = '22023';
      end if;

      v_category_id := (p_payload ->> 'category_id')::uuid;
      if not exists (
        select 1
        from public.categories category
        where category.id = v_category_id
          and category.is_active = true
      ) then
        raise exception 'The selected category is not active.'
          using errcode = '23503';
      end if;
    end if;

    update public.businesses business
    set
      category_id = case
        when p_payload ? 'category_id'
          then (p_payload ->> 'category_id')::uuid
        else business.category_id
      end,
      name = case
        when p_payload ? 'name'
          then trim(p_payload ->> 'name')
        else business.name
      end,
      description = case
        when p_payload ? 'description'
          then coalesce(p_payload ->> 'description', '')
        else business.description
      end,
      phone = case
        when p_payload ? 'phone'
          then trim(p_payload ->> 'phone')
        else business.phone
      end,
      whatsapp = case
        when p_payload ? 'whatsapp'
          then coalesce(p_payload ->> 'whatsapp', '')
        else business.whatsapp
      end,
      address = case
        when p_payload ? 'address'
          then coalesce(nullif(trim(p_payload ->> 'address'), ''), 'الحامي')
        else business.address
      end,
      latitude = case
        when not (p_payload ? 'latitude') then business.latitude
        when nullif(trim(p_payload ->> 'latitude'), '') is null then null
        else (p_payload ->> 'latitude')::numeric
      end,
      longitude = case
        when not (p_payload ? 'longitude') then business.longitude
        when nullif(trim(p_payload ->> 'longitude'), '') is null then null
        else (p_payload ->> 'longitude')::numeric
      end,
      logo_url = case
        when p_payload ? 'logo_url'
          then nullif(trim(p_payload ->> 'logo_url'), '')
        else business.logo_url
      end,
      cover_url = case
        when p_payload ? 'cover_url'
          then nullif(trim(p_payload ->> 'cover_url'), '')
        else business.cover_url
      end,
      status = case
        when lower(coalesce(p_payload ->> 'submit_for_review', 'false'))
          in ('true', '1', 'yes', 'on')
          then 'pending'
        else business.status
      end
    where business.id = p_entity_id
    returning * into v_business;

  elsif p_operation_type = 'submit_for_review' then
    update public.businesses business
    set status = 'pending'
    where business.id = p_entity_id
    returning * into v_business;

  else
    delete from public.businesses business
    where business.id = p_entity_id
    returning * into v_business;
  end if;

  select jsonb_build_object(
    'id', v_business.id,
    'owner_id', v_business.owner_id,
    'category_id', v_business.category_id,
    'category_name', category.name_ar,
    'name', v_business.name,
    'description', v_business.description,
    'phone', v_business.phone,
    'whatsapp', v_business.whatsapp,
    'address', v_business.address,
    'logo_url', v_business.logo_url,
    'cover_url', v_business.cover_url,
    'status', v_business.status,
    'rejection_reason', v_business.rejection_reason,
    'is_active', v_business.is_active,
    'sync_version', v_business.sync_version,
    'updated_at', v_business.updated_at
  )
  into v_server_snapshot
  from public.categories category
  where category.id = v_business.category_id;

  if v_server_snapshot is null then
    v_server_snapshot := to_jsonb(v_business);
  end if;

  v_result := jsonb_build_object(
    'operation_id', p_operation_id,
    'entity_type', p_entity_type,
    'operation_type', p_operation_type,
    'entity_id', v_business.id,
    'remote_status', case
      when p_operation_type = 'delete' then 'deleted'
      else v_business.status
    end,
    'server_sync_version', v_business.sync_version,
    'server_snapshot', v_server_snapshot,
    'processed_at', timezone('utc', now()),
    'replayed', false
  );

  insert into public.directory_sync_operation_receipts (
    operation_id,
    user_id,
    entity_type,
    operation_type,
    entity_id,
    result
  )
  values (
    p_operation_id,
    v_user_id,
    p_entity_type,
    p_operation_type,
    v_business.id,
    v_result
  );

  return v_result;
end;
$$;

create or replace function public.resolve_directory_sync_conflict(
  p_conflict_id uuid,
  p_resolution text,
  p_resolution_operation_id text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_conflict public.directory_sync_conflicts%rowtype;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.'
      using errcode = '42501';
  end if;

  if p_resolution not in (
    'resolved_keep_local',
    'resolved_use_server'
  ) then
    raise exception 'Unsupported conflict resolution.'
      using errcode = '22023';
  end if;

  update public.directory_sync_conflicts conflict
  set
    status = p_resolution,
    resolution_operation_id = p_resolution_operation_id,
    updated_at = timezone('utc', now()),
    resolved_at = timezone('utc', now())
  where conflict.id = p_conflict_id
    and conflict.user_id = v_user_id
  returning * into v_conflict;

  if not found then
    raise exception 'The conflict is not available for this user.'
      using errcode = '42501';
  end if;

  return jsonb_build_object(
    'conflict_id', v_conflict.id,
    'status', v_conflict.status,
    'resolution_operation_id', v_conflict.resolution_operation_id,
    'resolved_at', v_conflict.resolved_at
  );
end;
$$;

revoke all on function public.process_directory_sync_operation(
  text,
  text,
  text,
  uuid,
  jsonb
) from public, anon;

grant execute on function public.process_directory_sync_operation(
  text,
  text,
  text,
  uuid,
  jsonb
) to authenticated;

revoke all on function public.resolve_directory_sync_conflict(
  uuid,
  text,
  text
) from public, anon;

grant execute on function public.resolve_directory_sync_conflict(
  uuid,
  text,
  text
) to authenticated;

commit;
