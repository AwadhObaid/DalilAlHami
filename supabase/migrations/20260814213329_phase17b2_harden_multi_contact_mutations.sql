-- Phase 17B.2 hardening.
-- Deployed before app rollout. Keeps old clients safe, preserves full conflict
-- payloads, and allows only one WhatsApp-enabled number per business.

create or replace function public.replace_business_contacts_from_payload(
  p_business_id uuid,
  p_contacts jsonb
)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_entry record;
  v_item jsonb;
  v_phone text;
  v_normalized text;
  v_label text;
  v_primary boolean;
  v_whatsapp boolean;
  v_primary_count integer := 0;
  v_whatsapp_count integer := 0;
  v_seen text[] := array[]::text[];
  v_contacts jsonb;
begin
  if p_business_id is null then
    raise exception 'business_id is required.' using errcode = '22023';
  end if;

  if not exists (select 1 from public.businesses b where b.id = p_business_id) then
    raise exception 'Business was not found.' using errcode = 'P0002';
  end if;

  if p_contacts is null or jsonb_typeof(p_contacts) <> 'array' then
    raise exception 'contact_numbers must be a JSON array.' using errcode = '22023';
  end if;

  if jsonb_array_length(p_contacts) < 1 or jsonb_array_length(p_contacts) > 5 then
    raise exception 'A business must have between 1 and 5 contact numbers.' using errcode = '22023';
  end if;

  for v_entry in
    select value as item, ordinality
    from jsonb_array_elements(p_contacts) with ordinality
  loop
    v_item := v_entry.item;
    if jsonb_typeof(v_item) <> 'object' then
      raise exception 'Each contact number must be a JSON object.' using errcode = '22023';
    end if;

    v_phone := btrim(coalesce(v_item ->> 'phone_number', ''));
    v_normalized := public.normalize_business_contact_number(v_phone);
    if v_normalized = '' or length(v_phone) < 5 then
      raise exception 'Each contact number must contain a valid phone number.' using errcode = '22023';
    end if;

    if v_normalized = any(v_seen) then
      raise exception 'Duplicate contact numbers are not allowed.' using errcode = '23505';
    end if;
    v_seen := array_append(v_seen, v_normalized);

    v_primary := lower(coalesce(v_item ->> 'is_primary', 'false')) in ('true', '1', 'yes', 'on');
    v_whatsapp := lower(coalesce(v_item ->> 'supports_whatsapp', 'false')) in ('true', '1', 'yes', 'on');
    if v_primary then v_primary_count := v_primary_count + 1; end if;
    if v_whatsapp then v_whatsapp_count := v_whatsapp_count + 1; end if;

    v_label := btrim(coalesce(v_item ->> 'label', ''));
    if length(v_label) > 40 then
      raise exception 'Contact label is too long.' using errcode = '22023';
    end if;
  end loop;

  if v_primary_count <> 1 then
    raise exception 'Exactly one contact number must be primary.' using errcode = '22023';
  end if;
  if v_whatsapp_count > 1 then
    raise exception 'At most one contact number may support WhatsApp.' using errcode = '22023';
  end if;

  update public.business_contact_numbers
  set deleted_at = timezone('utc', now())
  where business_id = p_business_id and deleted_at is null;

  for v_entry in
    select value as item, ordinality
    from jsonb_array_elements(p_contacts) with ordinality
    order by
      (lower(coalesce(value ->> 'is_primary', 'false')) in ('true', '1', 'yes', 'on')) desc,
      ordinality
  loop
    v_item := v_entry.item;
    v_phone := btrim(v_item ->> 'phone_number');
    v_primary := lower(coalesce(v_item ->> 'is_primary', 'false')) in ('true', '1', 'yes', 'on');
    v_whatsapp := lower(coalesce(v_item ->> 'supports_whatsapp', 'false')) in ('true', '1', 'yes', 'on');
    v_label := btrim(coalesce(v_item ->> 'label', ''));
    if v_label = '' then
      v_label := case when v_primary then 'الرئيسي' else 'رقم إضافي' end;
    end if;

    insert into public.business_contact_numbers (
      business_id, phone_number, label, is_primary, supports_whatsapp, sort_order
    ) values (
      p_business_id, v_phone, v_label, v_primary, v_whatsapp,
      (v_entry.ordinality - 1)::smallint
    );
  end loop;

  update public.businesses
  set updated_at = timezone('utc', now())
  where id = p_business_id;

  select coalesce(
    jsonb_agg(jsonb_build_object(
      'id', c.id,
      'business_id', c.business_id,
      'phone_number', c.phone_number,
      'label', c.label,
      'is_primary', c.is_primary,
      'supports_whatsapp', c.supports_whatsapp,
      'sort_order', c.sort_order,
      'created_at', c.created_at,
      'updated_at', c.updated_at,
      'deleted_at', c.deleted_at,
      'sync_version', c.sync_version
    ) order by c.is_primary desc, c.sort_order, c.created_at, c.id),
    '[]'::jsonb
  ) into v_contacts
  from public.business_contact_numbers c
  where c.business_id = p_business_id and c.deleted_at is null;

  return v_contacts;
