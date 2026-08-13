-- Dalil Al Hami - local migration history synchronization
-- Version: 20260813100033
-- Remote name: blogger_live_views_presence
-- Historical production migration. Its temporary schema effect was later removed by 20260813100457.
--
-- This migration version is already recorded as applied on the linked production
-- project. The two historical migrations have no net schema effect in the current
-- database because the later migration removed the temporary change.
--
-- This no-op file intentionally restores the missing LOCAL migration-history entry.
-- Do NOT use supabase migration repair for these versions.

select 1;
