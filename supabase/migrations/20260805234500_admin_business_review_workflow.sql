-- Dalil Al Hami
-- Phase 07B: administrator business review workflow and audit log

begin;

-- Add a distinct state for requests that need owner corrections.
alter table public.businesses
  drop constraint if exists businesses_status_check;

alter table public.businesses
  add constraint businesses_status_check
  check (
    status in (
      'draft',
      'pending',
      'approved',
      'rejected',
      'changes_requested',
      'suspended'
    )
  );

-- Let owners resubmit rejected or change-requested records without
-- carrying the previous moderation reason into the new pending request.
create or replace function public.protect_business_moderation_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_is_admin boolean := public.is_admin();
  content_changed boolean := false;
begin
  if current_user_is_admin then
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.owner_id = (select auth.uid());

    if new.status not in ('draft', 'pending') then
      new.status = 'draft';
    end if;

    new.rejection_reason = null;
    new.is_featured = false;
    new.is_active = true;
    new.approved_at = null;
    new.approved_by = null;

    return new;
  end if;

  new.owner_id = old.owner_id;
  new.rejection_reason = old.rejection_reason;
  new.is_featured = old.is_featured;
  new.is_active = old.is_active;
  new.approved_at = old.approved_at;
  new.approved_by = old.approved_by;

  content_changed :=
       new.category_id is distinct from old.category_id
    or new.name is distinct from old.name
    or new.description is distinct from old.description
    or new.phone is distinct from old.phone
    or new.whatsapp is distinct from old.whatsapp
    or new.address is distinct from old.address
    or new.latitude is distinct from old.latitude
    or new.longitude is distinct from old.longitude
    or new.logo_url is distinct from old.logo_url
    or new.cover_url is distinct from old.cover_url;

  if new.status not in ('draft', 'pending') then
    new.status = old.status;
  end if;

  if new.status = 'pending'
     and old.status in ('rejected', 'changes_requested') then
    new.rejection_reason = null;
    new.is_active = true;
    new.approved_at = null;
    new.approved_by = null;
  end if;

  if old.status = 'approved' and content_changed then
    new.status = 'pending';
    new.rejection_reason = null;
    new.approved_at = null;
    new.approved_by = null;
  end if;

  return new;
end;
$$;

create table if not exists public.business_reviews (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null
    references public.businesses(id) on delete cascade,
  reviewer_id uuid references auth.users(id) on delete set null,
  action text not null
    check (action in ('approved', 'rejected', 'changes_requested')),
  reason text,
  previous_status text not null,
  resulting_status text not null,
  created_at timestamptz not null default timezone('utc', now()),
  constraint business_reviews_reason_required
    check (
      action = 'approved'
      or length(btrim(coalesce(reason, ''))) >= 5
    )
);

create index if not exists business_reviews_business_created_idx
  on public.business_reviews(business_id, created_at desc);

create index if not exists business_reviews_reviewer_created_idx
  on public.business_reviews(reviewer_id, created_at desc);

alter table public.business_reviews enable row level security;

drop policy if exists business_reviews_admin_select
  on public.business_reviews;
create policy business_reviews_admin_select
on public.business_reviews
for select
to authenticated
using (public.is_admin());

drop policy if exists business_reviews_owner_select
  on public.business_reviews;
create policy business_reviews_owner_select
on public.business_reviews
for select
to authenticated
using (
  exists (
    select 1
    from public.businesses business
    where business.id = business_reviews.business_id
      and business.owner_id = (select auth.uid())
  )
);

drop policy if exists business_reviews_admin_insert
  on public.business_reviews;
create policy business_reviews_admin_insert
on public.business_reviews
for insert
to authenticated
with check (
  public.is_admin()
  and reviewer_id = (select auth.uid())
);

grant select, insert on public.business_reviews to authenticated;

create or replace function public.admin_review_business(
  p_business_id uuid,
  p_decision text,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_business public.businesses%rowtype;
  v_previous_status text;
  v_resulting_status text;
  v_action text;
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_reviewed_at timestamptz := timezone('utc', now());
begin
  if not public.is_admin() then
    raise exception 'Administrator access is required.'
      using errcode = '42501';
  end if;

  if p_decision not in ('approve', 'reject', 'request_changes') then
    raise exception 'Invalid review decision.'
      using errcode = '22023';
  end if;

  if p_decision in ('reject', 'request_changes')
     and length(coalesce(v_reason, '')) < 5 then
    raise exception 'A review reason of at least five characters is required.'
      using errcode = '22023';
  end if;

  select business.*
  into v_business
  from public.businesses business
  where business.id = p_business_id
  for update;

  if not found then
    raise exception 'Business was not found.'
      using errcode = 'P0002';
  end if;

  if v_business.status <> 'pending' then
    raise exception 'Only pending businesses can be reviewed.'
      using errcode = '22023';
  end if;

  v_previous_status := v_business.status;

  if p_decision = 'approve' then
    v_action := 'approved';
    v_resulting_status := 'approved';

    update public.businesses business
    set
      status = 'approved',
      rejection_reason = null,
      is_active = true,
      approved_at = v_reviewed_at,
      approved_by = (select auth.uid())
    where business.id = p_business_id
    returning business.* into v_business;
  elsif p_decision = 'reject' then
    v_action := 'rejected';
    v_resulting_status := 'rejected';

    update public.businesses business
    set
      status = 'rejected',
      rejection_reason = v_reason,
      is_active = false,
      approved_at = null,
      approved_by = null
    where business.id = p_business_id
    returning business.* into v_business;
  else
    v_action := 'changes_requested';
    v_resulting_status := 'changes_requested';

    update public.businesses business
    set
      status = 'changes_requested',
      rejection_reason = v_reason,
      is_active = false,
      approved_at = null,
      approved_by = null
    where business.id = p_business_id
    returning business.* into v_business;
  end if;

  insert into public.business_reviews (
    business_id,
    reviewer_id,
    action,
    reason,
    previous_status,
    resulting_status,
    created_at
  )
  values (
    p_business_id,
    (select auth.uid()),
    v_action,
    v_reason,
    v_previous_status,
    v_resulting_status,
    v_reviewed_at
  );

  return jsonb_build_object(
    'business_id', p_business_id,
    'previous_status', v_previous_status,
    'resulting_status', v_resulting_status,
    'decision', v_action,
    'reason', v_reason,
    'reviewed_at', v_reviewed_at
  );
end;
$$;

revoke all on function public.admin_review_business(uuid, text, text)
  from public;
grant execute on function public.admin_review_business(uuid, text, text)
  to authenticated;

comment on table public.business_reviews is
  'Immutable audit log for administrator decisions on business submissions.';
comment on function public.admin_review_business(uuid, text, text) is
  'Atomically reviews one pending business and records the administrator decision.';

commit;
