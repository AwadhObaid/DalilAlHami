-- فحص المرحلة 03C – Google Auth
-- للقراءة فقط

select
  u.id,
  u.email,
  u.phone,
  identity.provider,
  p.full_name,
  p.role,
  p.is_active,
  p.avatar_url
from auth.users u
left join auth.identities identity
  on identity.user_id = u.id
left join public.profiles p
  on p.id = u.id
order by u.created_at desc;

select
  owner_id,
  count(*) as owned_business_count
from public.businesses
where owner_id is not null
group by owner_id
order by owned_business_count desc;

select
  indexname,
  indexdef
from pg_indexes
where schemaname = 'public'
  and indexname = 'businesses_one_per_owner_idx';
