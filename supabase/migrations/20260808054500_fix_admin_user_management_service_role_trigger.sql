-- Dalil Al Hami
-- Phase 12A server repair Step 2
-- Fix admin user-management writes being silently reverted by the legacy profile guard trigger.

begin;

create or replace function public.protect_profile_admin_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request_role text := coalesce(auth.role(), '');
begin
  -- Administrator role/status lifecycle changes are intentionally performed only
  -- through the service-role-backed admin-users Edge Function +
  -- public.admin_apply_user_change().
  --
  -- The legacy trigger used public.is_admin(). A service-role RPC has no auth.uid(),
  -- so is_admin() returned false and the trigger silently restored OLD.role and
  -- OLD.is_active. The RPC therefore returned success while the requested state
  -- never persisted.
  if v_request_role <> 'service_role' then
    new.id := old.id;
    new.role := old.role;
    new.is_active := old.is_active;
    new.suspended_at := old.suspended_at;
    new.suspension_reason := old.suspension_reason;
    new.deleted_at := old.deleted_at;
  end if;

  return new;
end;
$$;

comment on function public.protect_profile_admin_fields() is
  'Protects account-management fields from direct client writes while permitting trusted service-role admin-user transactions.';

commit;
