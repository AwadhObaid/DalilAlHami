# Account Profile Separation v1

Approved architecture
=====================
One user account can own multiple independent businesses.

Account
-------
`حسابي -> بيانات الحساب`

Contains:
- profile photo
- personal name
- phone
- Google email (read-only)
- change/delete profile photo
- save account details

Businesses
----------
`حسابي -> إدارة أنشطتي`

Each business keeps its own:
- logo
- business name
- category
- phone
- WhatsApp
- address
- map location
- description
- gallery
- moderation/status

The Add/Edit Business page no longer edits personal account identity.

Database
========
No migration is required. Existing `profiles` and `businesses.owner_id`
relationships already support one user owning multiple businesses, and the
existing profile RLS permits the signed-in user to update their own profile.

Safety
======
- No Supabase credentials are included.
- No app version/signing/update code is changed.
- Favorites and Ratings are untouched.
- Full Flutter regression tests are run by install.ps1.
