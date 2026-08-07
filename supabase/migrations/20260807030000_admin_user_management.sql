-- Dalil Al Hami
-- Phase 08C: secure administrator user management and audit trail

begin;

alter table public.profiles
  add column if not exists created_at timestamptz,
  add column if not exists updated_at timestamptz,
  add column if not exists suspended_at timestamptz,
  add column if not exists suspension_reason text,
  add column if not exists deleted_at timestamptz;

update public.profiles profile
set
  email = coalesce(
    nullif(btrim(profile.email), ''),
    auth_user.email,
    profile.email
  ),
  phone = coalesce(
    nullif(btrim(profile.phone), ''),
    auth_user.phone,
    profile.phone
  ),
  created_at = coalesce(
    profile.created_at,
    auth_user.created_at,
    timezone('utc', now())
  ),
  updated_at = coalesce(
    profile.updated_at,
    auth_user.updated_at,
    auth_user.created_at,
    timezone('utc', now())
  )
from auth.users auth_user
where auth_user.id = profile.id;

update public.profiles
set
  created_at = coalesce(created_at, timezone('utc', now())),
  updated_at = coalesce(updated_at, timezone('utc', now()));

alter table public.profiles
  alter column created_at set default timezone('utc', now()),
  alter column created_at set not null,
  alter column updated_at set default timezone('utc', now()),
  alter column updated_at set not null;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles profile
    where profile.id = auth.uid()
      and profile.role = 'admin'
      and profile.is_active = true
      and profile.deleted_at is null
  );
$$;

revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.is_admin() to service_role;

create or replace function public.is_active_account()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles profile
    where profile.id = auth.uid()
      and profile.is_active = true
      and profile.deleted_at is null
  );
$$;

revoke all on function public.is_active_account() from public, anon;
grant execute on function public.is_active_account() to authenticated;
grant execute on function public.is_active_account() to service_role;

create or replace function public.enforce_active_account_mutation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null and not public.is_active_account() then
    raise exception 'The authenticated account is suspended or deleted.'
      using errcode = '42501';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

revoke all on function public.enforce_active_account_mutation()
  from public, anon, authenticated;
grant execute on function public.enforce_active_account_mutation()
  to service_role;

drop trigger if exists profiles_active_account_update_guard
  on public.profiles;
create trigger profiles_active_account_update_guard
before update on public.profiles
for each row execute function public.enforce_active_account_mutation();

drop trigger if exists businesses_active_account_write_guard
  on public.businesses;
create trigger businesses_active_account_write_guard
before insert or update or delete on public.businesses
for each row execute function public.enforce_active_account_mutation();

drop trigger if exists business_images_active_account_write_guard
  on public.business_images;
create trigger business_images_active_account_write_guard
before insert or update or delete on public.business_images
for each row execute function public.enforce_active_account_mutation();

drop policy if exists storage_active_account_access_guard
  on storage.objects;
create policy storage_active_account_access_guard
on storage.objects
as restrictive
for all
to authenticated
using (public.is_active_account())
with check (public.is_active_account());

create or replace function public.touch_profile_management_row()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists profiles_touch_management_updated_at
  on public.profiles;
create trigger profiles_touch_management_updated_at
before update on public.profiles
for each row execute function public.touch_profile_management_row();

