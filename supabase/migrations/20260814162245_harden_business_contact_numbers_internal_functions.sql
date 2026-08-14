-- Dalil Al Hami - Phase 17A.1
-- Remote follow-up hardening applied after the contact-number foundation.
-- Internal helper/trigger functions must not be callable through PostgREST RPC.

revoke all on function public.enforce_business_contact_number_limit()
  from public, anon, authenticated;

revoke all on function public.business_contact_numbers_after_change_trigger()
  from public, anon, authenticated;

revoke all on function public.refresh_business_legacy_contact_fields(uuid)
  from public, anon, authenticated;

revoke all on function public.ensure_business_contact_primary(uuid)
  from public, anon, authenticated;

revoke all on function public.sync_legacy_business_fields_to_contacts()
  from public, anon, authenticated;

revoke all on function public.normalize_business_contact_number(text)
  from public, anon, authenticated;

revoke all on function public.split_legacy_business_phone_numbers(text)
  from public, anon, authenticated;
