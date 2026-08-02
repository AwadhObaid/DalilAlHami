-- دليل الحامي
-- المرحلة 03A: تأسيس قاعدة البيانات الأساسية وسياسات RLS
-- PostgreSQL / Supabase

begin;

create extension if not exists pgcrypto;

-- =========================================================
-- الجداول
-- =========================================================

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  email text,
  phone text,
  avatar_url text,
  role text not null default 'user'
    check (role in ('user', 'admin')),
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  name_ar text not null unique,
  slug text not null unique,
  icon_name text not null default 'category',
  image_url text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.businesses (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references auth.users(id) on delete set null,
  category_id uuid not null references public.categories(id) on delete restrict,
  name text not null,
  description text not null default '',
  phone text not null,
  whatsapp text not null default '',
  address text not null default 'الحامي',
  latitude numeric(9, 6),
  longitude numeric(9, 6),
  logo_url text,
  cover_url text,
  status text not null default 'draft'
    check (status in ('draft', 'pending', 'approved', 'rejected', 'suspended')),
  rejection_reason text,
  is_featured boolean not null default false,
  is_active boolean not null default true,
  views_count bigint not null default 0 check (views_count >= 0),
  approved_at timestamptz,
  approved_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint businesses_latitude_range
    check (latitude is null or latitude between -90 and 90),
  constraint businesses_longitude_range
    check (longitude is null or longitude between -180 and 180)
);

create table public.business_images (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null
    references public.businesses(id) on delete cascade,
  storage_path text not null,
  alt_text text not null default '',
  sort_order integer not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  unique (business_id, storage_path)
);

create table public.advertisements (
  id uuid primary key default gen_random_uuid(),
  business_id uuid references public.businesses(id) on delete set null,
  title text not null,
  image_path text not null,
  target_url text,
  placement text not null default 'home_top'
    check (placement in ('home_top', 'home_middle', 'category', 'business_list')),
  starts_at timestamptz,
  ends_at timestamptz,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint advertisements_valid_dates
    check (ends_at is null or starts_at is null or ends_at > starts_at)
);

create table public.favorites (
  user_id uuid not null references auth.users(id) on delete cascade,
  business_id uuid not null
    references public.businesses(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, business_id)
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  business_id uuid not null
    references public.businesses(id) on delete cascade,
  reason text not null,
  details text not null default '',
  status text not null default 'pending'
    check (status in ('pending', 'reviewed', 'resolved', 'dismissed')),
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null unique,
  platform text not null
    check (platform in ('android', 'ios', 'web', 'windows')),
  last_used_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now())
);

create table public.app_settings (
  key text primary key,
  value jsonb not null default '{}'::jsonb,
  description text not null default '',
  is_public boolean not null default false,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default timezone('utc', now())
);

-- =========================================================
-- الفهارس
-- =========================================================

create index businesses_owner_id_idx
  on public.businesses(owner_id);

create index businesses_category_id_idx
  on public.businesses(category_id);

create index businesses_public_listing_idx
  on public.businesses(status, is_active, is_featured, created_at desc);

create index businesses_name_search_idx
  on public.businesses using gin (to_tsvector('simple', name));

create index business_images_business_id_idx
  on public.business_images(business_id, sort_order);

create index advertisements_active_dates_idx
  on public.advertisements(is_active, starts_at, ends_at, sort_order);

create index favorites_business_id_idx
  on public.favorites(business_id);

create index reports_business_id_idx
  on public.reports(business_id, status);

create index device_tokens_user_id_idx
  on public.device_tokens(user_id);

-- =========================================================
-- الدوال والمشغلات
-- =========================================================

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role = 'admin'
      and is_active = true
  );
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (
    id,
    full_name,
    email,
    phone
  )
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    new.email,
    new.phone
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

create or replace function public.protect_profile_admin_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    new.id = old.id;
    new.role = old.role;
    new.is_active = old.is_active;
  end if;

  return new;
