-- Dalil Al Hami - Phase 17A.1
-- Multiple Contact Numbers Foundation
-- Additive migration: legacy businesses.phone / businesses.whatsapp are preserved.

create table if not exists public.business_contact_numbers (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  phone_number text not null,
  label text not null default '',
  is_primary boolean not null default false,
  supports_whatsapp boolean not null default false,
  sort_order smallint not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz null,
  constraint business_contact_numbers_phone_not_blank
    check (length(btrim(phone_number)) between 3 and 32),
  constraint business_contact_numbers_label_length
    check (length(label) <= 50),
  constraint business_contact_numbers_sort_order_range
    check (sort_order between 0 and 4)
);

create index if not exists business_contact_numbers_business_order_idx
  on public.business_contact_numbers (business_id, sort_order, created_at)
  where deleted_at is null;

create unique index if not exists business_contact_numbers_one_primary_idx
  on public.business_contact_numbers (business_id)
  where is_primary = true and deleted_at is null;

create unique index if not exists business_contact_numbers_active_number_idx
  on public.business_contact_numbers (business_id, phone_number)
  where deleted_at is null;

alter table public.business_contact_numbers enable row level security;

drop policy if exists business_contact_numbers_select on public.business_contact_numbers;
create policy business_contact_numbers_select
on public.business_contact_numbers for select to anon, authenticated
using (
  exists (
    select 1 from public.businesses b
    where b.id = business_contact_numbers.business_id
      and (
        (b.status = 'approved' and b.is_active = true)
        or b.owner_id = (select auth.uid())
        or public.is_admin()
      )
  )
);

drop policy if exists business_contact_numbers_insert on public.business_contact_numbers;
create policy business_contact_numbers_insert
on public.business_contact_numbers for insert to authenticated
with check (
  deleted_at is null
  and exists (
    select 1 from public.businesses b
    where b.id = business_contact_numbers.business_id
      and (b.owner_id = (select auth.uid()) or public.is_admin())
  )
);

drop policy if exists business_contact_numbers_update on public.business_contact_numbers;
create policy business_contact_numbers_update
on public.business_contact_numbers for update to authenticated
using (
  exists (
    select 1 from public.businesses b
    where b.id = business_contact_numbers.business_id
      and (b.owner_id = (select auth.uid()) or public.is_admin())
  )
)
with check (
  exists (
    select 1 from public.businesses b
    where b.id = business_contact_numbers.business_id
      and (b.owner_id = (select auth.uid()) or public.is_admin())
  )
);

drop policy if exists business_contact_numbers_delete on public.business_contact_numbers;
create policy business_contact_numbers_delete
on public.business_contact_numbers for delete to authenticated
using (
  exists (
    select 1 from public.businesses b
    where b.id = business_contact_numbers.business_id
      and (b.owner_id = (select auth.uid()) or public.is_admin())
  )
);

create or replace function public.normalize_business_contact_number(p_value text)
returns text language sql immutable set search_path = public
as $$
  select regexp_replace(coalesce(btrim(p_value), ''), '[^0-9+]', '', 'g');
$$;
revoke all on function public.normalize_business_contact_number(text) from public;
grant execute on function public.normalize_business_contact_number(text) to anon, authenticated;

create or replace function public.enforce_business_contact_number_limit()
returns trigger language plpgsql security definer set search_path = public, pg_temp
as $$
declare
  active_count integer;
  duplicate_count integer;
begin
  new.phone_number := btrim(new.phone_number);
  new.label := btrim(coalesce(new.label, ''));

  if new.deleted_at is not null then
    return new;
  end if;

  if tg_op = 'UPDATE' then
    select count(*) into active_count
    from public.business_contact_numbers c
    where c.business_id = new.business_id
      and c.deleted_at is null
      and c.id <> old.id;

    select count(*) into duplicate_count
    from public.business_contact_numbers c
    where c.business_id = new.business_id
      and c.deleted_at is null
      and c.id <> old.id
      and public.normalize_business_contact_number(c.phone_number)
          = public.normalize_business_contact_number(new.phone_number);
  else
    select count(*) into active_count
    from public.business_contact_numbers c
    where c.business_id = new.business_id
      and c.deleted_at is null;

    select count(*) into duplicate_count
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
$$;

drop trigger if exists business_contact_numbers_limit_guard on public.business_contact_numbers;
create trigger business_contact_numbers_limit_guard
before insert or update on public.business_contact_numbers
for each row execute function public.enforce_business_contact_number_limit();

drop trigger if exists business_contact_numbers_set_updated_at on public.business_contact_numbers;
create trigger business_contact_numbers_set_updated_at
before update on public.business_contact_numbers
for each row execute function public.set_updated_at();

