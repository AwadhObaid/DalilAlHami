-- ============================================================
-- Dalil Al Hami - Phase 17C.1
-- Contact integrity + safe legacy projection reconciliation.
--
-- Goals:
--   1) Keep modern multi-contact rows as the source of truth.
--   2) Prevent internal projection writes from re-parsing/destructively
--      rebuilding the multi-contact set.
--   3) Align server validation with the Flutter client:
--      5..20 numeric digits per contact.
--   4) Reconcile businesses.phone / businesses.whatsapp from the
--      authoritative active contact rows.
--   5) Fail the migration if any contact invariant remains broken.
-- ============================================================

create or replace function public.refresh_business_legacy_contact_fields(
  p_business_id uuid
)
returns void
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  primary_phone text;
  whatsapp_phone text;
begin
  select c.phone_number
  into primary_phone
  from public.business_contact_numbers c
  where c.business_id = p_business_id
    and c.deleted_at is null
  order by c.is_primary desc, c.sort_order, c.created_at, c.id
  limit 1;

  select c.phone_number
  into whatsapp_phone
  from public.business_contact_numbers c
  where c.business_id = p_business_id
    and c.deleted_at is null
    and c.supports_whatsapp = true
  order by c.is_primary desc, c.sort_order, c.created_at, c.id
  limit 1;

  if primary_phone is null then
    return;
  end if;

  -- This update is an internal projection from contact rows to the
  -- legacy compatibility columns. It must never be interpreted as a
  -- legacy client edit that reconstructs the contact rows.
  perform set_config('dalil.contact_projection_write', 'on', true);

  begin
    update public.businesses b
    set phone = primary_phone,
        whatsapp = coalesce(whatsapp_phone, '')
    where b.id = p_business_id
      and (
        b.phone is distinct from primary_phone
        or b.whatsapp is distinct from coalesce(whatsapp_phone, '')
      );
  exception
    when others then
      perform set_config('dalil.contact_projection_write', 'off', true);
      raise;
  end;

  perform set_config('dalil.contact_projection_write', 'off', true);
end;
$function$;

create or replace function public.sync_legacy_business_fields_to_contacts()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  parsed record;
  next_order integer := 0;
  normalized_whatsapp text;
  already_added_whatsapp boolean := false;
  active_contact_count integer := 0;
  modern_multi_contact_write boolean := false;
  projection_write boolean := false;
begin
  projection_write :=
    coalesce(current_setting('dalil.contact_projection_write', true), '') = 'on';

  if projection_write then
    return new;
  end if;

  if pg_trigger_depth() > 1 then
    return new;
  end if;

  if tg_op = 'UPDATE'
     and new.phone is not distinct from old.phone
     and new.whatsapp is not distinct from old.whatsapp then
    return new;
  end if;

  if tg_op = 'UPDATE' then
    select count(*)::integer
    into active_contact_count
    from public.business_contact_numbers c
    where c.business_id = new.id
      and c.deleted_at is null;

    modern_multi_contact_write :=
      coalesce(current_setting('dalil.multi_contact_write', true), '') = 'on';

    if active_contact_count > 1 and not modern_multi_contact_write then
      raise exception
        'This business has multiple contact numbers. Use a current app version to edit phone or WhatsApp numbers.'
        using errcode = '22023';
    end if;
  end if;

  update public.business_contact_numbers
  set deleted_at = timezone('utc', now())
  where business_id = new.id
    and deleted_at is null;

  normalized_whatsapp :=
    public.normalize_business_contact_number(new.whatsapp);

  for parsed in
    select *
    from public.split_legacy_business_phone_numbers(new.phone)
  loop
    exit when next_order >= 5;

    if exists (
      select 1
      from public.business_contact_numbers c
      where c.business_id = new.id
        and c.deleted_at is null
        and public.normalize_business_contact_number(c.phone_number)
            = public.normalize_business_contact_number(parsed.phone_number)
    ) then
      continue;
    end if;

    insert into public.business_contact_numbers (
      business_id,
      phone_number,
      label,
      is_primary,
      supports_whatsapp,
      sort_order
    ) values (
      new.id,
      parsed.phone_number,
      case when next_order = 0 then 'الرئيسي' else 'رقم إضافي' end,
      next_order = 0,
      normalized_whatsapp <> ''
        and public.normalize_business_contact_number(parsed.phone_number)
            = normalized_whatsapp,
      next_order::smallint
    );

    if normalized_whatsapp <> ''
       and public.normalize_business_contact_number(parsed.phone_number)
           = normalized_whatsapp then
      already_added_whatsapp := true;
    end if;

    next_order := next_order + 1;
  end loop;

  if normalized_whatsapp <> ''
     and not already_added_whatsapp
     and next_order < 5 then
    insert into public.business_contact_numbers (
      business_id,
      phone_number,
      label,
      is_primary,
      supports_whatsapp,
      sort_order
    ) values (
      new.id,
      btrim(new.whatsapp),
      case when next_order = 0 then 'الرئيسي' else 'واتساب' end,
      next_order = 0,
      true,
      next_order::smallint
    );
  end if;

  return new;