create table if not exists public.admin_user_actions (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references auth.users(id) on delete set null,
  target_user_id uuid not null references auth.users(id) on delete cascade,
  action text not null check (
    action in (
      'suspended', 'activated', 'promoted', 'demoted',
      'soft_deleted', 'restored'
    )
  ),
  reason text,
  before_data jsonb,
  after_data jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists admin_user_actions_target_created_idx
  on public.admin_user_actions(target_user_id, created_at desc);
create index if not exists admin_user_actions_actor_created_idx
  on public.admin_user_actions(actor_id, created_at desc);

alter table public.admin_user_actions enable row level security;

drop policy if exists admin_user_actions_admin_select
  on public.admin_user_actions;
create policy admin_user_actions_admin_select
on public.admin_user_actions
for select
to authenticated
using (
  exists (
    select 1
    from public.profiles profile
    where profile.id = auth.uid()
      and profile.role = 'admin'
      and profile.is_active = true
      and profile.deleted_at is null
  )
);

revoke all on public.admin_user_actions from anon, authenticated;
grant select on public.admin_user_actions to authenticated;
grant all on public.admin_user_actions to service_role;

create or replace function public.admin_apply_user_change(
  p_actor_id uuid,
  p_target_user_id uuid,
  p_action text,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor public.profiles%rowtype;
  v_target public.profiles%rowtype;
  v_before jsonb;
  v_after jsonb;
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_active_admin_count integer;
  v_message text;
begin
  select profile.*
  into v_actor
  from public.profiles profile
  where profile.id = p_actor_id
  for update;

  if not found
     or v_actor.role <> 'admin'
     or v_actor.is_active is distinct from true
     or v_actor.deleted_at is not null then
    raise exception 'Administrator access is required.'
      using errcode = '42501';
  end if;

  if p_actor_id = p_target_user_id then
    raise exception 'Administrators cannot change their own role or status.'
      using errcode = '22023';
  end if;

  perform profile.id
  from public.profiles profile
  where profile.role = 'admin'
    and profile.is_active = true
    and profile.deleted_at is null
  order by profile.id
  for update;

  select profile.*
  into v_target
  from public.profiles profile
  where profile.id = p_target_user_id
  for update;

  if not found then
    raise exception 'User profile was not found.' using errcode = 'P0002';
  end if;

  if p_action not in (
    'suspend', 'activate', 'promote', 'demote', 'soft_delete', 'restore'
  ) then
    raise exception 'Invalid user management action.' using errcode = '22023';
  end if;

  if p_action in ('suspend', 'soft_delete')
     and length(coalesce(v_reason, '')) < 5 then
    raise exception 'A suspension reason of at least five characters is required.'
      using errcode = '22023';
  end if;

  if v_target.role = 'admin'
     and v_target.is_active = true
     and p_action in ('suspend', 'demote', 'soft_delete') then
    select count(*)
    into v_active_admin_count
    from public.profiles profile
    where profile.role = 'admin'
      and profile.is_active = true
      and profile.deleted_at is null;

    if v_active_admin_count <= 1 then
      raise exception 'The last active administrator cannot be changed.'
        using errcode = '23514';
    end if;
  end if;

  v_before := to_jsonb(v_target);

  if p_action = 'suspend' then
    update public.profiles profile
    set
      is_active = false,
      suspended_at = timezone('utc', now()),
      suspension_reason = v_reason
    where profile.id = p_target_user_id
    returning profile.* into v_target;
    v_message := 'تم إيقاف الحساب.';
  elsif p_action = 'activate' then
    if v_target.deleted_at is not null then
      raise exception 'Restore a soft-deleted account before activation.'
        using errcode = '23514';
    end if;
    update public.profiles profile
    set
      is_active = true,
      suspended_at = null,
      suspension_reason = null
    where profile.id = p_target_user_id
    returning profile.* into v_target;
    v_message := 'تم تفعيل الحساب.';
  elsif p_action = 'promote' then
    if v_target.deleted_at is not null then
      raise exception 'A soft-deleted account cannot be promoted.'
        using errcode = '23514';
    end if;
    update public.profiles profile
    set role = 'admin'
    where profile.id = p_target_user_id
    returning profile.* into v_target;
    v_message := 'تم منح صلاحية المدير.';
  elsif p_action = 'demote' then
    update public.profiles profile
    set role = 'user'
    where profile.id = p_target_user_id
    returning profile.* into v_target;
    v_message := 'تم إلغاء صلاحية المدير.';
  elsif p_action = 'soft_delete' then
    update public.profiles profile
    set
      is_active = false,
      suspended_at = timezone('utc', now()),
      suspension_reason = v_reason,
      deleted_at = timezone('utc', now())
    where profile.id = p_target_user_id
    returning profile.* into v_target;
    v_message := 'تم حذف الحساب ظاهريًا.';
  else
    update public.profiles profile
    set
      is_active = true,
      suspended_at = null,
      suspension_reason = null,
      deleted_at = null
    where profile.id = p_target_user_id
    returning profile.* into v_target;
    v_message := 'تمت استعادة الحساب.';
  end if;

  v_after := to_jsonb(v_target);

  insert into public.admin_user_actions (
    actor_id,
    target_user_id,
    action,
    reason,
    before_data,
    after_data
  )
  values (
    p_actor_id,
    p_target_user_id,
    case p_action
      when 'suspend' then 'suspended'
      when 'activate' then 'activated'
      when 'promote' then 'promoted'
      when 'demote' then 'demoted'
      when 'soft_delete' then 'soft_deleted'
      else 'restored'
    end,
    v_reason,
    v_before,
    v_after
  );

  return jsonb_build_object(
    'user_id', p_target_user_id,
    'action', case p_action
      when 'suspend' then 'suspended'
      when 'activate' then 'activated'
      when 'promote' then 'promoted'
      when 'demote' then 'demoted'
      when 'soft_delete' then 'soft_deleted'
      else 'restored'
    end,
    'message', v_message,
    'profile', v_after
  );
end;
$$;

revoke all on function public.admin_apply_user_change(
  uuid, uuid, text, text
) from public, anon, authenticated;
grant execute on function public.admin_apply_user_change(
  uuid, uuid, text, text
) to service_role;

comment on table public.admin_user_actions is
  'Administrator audit trail for user status and role changes.';
comment on function public.admin_apply_user_change(
  uuid, uuid, text, text
) is
  'Service-role-only transaction used by the authenticated admin-users Edge Function.';

commit;