create or replace function public.split_legacy_business_phone_numbers(p_value text)
returns table(phone_number text, item_order integer)
language sql immutable set search_path = public
as $$
  with parts as (
    select btrim(part) as phone_number, ordinality::integer as item_order
    from regexp_split_to_table(
      coalesce(p_value, ''),
      E'\\s*(-{2,}|[,;/|\\n]+)\\s*'
    ) with ordinality as split(part, ordinality)
  )
  select parts.phone_number, parts.item_order
  from parts
  where length(parts.phone_number) >= 3
  order by parts.item_order;
$$;
revoke all on function public.split_legacy_business_phone_numbers(text) from public;

with parsed as (
  select b.id as business_id, p.phone_number, p.item_order,
         public.normalize_business_contact_number(p.phone_number) as normalized
  from public.businesses b
  cross join lateral public.split_legacy_business_phone_numbers(b.phone) p
), deduped as (
  select distinct on (business_id, normalized)
    business_id, phone_number, item_order, normalized
  from parsed
  where normalized <> ''
  order by business_id, normalized, item_order
), ranked as (
  select business_id, phone_number, normalized,
         row_number() over (partition by business_id order by item_order, phone_number) as rn
  from deduped
)
insert into public.business_contact_numbers (
  business_id, phone_number, label, is_primary, supports_whatsapp, sort_order
)
select r.business_id, r.phone_number,
       case when r.rn = 1 then 'الرئيسي' else 'رقم إضافي' end,
       r.rn = 1,
       public.normalize_business_contact_number(b.whatsapp) <> ''
         and r.normalized = public.normalize_business_contact_number(b.whatsapp),
       (r.rn - 1)::smallint
from ranked r
join public.businesses b on b.id = r.business_id
where r.rn <= 5
on conflict do nothing;

insert into public.business_contact_numbers (
  business_id, phone_number, label, is_primary, supports_whatsapp, sort_order
)
select b.id, btrim(b.whatsapp),
       case when cnt.active_count = 0 then 'الرئيسي' else 'واتساب' end,
       cnt.active_count = 0, true, cnt.active_count::smallint
from public.businesses b
cross join lateral (
  select count(*)::integer as active_count
  from public.business_contact_numbers c
  where c.business_id = b.id and c.deleted_at is null
) cnt
where public.normalize_business_contact_number(b.whatsapp) <> ''
  and cnt.active_count < 5
  and not exists (
    select 1 from public.business_contact_numbers c
    where c.business_id = b.id and c.deleted_at is null
      and public.normalize_business_contact_number(c.phone_number)
        = public.normalize_business_contact_number(b.whatsapp)
  )
on conflict do nothing;

update public.business_contact_numbers c
set supports_whatsapp = true
from public.businesses b
where b.id = c.business_id and c.deleted_at is null
  and public.normalize_business_contact_number(b.whatsapp) <> ''
  and public.normalize_business_contact_number(c.phone_number)
      = public.normalize_business_contact_number(b.whatsapp)
  and c.supports_whatsapp = false;

with first_contact as (
  select distinct on (business_id) id, business_id
  from public.business_contact_numbers
  where deleted_at is null
  order by business_id, is_primary desc, sort_order, created_at, id
)
update public.business_contact_numbers c
set is_primary = (c.id = f.id)
from first_contact f
where c.business_id = f.business_id and c.deleted_at is null
  and c.is_primary is distinct from (c.id = f.id);

create or replace function public.refresh_business_legacy_contact_fields(p_business_id uuid)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
declare primary_phone text; whatsapp_phone text;
begin
  select c.phone_number into primary_phone
  from public.business_contact_numbers c
  where c.business_id = p_business_id and c.deleted_at is null
  order by c.is_primary desc, c.sort_order, c.created_at, c.id limit 1;

  select c.phone_number into whatsapp_phone
  from public.business_contact_numbers c
  where c.business_id = p_business_id and c.deleted_at is null
    and c.supports_whatsapp = true
  order by c.is_primary desc, c.sort_order, c.created_at, c.id limit 1;

  if primary_phone is null then return; end if;

  update public.businesses b
  set phone = primary_phone, whatsapp = coalesce(whatsapp_phone, '')
  where b.id = p_business_id
    and (b.phone is distinct from primary_phone
      or b.whatsapp is distinct from coalesce(whatsapp_phone, ''));
end;
$$;
revoke all on function public.refresh_business_legacy_contact_fields(uuid) from public;

create or replace function public.ensure_business_contact_primary(p_business_id uuid)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
declare
  has_primary boolean;
  fallback_id uuid;
begin
  select exists (
    select 1 from public.business_contact_numbers c
    where c.business_id = p_business_id
      and c.deleted_at is null
      and c.is_primary = true
  ) into has_primary;

  if has_primary then return; end if;

  select c.id into fallback_id
  from public.business_contact_numbers c
  where c.business_id = p_business_id
    and c.deleted_at is null
  order by c.sort_order, c.created_at, c.id
  limit 1;

  if fallback_id is not null then
    update public.business_contact_numbers
    set is_primary = true
    where id = fallback_id and is_primary = false;
  end if;
end;
$$;
revoke all on function public.ensure_business_contact_primary(uuid) from public;