end;
$function$;

create or replace function public.enforce_business_contact_number_limit()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  active_count integer;
  duplicate_count integer;
  digit_count integer;
begin
  new.phone_number := btrim(new.phone_number);
  new.label := btrim(coalesce(new.label, ''));

  if new.deleted_at is not null then
    return new;
  end if;

  digit_count :=
    length(regexp_replace(coalesce(new.phone_number, ''), '[^0-9]', '', 'g'));

  if digit_count < 5 or digit_count > 20 then
    raise exception
      'Each contact number must contain between 5 and 20 numeric digits.'
      using errcode = '23514';
  end if;

  if tg_op = 'UPDATE' then
    select count(*)
    into active_count
    from public.business_contact_numbers c
    where c.business_id = new.business_id
      and c.deleted_at is null
      and c.id <> old.id;

    select count(*)
    into duplicate_count
    from public.business_contact_numbers c
    where c.business_id = new.business_id
      and c.deleted_at is null
      and c.id <> old.id
      and public.normalize_business_contact_number(c.phone_number)
          = public.normalize_business_contact_number(new.phone_number);
  else
    select count(*)
    into active_count
    from public.business_contact_numbers c
    where c.business_id = new.business_id
      and c.deleted_at is null;

    select count(*)
    into duplicate_count
    from public.business_contact_numbers c
    where c.business_id = new.business_id
      and c.deleted_at is null
      and public.normalize_business_contact_number(c.phone_number)
          = public.normalize_business_contact_number(new.phone_number);
  end if;

  if active_count >= 5 then
    raise exception 'A business can have at most 5 active contact numbers.'
      using errcode = '23514';
  end if;

  if duplicate_count > 0 then
    raise exception 'Duplicate active contact number for this business.'
      using errcode = '23505';
  end if;

  return new;
end;
$function$;

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
  v_digit_count integer;
begin
  if p_business_id is null then
    raise exception 'business_id is required.' using errcode = '22023';
  end if;

  if not exists (
    select 1
    from public.businesses b
    where b.id = p_business_id
  ) then
    raise exception 'Business was not found.' using errcode = 'P0002';
  end if;

  if p_contacts is null or jsonb_typeof(p_contacts) <> 'array' then
    raise exception 'contact_numbers must be a JSON array.'
      using errcode = '22023';
  end if;

  if jsonb_array_length(p_contacts) < 1
     or jsonb_array_length(p_contacts) > 5 then
    raise exception
      'A business must have between 1 and 5 contact numbers.'
      using errcode = '22023';
  end if;

  for v_entry in
    select value as item, ordinality
    from jsonb_array_elements(p_contacts) with ordinality
  loop
    v_item := v_entry.item;

    if jsonb_typeof(v_item) <> 'object' then
      raise exception 'Each contact number must be a JSON object.'
        using errcode = '22023';
    end if;

    v_phone := btrim(coalesce(v_item ->> 'phone_number', ''));
    v_normalized := public.normalize_business_contact_number(v_phone);
    v_digit_count :=
      length(regexp_replace(coalesce(v_phone, ''), '[^0-9]', '', 'g'));

    if v_normalized = ''
       or v_digit_count < 5
       or v_digit_count > 20 then
      raise exception
        'Each contact number must contain between 5 and 20 numeric digits.'
        using errcode = '22023';
    end if;

    if v_normalized = any(v_seen) then
      raise exception 'Duplicate contact numbers are not allowed.'
        using errcode = '23505';
    end if;

    v_seen := array_append(v_seen, v_normalized);

    v_primary :=
      lower(coalesce(v_item ->> 'is_primary', 'false'))
      in ('true', '1', 'yes', 'on');
    v_whatsapp :=
      lower(coalesce(v_item ->> 'supports_whatsapp', 'false'))
      in ('true', '1', 'yes', 'on');

    if v_primary then
      v_primary_count := v_primary_count + 1;
    end if;
    if v_whatsapp then
      v_whatsapp_count := v_whatsapp_count + 1;
    end if;

    v_label := btrim(coalesce(v_item ->> 'label', ''));
    if length(v_label) > 40 then
      raise exception 'Contact label is too long.'
        using errcode = '22023';
    end if;
  end loop;

  if v_primary_count <> 1 then
    raise exception 'Exactly one contact number must be primary.'
      using errcode = '22023';
  end if;

  if v_whatsapp_count > 1 then
    raise exception 'At most one contact number may support WhatsApp.'
      using errcode = '22023';
  end if;

  update public.business_contact_numbers
  set deleted_at = timezone('utc', now())
  where business_id = p_business_id
    and deleted_at is null;

  for v_entry in
    select value as item, ordinality
    from jsonb_array_elements(p_contacts) with ordinality
    order by
      (
        lower(coalesce(value ->> 'is_primary', 'false'))
        in ('true', '1', 'yes', 'on')
      ) desc,
      ordinality
  loop
    v_item := v_entry.item;
    v_phone := btrim(v_item ->> 'phone_number');
    v_primary :=
      lower(coalesce(v_item ->> 'is_primary', 'false'))
      in ('true', '1', 'yes', 'on');
    v_whatsapp :=
      lower(coalesce(v_item ->> 'supports_whatsapp', 'false'))
      in ('true', '1', 'yes', 'on');
    v_label := btrim(coalesce(v_item ->> 'label', ''));

    if v_label = '' then
      v_label := case
        when v_primary then 'الرئيسي'
        else 'رقم إضافي'
      end;
    end if;

    insert into public.business_contact_numbers (
      business_id,
      phone_number,
      label,
      is_primary,
      supports_whatsapp,
      sort_order
    ) values (
      p_business_id,
      v_phone,
      v_label,
      v_primary,
      v_whatsapp,
      (v_entry.ordinality - 1)::smallint
    );
  end loop;

  update public.businesses
  set updated_at = timezone('utc', now())
  where id = p_business_id;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
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
      )
      order by c.is_primary desc, c.sort_order, c.created_at, c.id
    ),
    '[]'::jsonb
  )
  into v_contacts
  from public.business_contact_numbers c
  where c.business_id = p_business_id
    and c.deleted_at is null;

  return v_contacts;
