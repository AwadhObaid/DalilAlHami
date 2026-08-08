-- Dalil Al Hami
-- Phase 09B: public business rating summary + one mutable rating per account

begin;

create table if not exists public.business_ratings (
  user_id uuid not null references auth.users(id) on delete cascade,
  business_id uuid not null references public.businesses(id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, business_id)
);

create index if not exists business_ratings_business_id_idx
  on public.business_ratings(business_id);

alter table public.business_ratings enable row level security;

drop policy if exists business_ratings_select_own on public.business_ratings;
drop policy if exists business_ratings_insert_own_active on public.business_ratings;
drop policy if exists business_ratings_update_own_active on public.business_ratings;
drop policy if exists business_ratings_delete_own_active on public.business_ratings;

create policy business_ratings_select_own
on public.business_ratings
for select
to authenticated
using (user_id = (select auth.uid()));

create policy business_ratings_insert_own_active
on public.business_ratings
for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and public.is_active_account()
  and exists (
    select 1
    from public.businesses business
    where business.id = business_ratings.business_id
      and business.status = 'approved'
      and business.is_active = true
      and business.deleted_at is null
  )
);

create policy business_ratings_update_own_active
on public.business_ratings
for update
to authenticated
using (
  user_id = (select auth.uid())
  and public.is_active_account()
)
with check (
  user_id = (select auth.uid())
  and public.is_active_account()
  and rating between 1 and 5
);

create policy business_ratings_delete_own_active
on public.business_ratings
for delete
to authenticated
using (
  user_id = (select auth.uid())
  and public.is_active_account()
);

revoke all on public.business_ratings from anon;
grant select, insert, update, delete on public.business_ratings to authenticated;

create or replace function public.get_business_rating_summary(
  p_business_id uuid
)
returns table (
  average_rating numeric,
  ratings_count bigint,
  user_rating smallint
)
language sql
stable
security definer
set search_path = public
as $$
  select
    coalesce(round(avg(rating_row.rating)::numeric, 2), 0::numeric)
      as average_rating,
    count(rating_row.rating)::bigint as ratings_count,
    (
      select own_rating.rating
      from public.business_ratings own_rating
      where own_rating.business_id = business.id
        and own_rating.user_id = auth.uid()
      limit 1
    ) as user_rating
  from public.businesses business
  left join public.business_ratings rating_row
    on rating_row.business_id = business.id
  where business.id = p_business_id
    and business.status = 'approved'
    and business.is_active = true
    and business.deleted_at is null
  group by business.id;
$$;

revoke all on function public.get_business_rating_summary(uuid) from public;
grant execute on function public.get_business_rating_summary(uuid) to anon;
grant execute on function public.get_business_rating_summary(uuid) to authenticated;
grant execute on function public.get_business_rating_summary(uuid) to service_role;

create or replace function public.set_business_rating(
  p_business_id uuid,
  p_rating smallint
)
returns table (
  average_rating numeric,
  ratings_count bigint,
  user_rating smallint
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Authentication is required.' using errcode = '42501';
  end if;

  if p_rating is null or p_rating < 1 or p_rating > 5 then
    raise exception 'Rating must be between 1 and 5.' using errcode = '22023';
  end if;

  if not public.is_active_account() then
    raise exception 'The authenticated account is suspended or deleted.'
      using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.businesses business
    where business.id = p_business_id
      and business.status = 'approved'
      and business.is_active = true
      and business.deleted_at is null
  ) then
    raise exception 'The business is not available for rating.'
      using errcode = '22023';
  end if;

  insert into public.business_ratings (
    user_id,
    business_id,
    rating
  ) values (
    v_user_id,
    p_business_id,
    p_rating
  )
  on conflict (user_id, business_id)
  do update set
    rating = excluded.rating,
    updated_at = timezone('utc', now());

  return query
  select
    coalesce(round(avg(rating_row.rating)::numeric, 2), 0::numeric),
    count(rating_row.rating)::bigint,
    p_rating
  from public.business_ratings rating_row
  where rating_row.business_id = p_business_id;
end;
$$;

revoke all on function public.set_business_rating(uuid, smallint) from public, anon;
grant execute on function public.set_business_rating(uuid, smallint) to authenticated;
grant execute on function public.set_business_rating(uuid, smallint) to service_role;

commit;
