-- فحص المرحلة 03B – للقراءة فقط

select
  display_group,
  count(*) as category_count
from public.categories
where is_active = true
group by display_group
order by display_group;

select
  b.id,
  b.name,
  c.name_ar as category_name,
  c.display_group,
  b.status,
  b.is_active,
  b.is_featured
from public.businesses b
join public.categories c on c.id = b.category_id
where b.id in (
  '10000000-0000-4000-8000-000000000001'::uuid,
  '10000000-0000-4000-8000-000000000002'::uuid,
  '10000000-0000-4000-8000-000000000003'::uuid
)
order by b.name;

select
  count(*) as public_approved_businesses
from public.businesses
where status = 'approved'
  and is_active = true;