end;
$function$;

revoke all on function public.replace_business_contacts_from_payload(uuid, jsonb) from public;
revoke all on function public.replace_business_contacts_from_payload(uuid, jsonb) from anon;
revoke all on function public.replace_business_contacts_from_payload(uuid, jsonb) from authenticated;

create or replace function public.process_directory_sync_operation_v2(
  p_operation_id text,
  p_entity_type text,
  p_operation_type text,
  p_entity_id uuid default null,
  p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_user_id uuid := auth.uid();
  v_result jsonb;
  v_business_id uuid;
  v_snapshot jsonb;
  v_conflict_id uuid;
  v_legacy_payload jsonb;
begin
  v_legacy_payload := p_payload - 'contact_numbers';

  if p_payload ? 'contact_numbers' then
    perform set_config('dalil.multi_contact_write', 'on', true);
    if p_operation_type = 'update' then
      v_legacy_payload := v_legacy_payload - 'phone' - 'whatsapp';
    end if;
  end if;

  v_result := public.process_directory_sync_operation(
    p_operation_id,
    p_entity_type,
    p_operation_type,
    p_entity_id,
    v_legacy_payload
  );

  if coalesce((v_result ->> 'replayed')::boolean, false) then return v_result; end if;
  if not (p_payload ? 'contact_numbers') then return v_result; end if;

  if v_result ->> 'remote_status' = 'conflict' then
    v_business_id := nullif(v_result ->> 'entity_id', '')::uuid;
    v_conflict_id := nullif(v_result ->> 'conflict_id', '')::uuid;
    v_snapshot := public.business_mutation_snapshot(v_business_id);
    v_result := v_result || jsonb_build_object('server_snapshot', v_snapshot);

    update public.directory_sync_operation_receipts r
    set result = v_result
    where r.operation_id = p_operation_id and r.user_id = v_user_id;

    if v_conflict_id is not null then
      update public.directory_sync_conflicts c
      set local_payload = p_payload,
          server_snapshot = v_snapshot,
          updated_at = timezone('utc', now())
      where c.id = v_conflict_id and c.user_id = v_user_id;
    end if;
    return v_result;
  end if;

  if p_operation_type not in ('create', 'update') then return v_result; end if;

  v_business_id := nullif(v_result ->> 'entity_id', '')::uuid;
  if v_business_id is null then
    raise exception 'The synchronized business ID is missing.' using errcode = '22023';
  end if;

  perform public.replace_business_contacts_from_payload(
    v_business_id,
    p_payload -> 'contact_numbers'
  );

  v_snapshot := public.business_mutation_snapshot(v_business_id);
  v_result := v_result || jsonb_build_object(
    'server_sync_version', coalesce((v_snapshot ->> 'sync_version')::bigint, 0),
    'server_snapshot', v_snapshot
  );

  update public.directory_sync_operation_receipts r
  set result = v_result
  where r.operation_id = p_operation_id and r.user_id = v_user_id;

  return v_result;
end;
$function$;

revoke all on function public.process_directory_sync_operation_v2(text, text, text, uuid, jsonb) from public;
revoke all on function public.process_directory_sync_operation_v2(text, text, text, uuid, jsonb) from anon;
grant execute on function public.process_directory_sync_operation_v2(text, text, text, uuid, jsonb) to authenticated;

create or replace function public.admin_upsert_business_v2(
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
  p_cover_url text,
  p_contacts jsonb
)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_result jsonb;
  v_business_id uuid;
  v_legacy_phone text := p_phone;
  v_legacy_whatsapp text := p_whatsapp;
begin
  if not public.is_admin() then
    raise exception 'Administrator access is required.' using errcode = '42501';
  end if;

  perform set_config('dalil.multi_contact_write', 'on', true);

  if p_business_id is not null then
    select b.phone, b.whatsapp
    into v_legacy_phone, v_legacy_whatsapp
    from public.businesses b
    where b.id = p_business_id;
  end if;

  v_result := public.admin_upsert_business(
    p_business_id,
    p_category_id,
    p_name,
    p_description,
    v_legacy_phone,
    v_legacy_whatsapp,
    p_address,
    p_latitude,
    p_longitude,
    p_logo_url,
    p_cover_url
  );

  v_business_id := nullif(v_result ->> 'entity_id', '')::uuid;
  perform public.replace_business_contacts_from_payload(v_business_id, p_contacts);
  return v_result;
end;
$function$;

revoke all on function public.admin_upsert_business_v2(uuid, uuid, text, text, text, text, text, numeric, numeric, text, text, jsonb) from public;
revoke all on function public.admin_upsert_business_v2(uuid, uuid, text, text, text, text, text, numeric, numeric, text, text, jsonb) from anon;
grant execute on function public.admin_upsert_business_v2(uuid, uuid, text, text, text, text, text, numeric, numeric, text, text, jsonb) to authenticated;
