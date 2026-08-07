-- Dalil Al Hami
-- Phase 10B: in-app notification center and secure administrator sending

begin;

create table if not exists public.app_notifications (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  target_type text not null default 'public' check (
    target_type in ('public', 'user')
  ),
  target_user_id uuid references public.profiles(id) on delete cascade,
  navigation_type text not null default 'notifications' check (
    navigation_type in (
      'notifications', 'home', 'categories', 'search', 'account', 'business'
    )
  ),
  business_id uuid references public.businesses(id) on delete set null,
  data jsonb not null default '{}'::jsonb,
  created_by uuid references public.profiles(id) on delete set null,
  delivery_status text not null default 'pending' check (
    delivery_status in ('pending', 'sent', 'partial', 'failed', 'no_devices')
  ),
  delivery_attempt_count integer not null default 0 check (
    delivery_attempt_count >= 0
  ),
  delivery_success_count integer not null default 0 check (
    delivery_success_count >= 0
  ),
  error_message text,
  created_at timestamptz not null default timezone('utc', now()),
  sent_at timestamptz,
  constraint app_notifications_title_nonempty check (
    char_length(btrim(title)) between 2 and 120
  ),
  constraint app_notifications_body_nonempty check (
    char_length(btrim(body)) between 1 and 600
  ),
  constraint app_notifications_target_consistency check (
    (target_type = 'public' and target_user_id is null)
    or
    (target_type = 'user' and target_user_id is not null)
  )
);

create index if not exists app_notifications_created_at_idx
  on public.app_notifications(created_at desc);
create index if not exists app_notifications_target_user_idx
  on public.app_notifications(target_user_id, created_at desc)
  where target_type = 'user';
create index if not exists app_notifications_target_type_idx
  on public.app_notifications(target_type, created_at desc);

create table if not exists public.app_notification_reads (
  notification_id uuid not null references public.app_notifications(id)
    on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  read_at timestamptz not null default timezone('utc', now()),
  primary key (notification_id, user_id)
);

create index if not exists app_notification_reads_user_idx
  on public.app_notification_reads(user_id, read_at desc);

alter table public.app_notifications enable row level security;
alter table public.app_notification_reads enable row level security;

revoke all on public.app_notifications from public, anon, authenticated;
revoke all on public.app_notification_reads from public, anon, authenticated;
grant all on public.app_notifications to service_role;
grant all on public.app_notification_reads to service_role;

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
    n.target_type = 'public'
    or (n.target_type = 'user' and n.target_user_id = v_user_id)
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
    n.target_type = 'public'
    or (n.target_type = 'user' and n.target_user_id = v_user_id)
  on conflict (notification_id, user_id) do nothing;

  get diagnostics v_changed = row_count;
  return v_changed;
end;
$$;

revoke all on function public.mark_all_my_notifications_read()
  from public, anon;
grant execute on function public.mark_all_my_notifications_read()
  to authenticated, service_role;

comment on table public.app_notifications is
  'Phase 10B durable notification records for public and user-targeted messages.';
comment on table public.app_notification_reads is
  'Per-user read state for the in-app notification center.';

commit;
