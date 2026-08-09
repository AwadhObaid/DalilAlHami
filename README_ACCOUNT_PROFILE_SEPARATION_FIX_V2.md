# Account Profile Separation — Compile Fix v2

This patch fixes the compile/analyze errors found immediately after installing v1.

Root causes fixed:
1. `updateProfileDetails()` referenced `normalizedName` after the declaration had
   been removed by an over-broad transformation.
2. `saveAccount()` no longer accepts `fullName`, but one stale
   `final normalizedName = fullName.trim();` line remained.
3. `_trySaveProfileOnline()` became unused after personal profile writes were
   separated from business writes.
4. `AccountProfilePage` hides Flutter's material `Text`, consistent with the rest
   of the localized app, but was missing the project's localized Text import.

No Supabase migration is required.
No account/business data is changed.
No Favorites, Ratings, header branding, updater, app version, Firebase, signing,
or Supabase credentials are changed.
