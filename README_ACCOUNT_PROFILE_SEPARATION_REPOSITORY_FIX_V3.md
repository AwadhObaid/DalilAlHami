# Account Profile Separation — Repository Fix v3

Why v2 failed
=============
v2 used a global text replacement after inserting the missing
`normalizedName` declaration. Because the same declaration also existed as the
stale line inside `saveAccount`, the global replacement removed the FIRST match:
the newly-corrected declaration in `updateProfileDetails`.

That left both original errors in place:
- `updateProfileDetails` still referenced an undefined `normalizedName`.
- `saveAccount` still referenced the removed `fullName` parameter.

v3 correction
=============
This patch is intentionally narrow:
1. It edits only the `updateProfileDetails` method scope to restore
   `final normalizedName = fullName.trim();`.
2. It edits only the `saveAccount` method scope to remove the stale
   `final normalizedName = fullName.trim();`.
3. It replaces the earlier weak source-contract test with a method-scoped
   regression test so this exact bug cannot pass unnoticed again.

Safety
======
The installer checks the SHA-256 of the current repository file before
overwriting it. If it does not exactly match the known v2 failed state, the
installer stops instead of overwriting unknown local edits.

No Supabase migration.
No UI changes.
No account/business data changes.
