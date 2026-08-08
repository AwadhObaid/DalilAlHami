# Phase 09B v3 — Offline Recovery + Dark Mode Fix

This corrective package addresses the two issues found during device QA after
Phase 09B:

1. A queued/offline rating could remain marked as pending after connectivity
   returned because the rating store had no retry trigger while the app stayed
   open. The store now retries pending ratings automatically every six seconds
   while there is pending work, immediately retries a pending rating when its
   business is opened, and preserves the local pending selection until the
   server confirms it.

2. The Add/Manage Business screens still contained legacy hard-coded light
   surfaces (`Colors.white`, `Colors.grey[50]`, `Colors.black87`). In Dark Mode
   those light cards were combined with dark-theme light text, producing the
   low-contrast screenshots seen on device. Those surfaces/text tokens now use
   the existing semantic AppColors dark/light palette.

No database migration is added or changed.
No rating/favorites data is deleted.
No app version, updater, Firebase, Supabase credentials, or signing config is changed.
