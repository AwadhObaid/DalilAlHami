-- دليل الحامي
-- المرحلة 03B: تجهيز القراءة الفعلية للتصنيفات والأنشطة

begin;

-- تحديد مكان عرض كل تصنيف داخل واجهة التطبيق.
alter table public.categories
  add column if not exists display_group text;

update public.categories
set display_group = 'services'
where display_group is null;

update public.categories
set display_group = 'transport'
where slug in (
  'work-equipment',
  'water-tankers',
  'transport-trucks',
  'tuk-tuks',
  'noha-vehicles',
  'taxis',
  'delivery-motorcycles'
);

alter table public.categories
  alter column display_group set default 'services';

alter table public.categories
  alter column display_group set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'categories_display_group_check'
      and conrelid = 'public.categories'::regclass
  ) then
    alter table public.categories
      add constraint categories_display_group_check
      check (display_group in ('services', 'transport'));
  end if;
end;
$$;

create index if not exists categories_display_group_sort_idx
  on public.categories(display_group, sort_order)
  where is_active = true;

-- أنشطة تجريبية معتمدة للتأكد من أن التطبيق يقرأ من Supabase.
-- نوقف مشغل حماية حقول الاعتماد مؤقتًا لأن تنفيذ Migration لا يحمل auth.uid().
alter table public.businesses
  disable trigger businesses_protect_moderation_fields;

with sample_businesses (
  id,
  category_slug,
  name,
  description,
  phone,
  whatsapp,
  address,
  is_featured
) as (
  values
    (
      '10000000-0000-4000-8000-000000000001'::uuid,
      'pharmacies',
      'صيدلية الحامي الحديثة',
      'صيدلية تجريبية ضمن بيانات المرحلة 03B.',
      '777111222',
      '777111222',
      'بجانب المستشفى',
      true
    ),
    (
      '10000000-0000-4000-8000-000000000002'::uuid,
      'restaurants',
      'مطعم وادي سبأ',
      'مطعم تجريبي ضمن بيانات المرحلة 03B.',
      '777333444',
      '777333444',
      'الشارع العام',
      true
    ),
    (
      '10000000-0000-4000-8000-000000000003'::uuid,
      'tuk-tuks',
      'تكتك السعيد',
      'خدمة نقل تجريبية ضمن بيانات المرحلة 03B.',
      '777555111',
      '777555111',
      'السوق',
      false
    )
)
insert into public.businesses (
  id,
  category_id,
  name,
  description,
  phone,
  whatsapp,
  address,
  status,
  is_featured,
  is_active,
  approved_at
)
select
  sample.id,
  category.id,
  sample.name,
  sample.description,
  sample.phone,
  sample.whatsapp,
  sample.address,
  'approved',
  sample.is_featured,
  true,
  timezone('utc', now())
from sample_businesses sample
join public.categories category
  on category.slug = sample.category_slug
on conflict (id) do update
set
  category_id = excluded.category_id,
  name = excluded.name,
  description = excluded.description,
  phone = excluded.phone,
  whatsapp = excluded.whatsapp,
  address = excluded.address,
  status = 'approved',
  is_featured = excluded.is_featured,
  is_active = true,
  approved_at = coalesce(
    public.businesses.approved_at,
    excluded.approved_at
  ),
  updated_at = timezone('utc', now());

alter table public.businesses
  enable trigger businesses_protect_moderation_fields;

-- RLS تبقى هي طبقة الحماية، والمنح تسمح لـData API بتنفيذ SELECT.
grant select on public.categories to anon, authenticated;
grant select on public.businesses to anon, authenticated;

commit;
