-- دليل الحامي
-- المرحلة 05B-2A: إيصالات العمليات غير المتصلة ومعالجة آمنة قابلة للتكرار

begin;

create table if not exists public.directory_sync_operation_receipts (
  operation_id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  entity_type text not null
    check (entity_type in ('business')),
  operation_type text not null
    check (operation_type in (
      'create',
      'update',
      'delete',
      'submit_for_review'
    )),
  entity_id uuid,
  result jsonb not null,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists directory_sync_receipts_user_created_idx
  on public.directory_sync_operation_receipts(user_id, created_at desc);

alter table public.directory_sync_operation_receipts
  enable row level security;

revoke all on table public.directory_sync_operation_receipts
  from anon, authenticated;

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

  perform pg_advisory_xact_lock(
    hashtextextended(p_operation_id, 0)
  );

  select receipt.user_id, receipt.result
  into v_receipt_user_id, v_existing_result
  from public.directory_sync_operation_receipts receipt
  where receipt.operation_id = p_operation_id;

  if found then
    if v_receipt_user_id <> v_user_id then
      raise exception 'Operation ID belongs to another user.'
        using errcode = '42501';
    end if;

    return v_existing_result || jsonb_build_object(
      'replayed', true
    );
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
    if p_entity_id is null then
      raise exception 'entity_id is required for update.'
        using errcode = '22023';
    end if;

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

    if not exists (
      select 1
      from public.businesses business
      where business.id = p_entity_id
        and (
          business.owner_id = v_user_id
          or public.is_admin()
        )
    ) then
      raise exception 'The business is not available for this user.'
        using errcode = '42501';
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
      end
    where business.id = p_entity_id
    returning * into v_business;

  elsif p_operation_type = 'submit_for_review' then
    if p_entity_id is null then
      raise exception 'entity_id is required for review submission.'
        using errcode = '22023';
    end if;

    update public.businesses business
    set status = 'pending'
    where business.id = p_entity_id
      and (
        business.owner_id = v_user_id
        or public.is_admin()
      )
    returning * into v_business;

    if not found then
      raise exception 'The business is not available for this user.'
        using errcode = '42501';
    end if;

  else
    if p_entity_id is null then
      raise exception 'entity_id is required for delete.'
        using errcode = '22023';
    end if;

    delete from public.businesses business
    where business.id = p_entity_id
      and (
        business.owner_id = v_user_id
        or public.is_admin()
      )
    returning * into v_business;

    if not found then
      raise exception 'The business is not available for this user.'
        using errcode = '42501';
    end if;
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

commit;
