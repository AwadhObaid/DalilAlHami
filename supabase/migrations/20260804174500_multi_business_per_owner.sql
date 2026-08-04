-- دليل الحامي
-- المرحلة 05B-2C: دعم تعدد الأنشطة لكل مستخدم

begin;

-- إزالة القيد القديم الذي كان يسمح بنشاط واحد فقط لكل مالك.
drop index if exists public.businesses_one_per_owner_idx;

-- فهرس عادي لتحسين جلب جميع أنشطة المستخدم دون فرض التفرد.
create index if not exists businesses_owner_created_idx
  on public.businesses(owner_id, created_at desc)
  where owner_id is not null;

comment on index public.businesses_owner_created_idx is
  'Supports listing multiple businesses for one authenticated owner.';

commit;
