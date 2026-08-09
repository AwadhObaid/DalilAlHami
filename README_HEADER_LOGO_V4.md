# Header Logo Regression Test Fix v4

Root cause
----------
The v3 visual tuning correctly changed the Home header logo from 235x112 / -14
to 260x124 / -23. However, the older v2 regression test
`home_header_logo_size_position_test.dart` remained in the project and still
required the obsolete v2 values. The full regression suite therefore failed
even though the current application source contains the intended v3 values.

Fix
---
The obsolete v2 test is converted into a stable structural contract. It now
verifies that the official logo asset is present, centered, contained, and
translated safely without hard-coding a superseded tuning value.

The v3 test remains responsible for validating the currently approved
260x124 / -23 values.

No application source changes.
No asset changes.
No Supabase migration.
