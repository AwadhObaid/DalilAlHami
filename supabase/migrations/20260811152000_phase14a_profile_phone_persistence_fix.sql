-- Dalil Al Hami
-- Phase 14A: preserve the editable profile phone for Google-auth accounts.
--
-- Root cause:
-- sync_auth_user_profile() is triggered by raw_user_meta_data updates.
-- Google-auth users normally have auth.users.phone = NULL. The previous
-- function copied that NULL into public.profiles.phone, so changing
-- full_name metadata could erase a phone number that the user had just
-- saved directly in public.profiles.
--
-- Contract:
-- - A real non-empty auth.users.phone remains authoritative when present.
-- - A NULL/blank auth.users.phone must never erase an existing profile phone.
-- - Existing profile full_name/avatar preservation behavior remains intact.

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
    phone = case
      when nullif(btrim(coalesce(excluded.phone, '')), '') is null
        then public.profiles.phone
      else excluded.phone
    end,
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

comment on function public.sync_auth_user_profile() is
  'Synchronizes Google/Auth identity fields without erasing an app-managed profile phone when auth.users.phone is blank.';

commit;