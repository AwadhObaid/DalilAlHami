# Phase 09B — Business Ratings

Features:
- Public average rating and rating count for approved businesses.
- One rating per authenticated account per business, editable from 1 to 5 stars.
- Primary-key protection prevents duplicate ratings from the same account.
- Active-account enforcement through Supabase RPC/RLS.
- Local cached summaries.
- Offline-first pending rating queue; pending ratings sync after sign-in/connectivity returns.
- Ratings UI is added to Business Details only, avoiding fixed-height Home card regressions.
- Phase 09A favorites remain unchanged.

The installer does NOT push the Supabase migration automatically.