end;
$$;

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

  if old.status = 'approved' and content_changed then
    new.status = 'pending';
    new.rejection_reason = null;
    new.approved_at = null;
    new.approved_by = null;
  end if;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists categories_set_updated_at on public.categories;
create trigger categories_set_updated_at
before update on public.categories
for each row execute function public.set_updated_at();

drop trigger if exists businesses_set_updated_at on public.businesses;
create trigger businesses_set_updated_at
before update on public.businesses
for each row execute function public.set_updated_at();

drop trigger if exists advertisements_set_updated_at on public.advertisements;
create trigger advertisements_set_updated_at
before update on public.advertisements
for each row execute function public.set_updated_at();

drop trigger if exists reports_set_updated_at on public.reports;
create trigger reports_set_updated_at
before update on public.reports
for each row execute function public.set_updated_at();

drop trigger if exists profiles_protect_admin_fields on public.profiles;
create trigger profiles_protect_admin_fields
before update on public.profiles
for each row execute function public.protect_profile_admin_fields();

drop trigger if exists businesses_protect_moderation_fields on public.businesses;
create trigger businesses_protect_moderation_fields
before insert or update on public.businesses
for each row execute function public.protect_business_moderation_fields();

-- =========================================================
-- Row Level Security
-- =========================================================

alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.businesses enable row level security;
alter table public.business_images enable row level security;
alter table public.advertisements enable row level security;
alter table public.favorites enable row level security;
alter table public.reports enable row level security;
alter table public.device_tokens enable row level security;
alter table public.app_settings enable row level security;

-- Profiles
create policy profiles_select_own_or_admin
on public.profiles
for select
to authenticated
using (
  id = (select auth.uid())
  or public.is_admin()
);

create policy profiles_insert_own
on public.profiles
for insert
to authenticated
with check (id = (select auth.uid()));

create policy profiles_update_own_or_admin
on public.profiles
for update
to authenticated
using (
  id = (select auth.uid())
  or public.is_admin()
)
with check (
  id = (select auth.uid())
  or public.is_admin()
);

create policy profiles_admin_delete
on public.profiles
for delete
to authenticated
using (public.is_admin());

-- Categories
create policy categories_public_select
on public.categories
for select
to anon, authenticated
using (is_active = true or public.is_admin());

create policy categories_admin_all
on public.categories
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- Businesses
create policy businesses_public_select
on public.businesses
for select
to anon, authenticated
using (
  (status = 'approved' and is_active = true)
  or owner_id = (select auth.uid())
  or public.is_admin()
);

create policy businesses_owner_insert
on public.businesses
for insert
to authenticated
with check (
  owner_id = (select auth.uid())
  and status in ('draft', 'pending')
);

create policy businesses_owner_update
on public.businesses
for update
to authenticated
using (
  owner_id = (select auth.uid())
  or public.is_admin()
)
with check (
  owner_id = (select auth.uid())
  or public.is_admin()
);

create policy businesses_owner_delete
on public.businesses
for delete
to authenticated
using (
  owner_id = (select auth.uid())
  or public.is_admin()
);

-- Business images
create policy business_images_select
on public.business_images
for select
to anon, authenticated
using (
  exists (
    select 1
    from public.businesses b
    where b.id = business_images.business_id
      and (
        (b.status = 'approved' and b.is_active = true)
        or b.owner_id = (select auth.uid())
        or public.is_admin()
      )
  )
);

create policy business_images_owner_insert
on public.business_images
for insert
to authenticated
with check (
  exists (
    select 1
    from public.businesses b
    where b.id = business_images.business_id
      and (
        b.owner_id = (select auth.uid())
        or public.is_admin()
      )
  )
);

create policy business_images_owner_update
on public.business_images
for update
to authenticated
using (
  exists (
    select 1
    from public.businesses b
    where b.id = business_images.business_id
      and (
        b.owner_id = (select auth.uid())
        or public.is_admin()
      )
  )
)
with check (
  exists (
    select 1
    from public.businesses b
    where b.id = business_images.business_id
      and (
        b.owner_id = (select auth.uid())
        or public.is_admin()
      )
  )
);

