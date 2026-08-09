# Home UI Actions + Advertisement Auto-slide — Fix v2

This corrective package is intended only for a project where v1 was already copied and then stopped at `flutter analyze` because the legacy Phase 06A home design test instantiated `HomeHeader` without the newly required `onOpenSettings` argument.

## Fix

- Keeps the production dashboard explicitly passing `onOpenSettings: _openSettings`.
- Makes the `HomeHeader.onOpenSettings` constructor callback nullable for backward compatibility with older widget tests/usages.
- Allows the underlying header icon button to receive a nullable callback; production remains enabled because the dashboard supplies the settings callback.
- Updates the new source-contract test to enforce that `onOpenSettings` is supported but not constructor-required.
- Does not change the approved Settings, filter, transport-shortcut removal, or advertisement auto-slide behavior from v1.
- Does not create a Git commit.