end;
$function$;

-- Reconcile the legacy projection from authoritative active contacts.
-- refresh_business_legacy_contact_fields now marks its internal update so
-- sync_legacy_business_fields_to_contacts will not destructively rebuild rows.
do $phase17c1_reconcile$
declare
  item record;
begin
  for item in
    select distinct c.business_id
    from public.business_contact_numbers c
    where c.deleted_at is null
  loop
    perform public.refresh_business_legacy_contact_fields(item.business_id);
  end loop;
end;
$phase17c1_reconcile$;

-- Hard postconditions. The migration must abort instead of silently leaving
-- corrupted multi-contact data.
do $phase17c1_verify$
declare
  bad_count integer;
begin
  select count(*)
  into bad_count
  from (
    select
      c.business_id,
      count(*) as contact_count,
      count(*) filter (where c.is_primary) as primary_count,
      count(*) filter (where c.supports_whatsapp) as whatsapp_count
    from public.business_contact_numbers c
    where c.deleted_at is null
    group by c.business_id
  ) x
  where x.contact_count < 1
     or x.contact_count > 5
     or x.primary_count <> 1
     or x.whatsapp_count > 1;

  if bad_count <> 0 then
    raise exception
      'Phase 17C.1 verification failed: % businesses violate contact-count/primary/WhatsApp invariants.',
      bad_count;
  end if;

  select count(*)
  into bad_count
  from public.business_contact_numbers c
  where c.deleted_at is null
    and (
      length(regexp_replace(coalesce(c.phone_number, ''), '[^0-9]', '', 'g')) < 5
      or length(regexp_replace(coalesce(c.phone_number, ''), '[^0-9]', '', 'g')) > 20
    );

  if bad_count <> 0 then
    raise exception
      'Phase 17C.1 verification failed: % active contacts violate digit-count validation.',
      bad_count;
  end if;

  select count(*)
  into bad_count
  from (
    select
      c.business_id,
      public.normalize_business_contact_number(c.phone_number) as normalized
    from public.business_contact_numbers c
    where c.deleted_at is null
    group by
      c.business_id,
      public.normalize_business_contact_number(c.phone_number)
    having count(*) > 1
  ) duplicates;

  if bad_count <> 0 then
    raise exception
      'Phase 17C.1 verification failed: % normalized duplicate groups remain.',
      bad_count;
  end if;

  select count(*)
  into bad_count
  from public.businesses b
  join lateral (
    select c.phone_number
    from public.business_contact_numbers c
    where c.business_id = b.id
      and c.deleted_at is null
    order by c.is_primary desc, c.sort_order, c.created_at, c.id
    limit 1
  ) p on true
  left join lateral (
    select c.phone_number
    from public.business_contact_numbers c
    where c.business_id = b.id
      and c.deleted_at is null
      and c.supports_whatsapp = true
    order by c.is_primary desc, c.sort_order, c.created_at, c.id
    limit 1
  ) w on true
  where b.phone is distinct from p.phone_number
     or b.whatsapp is distinct from coalesce(w.phone_number, '');

  if bad_count <> 0 then
    raise exception
      'Phase 17C.1 verification failed: % legacy projection mismatches remain.',
      bad_count;
  end if;
end;
$phase17c1_verify$;
