-- Dalil Al Hami - Phase 17A.2 hardening
-- Remote migration: 20260814172015
-- harden_business_contact_number_delete_sync

create or replace function public.bump_business_sync_after_contact_delete()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.businesses
  set updated_at = timezone('utc', now())
  where id = old.business_id;

  return old;
end;
$$;

revoke all
  on function public.bump_business_sync_after_contact_delete()
  from public, anon, authenticated;

drop trigger if exists business_contact_numbers_directory_sync_delete
  on public.business_contact_numbers;

create trigger business_contact_numbers_directory_sync_delete
after delete
on public.business_contact_numbers
for each row
execute function public.bump_business_sync_after_contact_delete();
