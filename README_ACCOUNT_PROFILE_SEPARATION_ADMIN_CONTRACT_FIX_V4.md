# Account Profile Separation — Admin Contract Fix v4

Observed failure
================
The application source passed `flutter analyze`, and the full suite later failed
only in the legacy Phase 07A admin source-contract test.

The obsolete assertion expected this old implementation detail:

    role: cachedProfile?.role ?? 'user'

That exact construction no longer exists after Account/Profile Separation.

Current equivalent behavior
===========================
`saveAccount()` now preserves the complete cached AccountProfile:

    final profile = cachedProfile ?? _profileFromUser(user);

Therefore an existing cached admin profile keeps its real role. Only when there
is no cached profile does `_profileFromUser()` create a safe fallback with:

    role: 'user'

The admin page still independently rejects inactive/non-admin profiles, and the
Account Hub still shows the admin entry only when `isAdmin == true`.

This package updates ONLY the obsolete test contract to verify the new semantic
equivalent. It does not change application code, Supabase, migrations, data,
branding, Favorites, Ratings, Firebase, signing, or versioning.
