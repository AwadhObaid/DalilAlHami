-- Dalil Al Hami
-- Phase 09A: favorites hardening for local-first + account synchronization

begin;

create table if not exists public.favorites (
  user_id uuid not null references auth.users(id) on delete cascade,
  business_id uuid not null references public.businesses(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, business_id)
);

create index if not exists favorites_business_id_idx
  on public.favorites(business_id);

alter table public.favorites enable row level security;

drop policy if exists favorites_own_all on public.favorites;
drop policy if exists favorites_select_own on public.favorites;
drop policy if exists favorites_insert_own_active on public.favorites;
drop policy if exists favorites_update_own_active on public.favorites;
drop policy if exists favorites_delete_own_active on public.favorites;

create policy favorites_select_own
on public.favorites
for select
to authenticated
using (user_id = (select auth.uid()));

create policy favorites_insert_own_active
on public.favorites
for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and public.is_active_account()
  and exists (
    select 1
    from public.businesses business
    where business.id = favorites.business_id
      and business.status = 'approved'
      and business.is_active = true
      and business.deleted_at is null
  )
);

create policy favorites_update_own_active
on public.favorites
for update
to authenticated
using (
  user_id = (select auth.uid())
  and public.is_active_account()
)
with check (
  user_id = (select auth.uid())
  and public.is_active_account()
);

create policy favorites_delete_own_active
on public.favorites
for delete
to authenticated
using (
  user_id = (select auth.uid())
  and public.is_active_account()
);

commit;