create or replace function public.business_contact_numbers_after_change_trigger()
returns trigger language plpgsql security definer set search_path = public, pg_temp
as $$
declare
  affected_business_id uuid;
begin
  affected_business_id := case when tg_op = 'DELETE' then old.business_id else new.business_id end;

  -- Contact edits are business-content edits. Owners must go through the same
  -- moderation lifecycle as edits to the legacy phone/WhatsApp fields.
  if auth.uid() is not null and not public.is_admin() then
    update public.businesses
    set status = 'pending',
        rejection_reason = null,
        approved_at = null,
        approved_by = null
    where id = affected_business_id
      and status = 'approved';
  end if;

  perform public.ensure_business_contact_primary(affected_business_id);
  perform public.refresh_business_legacy_contact_fields(affected_business_id);

  if tg_op = 'UPDATE' and old.business_id is distinct from new.business_id then
    perform public.ensure_business_contact_primary(old.business_id);
    perform public.refresh_business_legacy_contact_fields(old.business_id);
  end if;

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

drop trigger if exists business_contact_numbers_refresh_legacy on public.business_contact_numbers;
drop trigger if exists business_contact_numbers_after_change on public.business_contact_numbers;
create trigger business_contact_numbers_after_change
after insert or update or delete on public.business_contact_numbers
for each row execute function public.business_contact_numbers_after_change_trigger();

-- No bulk rewrite of businesses.phone is performed here. Rewriting approved
-- legacy rows during migration would incorrectly send them back to moderation.
-- The existing legacy values remain untouched until a real owner/admin contact
-- edit occurs, while new clients can read the normalized rows immediately.

create or replace function public.sync_legacy_business_fields_to_contacts()
returns trigger language plpgsql security definer set search_path = public, pg_temp
as $$
declare parsed record; next_order integer := 0; normalized_whatsapp text; already_added_whatsapp boolean := false;
begin
  if pg_trigger_depth() > 1 then return new; end if;
  if tg_op = 'UPDATE'
     and new.phone is not distinct from old.phone
     and new.whatsapp is not distinct from old.whatsapp then
    return new;
  end if;

  update public.business_contact_numbers
  set deleted_at = timezone('utc', now())
  where business_id = new.id and deleted_at is null;

  normalized_whatsapp := public.normalize_business_contact_number(new.whatsapp);

  for parsed in select * from public.split_legacy_business_phone_numbers(new.phone) loop
    exit when next_order >= 5;
    if exists (
      select 1 from public.business_contact_numbers c
      where c.business_id = new.id and c.deleted_at is null
        and public.normalize_business_contact_number(c.phone_number)
            = public.normalize_business_contact_number(parsed.phone_number)
    ) then continue; end if;

    insert into public.business_contact_numbers (
      business_id, phone_number, label, is_primary, supports_whatsapp, sort_order
    ) values (
      new.id, parsed.phone_number,
      case when next_order = 0 then 'الرئيسي' else 'رقم إضافي' end,
      next_order = 0,
      normalized_whatsapp <> '' and public.normalize_business_contact_number(parsed.phone_number) = normalized_whatsapp,
      next_order::smallint
    );

    if normalized_whatsapp <> '' and public.normalize_business_contact_number(parsed.phone_number) = normalized_whatsapp then
      already_added_whatsapp := true;
    end if;
    next_order := next_order + 1;
  end loop;

  if normalized_whatsapp <> '' and not already_added_whatsapp and next_order < 5 then
    insert into public.business_contact_numbers (
      business_id, phone_number, label, is_primary, supports_whatsapp, sort_order
    ) values (
      new.id, btrim(new.whatsapp),
      case when next_order = 0 then 'الرئيسي' else 'واتساب' end,
      next_order = 0, true, next_order::smallint
    );
  end if;
  return new;
end;
$$;
revoke all on function public.sync_legacy_business_fields_to_contacts() from public;

drop trigger if exists businesses_sync_legacy_contacts on public.businesses;
create trigger businesses_sync_legacy_contacts
after insert or update on public.businesses
for each row execute function public.sync_legacy_business_fields_to_contacts();

grant select on public.business_contact_numbers to anon, authenticated;
grant insert, update, delete on public.business_contact_numbers to authenticated;

do $$
declare overflow_count integer; multiple_primary_count integer;
begin
  select count(*) into overflow_count from (
    select business_id from public.business_contact_numbers
    where deleted_at is null group by business_id having count(*) > 5
  ) q;
  if overflow_count <> 0 then
    raise exception 'Phase 17A.1 invariant failed: business with more than 5 contacts.';
  end if;

  select count(*) into multiple_primary_count from (
    select business_id from public.business_contact_numbers
    where deleted_at is null and is_primary = true
    group by business_id having count(*) > 1
  ) q;
  if multiple_primary_count <> 0 then
    raise exception 'Phase 17A.1 invariant failed: business with multiple primary contacts.';
  end if;
end;
$$;
