-- Phase 07B verification queries (run in Supabase SQL Editor)

select
  to_regclass('public.business_reviews') as business_reviews_table,
  to_regprocedure('public.admin_review_business(uuid,text,text)')
    as review_rpc;

select
  conname,
  pg_get_constraintdef(oid)
from pg_constraint
where conrelid = 'public.businesses'::regclass
  and conname = 'businesses_status_check';

select
  policyname,
  cmd,
  roles
from pg_policies
where schemaname = 'public'
  and tablename = 'business_reviews'
order by policyname;
