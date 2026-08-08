# Phase 09A — Favorites Foundation

This package is built against the exact source review bundle created on 2026-08-08 15:38.

What it does:
- Local-first favorites that work without sign-in.
- Immediate heart toggle on Home cards, directory cards, and business details.
- Favorites page available from Account whether signed in or signed out.
- When signed in, UUID-backed favorites are synchronized with the existing Supabase `favorites` table.
- Pending local add/remove operations survive transient network failure.
- Bundled/non-UUID favorites remain device-local.
- Supabase RLS is hardened so only the owner can read favorites and only active accounts can mutate them.
- Existing app version, branding, updater, Supabase runtime config, and Phase 12 work are preserved.

The installer DOES NOT run `supabase db push`. Apply the included migration only after Flutter analysis/tests pass.
