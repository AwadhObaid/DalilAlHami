-- Dalil Al Hami
-- Phase 10A: Firebase Cloud Messaging device-token foundation

begin;

create table if not exists public.push_notification_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  fcm_token text not null unique,
  platform text not null default 'android' check (
    platform in ('android', 'ios', 'macos', 'web', 'windows', 'linux', 'fuchsia')
  ),
  enabled boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  last_seen_at timestamptz not null default timezone('utc', now()),
  constraint push_notification_devices_token_nonempty check (
    char_length(btrim(fcm_token)) >= 20
  )
);

create index if not exists push_notification_devices_user_enabled_idx
  on public.push_notification_devices(user_id, enabled);
create index if not exists push_notification_devices_last_seen_idx
  on public.push_notification_devices(last_seen_at desc);

alter table public.push_notification_devices enable row level security;

revoke all on public.push_notification_devices from public, anon, authenticated;
grant all on public.push_notification_devices to service_role;

create or replace function public.disable_push_devices_for_inactive_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.is_active is distinct from true or new.deleted_at is not null then
    update public.push_notification_devices
    set
      enabled = false,
      updated_at = timezone('utc', now())
    where user_id = new.id
      and enabled = true;
  end if;

  return new;
end;
$$;

revoke all on function public.disable_push_devices_for_inactive_profile()
  from public, anon, authenticated;
grant execute on function public.disable_push_devices_for_inactive_profile()
  to service_role;

drop trigger if exists profiles_disable_push_devices_when_inactive
  on public.profiles;
create trigger profiles_disable_push_devices_when_inactive
after update of is_active, deleted_at on public.profiles
for each row execute function public.disable_push_devices_for_inactive_profile();

create or replace function public.register_push_device(
  p_fcm_token text,
  p_platform text default 'android'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_token text := btrim(coalesce(p_fcm_token, ''));
  v_platform text := lower(btrim(coalesce(p_platform, 'android')));
  v_device_id uuid;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.' using errcode = '42501';
  end if;

  if not public.is_active_account() then
    raise exception 'The authenticated account is suspended or deleted.'
      using errcode = '42501';
  end if;

  if char_length(v_token) < 20 then
    raise exception 'A valid FCM token is required.' using errcode = '22023';
  end if;

  if v_platform not in (
    'android', 'ios', 'macos', 'web', 'windows', 'linux', 'fuchsia'
  ) then
    raise exception 'Unsupported push platform.' using errcode = '22023';
  end if;

  insert into public.push_notification_devices (
    user_id,
    fcm_token,
    platform,
    enabled,
    updated_at,
    last_seen_at
  )
  values (
    v_user_id,
    v_token,
    v_platform,
    true,
    timezone('utc', now()),
    timezone('utc', now())
  )
  on conflict (fcm_token) do update
  set
    user_id = excluded.user_id,
    platform = excluded.platform,
    enabled = true,
    updated_at = timezone('utc', now()),
    last_seen_at = timezone('utc', now())
  returning id into v_device_id;

  return v_device_id;
end;
$$;

revoke all on function public.register_push_device(text, text)
  from public, anon;
grant execute on function public.register_push_device(text, text)
  to authenticated, service_role;

create or replace function public.unregister_push_device(
  p_fcm_token text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_token text := btrim(coalesce(p_fcm_token, ''));
  v_deleted integer;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.' using errcode = '42501';
  end if;

  delete from public.push_notification_devices
  where user_id = v_user_id
    and fcm_token = v_token;

  get diagnostics v_deleted = row_count;
  return v_deleted > 0;
end;
$$;

revoke all on function public.unregister_push_device(text)
  from public, anon;
grant execute on function public.unregister_push_device(text)
  to authenticated, service_role;

commit;
