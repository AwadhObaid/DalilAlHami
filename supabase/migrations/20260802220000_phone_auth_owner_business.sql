-- دليل الحامي
-- المرحلة 03C: تسجيل الهاتف وربط نشاط واحد بالمستخدم

begin;

-- يسمح التطبيق للمستخدم المصادق بإدارة ملفه ونشاطه فقط.
grant select, insert, update on public.profiles to authenticated;
grant select, insert, update, delete on public.businesses to authenticated;
grant select on public.categories to authenticated;

-- واجهة التطبيق الحالية تدير نشاطًا واحدًا لكل حساب.
create unique index if not exists businesses_one_per_owner_idx
  on public.businesses(owner_id)
  where owner_id is not null;

-- إبقاء رقم الهاتف في profiles متزامنًا مع auth.users.
create or replace function public.sync_auth_user_profile()
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
  on conflict (id) do update
  set
    email = excluded.email,
    phone = excluded.phone,
    updated_at = timezone('utc', now());

  return new;
end;
$$;

drop trigger if exists on_auth_user_profile_synced on auth.users;
create trigger on_auth_user_profile_synced
after insert or update of email, phone on auth.users
for each row execute function public.sync_auth_user_profile();

-- إعادة مزامنة المستخدمين الموجودين قبل هذه المرحلة.
insert into public.profiles (
  id,
  full_name,
  email,
  phone
)
select
  user_row.id,
  coalesce(user_row.raw_user_meta_data ->> 'full_name', ''),
  user_row.email,
  user_row.phone
from auth.users user_row
on conflict (id) do update
set
  email = excluded.email,
  phone = excluded.phone,
  updated_at = timezone('utc', now());

commit;
