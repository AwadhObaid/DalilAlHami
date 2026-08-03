-- فحص المرحلة 03C – للقراءة فقط

select
  indexname,
  indexdef
from pg_indexes
where schemaname = 'public'
  and indexname = 'businesses_one_per_owner_idx';

select
  grantee,
  table_name,
  privilege_type
from information_schema.role_table_grants
where table_schema = 'public'
  and grantee = 'authenticated'
  and table_name in ('profiles', 'businesses', 'categories')
order by table_name, privilege_type;

select
  trigger_name,
  event_manipulation,
  event_object_schema,
  event_object_table
from information_schema.triggers
where trigger_name = 'on_auth_user_profile_synced'
order by event_manipulation;

select
  (select count(*) from auth.users) as auth_users,
  (select count(*) from public.profiles) as profiles,
  (
    select count(*)
    from public.businesses
    where owner_id is not null
  ) as owned_businesses;

select
  p.id,
  p.full_name,
  p.phone,
  p.role,
  b.name as business_name,
  b.status as business_status,
  c.name_ar as category_name
from public.profiles p
left join public.businesses b on b.owner_id = p.id
left join public.categories c on c.id = b.category_id
order by p.created_at desc
limit 20;
