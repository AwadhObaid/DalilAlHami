-- دليل الحامي
-- المرحلة 03C البديلة: مزامنة ملفات مستخدمي Google

begin;

create or replace function public.sync_auth_user_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  metadata_full_name text;
  metadata_avatar_url text;
begin
  metadata_full_name := coalesce(
    new.raw_user_meta_data ->> 'full_name',
    new.raw_user_meta_data ->> 'name',
    ''
  );

  metadata_avatar_url := coalesce(
    new.raw_user_meta_data ->> 'avatar_url',
    new.raw_user_meta_data ->> 'picture'
  );

  insert into public.profiles (
    id,
    full_name,
    email,
    phone,
    avatar_url
  )
  values (
    new.id,
    metadata_full_name,
    new.email,
    new.phone,
    metadata_avatar_url
  )
  on conflict (id) do update
  set
    full_name = case
      when nullif(public.profiles.full_name, '') is null
        then excluded.full_name
      else public.profiles.full_name
    end,
    email = excluded.email,
    phone = excluded.phone,
    avatar_url = coalesce(
      public.profiles.avatar_url,
      excluded.avatar_url
    ),
    updated_at = timezone('utc', now());

  return new;
end;
$$;

drop trigger if exists on_auth_user_profile_synced on auth.users;
create trigger on_auth_user_profile_synced
after insert or update of email, phone, raw_user_meta_data
on auth.users
for each row execute function public.sync_auth_user_profile();

-- مزامنة الحسابات الموجودة قبل هذا التحديث.
insert into public.profiles (
  id,
  full_name,
  email,
  phone,
  avatar_url
)
select
  user_row.id,
  coalesce(
    user_row.raw_user_meta_data ->> 'full_name',
    user_row.raw_user_meta_data ->> 'name',
    ''
  ),
  user_row.email,
  user_row.phone,
  coalesce(
    user_row.raw_user_meta_data ->> 'avatar_url',
    user_row.raw_user_meta_data ->> 'picture'
  )
from auth.users user_row
on conflict (id) do update
set
  full_name = case
    when nullif(public.profiles.full_name, '') is null
      then excluded.full_name
    else public.profiles.full_name
  end,
  email = excluded.email,
  phone = excluded.phone,
  avatar_url = coalesce(
    public.profiles.avatar_url,
    excluded.avatar_url
  ),
  updated_at = timezone('utc', now());

commit;
