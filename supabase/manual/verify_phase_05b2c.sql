-- تحقق يدوي من المرحلة 05B-2C
select
  not exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and indexname = 'businesses_one_per_owner_idx'
  ) as single_owner_constraint_removed,
  exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and indexname = 'businesses_owner_created_idx'
  ) as multi_owner_lookup_index_exists;
