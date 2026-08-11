-- Dalil Al Hami
-- Phase 14B: per-user notification dismissal and admin-history cleanup
--
-- Safety contract:
-- 1) A user's "delete" action only records a per-user dismissal.
-- 2) Admin history cleanup only sets app_notifications.admin_hidden_at.
-- 3) Neither action hard-deletes app_notifications rows, so already-delivered
--    notifications remain available to other users.

begin;

alter table public.app_notifications
  add column if not exists admin_hidden_at timestamptz;

create index if not exists app_notifications_admin_visible_created_idx
  on public.app_notifications(created_at desc)
  where admin_hidden_at is null;

create table if not exists public.app_notification_dismissals (
  notification_id uuid not null references public.app_notifications(id)
    on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  dismissed_at timestamptz not null default timezone('utc', now()),
  primary key (notification_id, user_id)
);

create index if not exists app_notification_dismissals_user_idx
  on public.app_notification_dismissals(user_id, dismissed_at desc);

alter table public.app_notification_dismissals enable row level security;

revoke all on public.app_notification_dismissals
  from public, anon, authenticated;
grant all on public.app_notification_dismissals to service_role;

create or replace function public.list_my_notifications(
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  id uuid,
  title text,
  body text,
  target_type text,
  navigation_type text,
  business_id uuid,
  data jsonb,
  created_at timestamptz,
  is_read boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_limit integer := least(100, greatest(1, coalesce(p_limit, 50)));
  v_offset integer := greatest(0, coalesce(p_offset, 0));
begin
  if v_user_id is null then
    raise exception 'Authentication is required.' using errcode = '42501';
  end if;

  if not public.is_active_account() then
    raise exception 'The authenticated account is suspended or deleted.'
      using errcode = '42501';
  end if;

  return query
  select
    n.id,
    n.title,
    n.body,
    n.target_type,
    n.navigation_type,
    n.business_id,
    n.data,
    n.created_at,
    (r.notification_id is not null) as is_read
  from public.app_notifications n
  left join public.app_notification_reads r
    on r.notification_id = n.id
   and r.user_id = v_user_id
  where
    (
      n.target_type = 'public'
      or (n.target_type = 'user' and n.target_user_id = v_user_id)
    )
    and not exists (
      select 1
      from public.app_notification_dismissals d
      where d.notification_id = n.id
        and d.user_id = v_user_id
    )
  order by n.created_at desc
  limit v_limit
  offset v_offset;
end;
$$;

revoke all on function public.list_my_notifications(integer, integer)
  from public, anon;
grant execute on function public.list_my_notifications(integer, integer)
  to authenticated, service_role;

create or replace function public.my_notification_unread_count()
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_count bigint;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.' using errcode = '42501';
  end if;

  if not public.is_active_account() then
    return 0;
  end if;

  select count(*)
  into v_count
  from public.app_notifications n
  where
    (
      n.target_type = 'public'
      or (n.target_type = 'user' and n.target_user_id = v_user_id)
    )
    and not exists (
      select 1
      from public.app_notification_reads r
      where r.notification_id = n.id
        and r.user_id = v_user_id
    )
    and not exists (
      select 1
      from public.app_notification_dismissals d
      where d.notification_id = n.id
        and d.user_id = v_user_id
    );

  return coalesce(v_count, 0);
end;
$$;

revoke all on function public.my_notification_unread_count()
  from public, anon;
grant execute on function public.my_notification_unread_count()
  to authenticated, service_role;

create or replace function public.mark_my_notification_read(
  p_notification_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_visible boolean;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.' using errcode = '42501';
  end if;

  select exists (
    select 1
    from public.app_notifications n
    where n.id = p_notification_id
      and (
        n.target_type = 'public'
        or (n.target_type = 'user' and n.target_user_id = v_user_id)
      )
      and not exists (
        select 1
        from public.app_notification_dismissals d
        where d.notification_id = n.id
          and d.user_id = v_user_id
      )
  ) into v_visible;

  if not v_visible then
    return false;
  end if;

  insert into public.app_notification_reads (
    notification_id,
    user_id,
    read_at
  ) values (
    p_notification_id,
    v_user_id,
    timezone('utc', now())
  )
  on conflict (notification_id, user_id) do update
  set read_at = excluded.read_at;

  return true;
end;
$$;

revoke all on function public.mark_my_notification_read(uuid)
  from public, anon;
grant execute on function public.mark_my_notification_read(uuid)
  to authenticated, service_role;

create or replace function public.mark_all_my_notifications_read()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_changed integer := 0;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.' using errcode = '42501';
  end if;

  insert into public.app_notification_reads (
    notification_id,
    user_id,
    read_at
  )
  select
    n.id,
    v_user_id,
    timezone('utc', now())
  from public.app_notifications n
  where
    (
      n.target_type = 'public'
      or (n.target_type = 'user' and n.target_user_id = v_user_id)
    )
    and not exists (
      select 1
      from public.app_notification_dismissals d
      where d.notification_id = n.id
        and d.user_id = v_user_id
    )
  on conflict (notification_id, user_id) do nothing;

  get diagnostics v_changed = row_count;
  return v_changed;
end;
$$;

revoke all on function public.mark_all_my_notifications_read()
  from public, anon;
grant execute on function public.mark_all_my_notifications_read()
  to authenticated, service_role;

create or replace function public.dismiss_my_notification(
  p_notification_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_visible boolean;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.' using errcode = '42501';
  end if;

  if not public.is_active_account() then
    raise exception 'The authenticated account is suspended or deleted.'
      using errcode = '42501';
  end if;

  select exists (
    select 1
    from public.app_notifications n
    where n.id = p_notification_id
      and (
        n.target_type = 'public'
        or (n.target_type = 'user' and n.target_user_id = v_user_id)
      )
  ) into v_visible;

  if not v_visible then
    return false;
  end if;

  insert into public.app_notification_dismissals (
    notification_id,
    user_id,
    dismissed_at
  ) values (
    p_notification_id,
    v_user_id,
    timezone('utc', now())
  )
  on conflict (notification_id, user_id) do update
  set dismissed_at = excluded.dismissed_at;

  return true;
end;
$$;

revoke all on function public.dismiss_my_notification(uuid)
  from public, anon;
grant execute on function public.dismiss_my_notification(uuid)
  to authenticated, service_role;

create or replace function public.dismiss_my_notifications(
  p_notification_ids uuid[]
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_changed integer := 0;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.' using errcode = '42501';
  end if;

  if not public.is_active_account() then
    raise exception 'The authenticated account is suspended or deleted.'
      using errcode = '42501';
  end if;

  with requested as (
    select distinct unnest(
      coalesce(p_notification_ids, array[]::uuid[])
    ) as notification_id
  )
  insert into public.app_notification_dismissals (
    notification_id,
    user_id,
    dismissed_at
  )
  select
    n.id,
    v_user_id,
    timezone('utc', now())
  from requested q
  join public.app_notifications n
    on n.id = q.notification_id
  where
    n.target_type = 'public'
    or (n.target_type = 'user' and n.target_user_id = v_user_id)
  on conflict (notification_id, user_id) do nothing;

  get diagnostics v_changed = row_count;
  return v_changed;
end;
$$;

revoke all on function public.dismiss_my_notifications(uuid[])
  from public, anon;
grant execute on function public.dismiss_my_notifications(uuid[])
  to authenticated, service_role;

create or replace function public.dismiss_all_my_notifications()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_changed integer := 0;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.' using errcode = '42501';
  end if;

  if not public.is_active_account() then
    raise exception 'The authenticated account is suspended or deleted.'
      using errcode = '42501';
  end if;

  insert into public.app_notification_dismissals (
    notification_id,
    user_id,
    dismissed_at
  )
  select
    n.id,
    v_user_id,
    timezone('utc', now())
  from public.app_notifications n
  where
    n.target_type = 'public'
    or (n.target_type = 'user' and n.target_user_id = v_user_id)
  on conflict (notification_id, user_id) do nothing;

  get diagnostics v_changed = row_count;
  return v_changed;
end;
$$;

revoke all on function public.dismiss_all_my_notifications()
  from public, anon;
grant execute on function public.dismiss_all_my_notifications()
  to authenticated, service_role;

comment on column public.app_notifications.admin_hidden_at is
  'Admin-dashboard history visibility only. Does not remove notification delivery/inbox visibility.';

comment on table public.app_notification_dismissals is
  'Per-user dismissal state. A row hides one notification only for one user.';

commit;