create policy business_images_owner_delete
on public.business_images
for delete
to authenticated
using (
  exists (
    select 1
    from public.businesses b
    where b.id = business_images.business_id
      and (
        b.owner_id = (select auth.uid())
        or public.is_admin()
      )
  )
);

-- Advertisements
create policy advertisements_public_select
on public.advertisements
for select
to anon, authenticated
using (
  is_active = true
  and (starts_at is null or starts_at <= timezone('utc', now()))
  and (ends_at is null or ends_at > timezone('utc', now()))
);

create policy advertisements_admin_all
on public.advertisements
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- Favorites
create policy favorites_own_all
on public.favorites
for all
to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

-- Reports
create policy reports_insert_own
on public.reports
for insert
to authenticated
with check (reporter_id = (select auth.uid()));

create policy reports_select_own_or_admin
on public.reports
for select
to authenticated
using (
  reporter_id = (select auth.uid())
  or public.is_admin()
);

create policy reports_admin_update
on public.reports
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy reports_admin_delete
on public.reports
for delete
to authenticated
using (public.is_admin());

-- Device tokens
create policy device_tokens_own_all
on public.device_tokens
for all
to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

-- Application settings
create policy app_settings_public_select
on public.app_settings
for select
to anon, authenticated
using (is_public = true or public.is_admin());

create policy app_settings_admin_all
on public.app_settings
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- =========================================================
-- البيانات الأولية
-- =========================================================

insert into public.categories (
  name_ar,
  slug,
  icon_name,
  sort_order
)
values
  ('طوارئ', 'emergency', 'emergency', 10),
  ('صيدليات', 'pharmacies', 'local_pharmacy', 20),
  ('عيادات', 'clinics', 'medical_services', 30),
  ('مطاعم', 'restaurants', 'restaurant', 40),
  ('مطابخ', 'kitchens', 'soup_kitchen', 50),
  ('بوفيات', 'buffets', 'fastfood', 60),
  ('محلات جملة', 'wholesale-shops', 'inventory', 70),
  ('صيد/أدوات بحر', 'fishing-marine-tools', 'phishing', 80),
  ('إلكترونيات', 'electronics', 'devices', 90),
  ('مواد بناء', 'building-materials', 'home_repair_service', 100),
  ('بقالات', 'groceries', 'storefront', 110),
  ('محطات', 'fuel-stations', 'local_gas_station', 120),
  ('أعمال أخرى', 'other-services', 'groups', 130),
  ('صوالين', 'salons', 'content_cut', 140),
  ('ورش متنوعة', 'workshops', 'build', 150),
  ('مغاسل متنوعة', 'laundries', 'local_laundry_service', 160),
  ('معدات عمل', 'work-equipment', 'engineering', 170),
  ('بوز ماء', 'water-tankers', 'water_drop', 180),
  ('سيارات نقل', 'transport-trucks', 'local_shipping', 190),
  ('تكاتك', 'tuk-tuks', 'electric_rickshaw', 200),
  ('سيارات نوها', 'noha-vehicles', 'airport_shuttle', 210),
  ('تكاسي', 'taxis', 'local_taxi', 220),
  ('دراجات توصيل', 'delivery-motorcycles', 'motorcycle', 230)
on conflict (slug) do update
set
  name_ar = excluded.name_ar,
  icon_name = excluded.icon_name,
  sort_order = excluded.sort_order,
  is_active = true;

insert into public.app_settings (
  key,
  value,
  description,
  is_public
)
values
  (
    'directory',
    jsonb_build_object(
      'app_name', 'دليل الحامي',
      'city_name', 'الحامي',
      'allow_business_submissions', true,
      'maximum_business_images', 5
    ),
    'الإعدادات العامة العامة للتطبيق',
    true
  )
on conflict (key) do update
set
  value = excluded.value,
  description = excluded.description,
  is_public = excluded.is_public,
  updated_at = timezone('utc', now());

commit;
