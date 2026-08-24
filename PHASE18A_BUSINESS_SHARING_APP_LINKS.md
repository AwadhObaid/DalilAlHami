# Phase 18A — Business Sharing and Android App Links

## Delivered

- A share action on every public business details page.
- A concise Arabic share message containing the business name, category,
  location, and one stable HTTPS link. Phone numbers and full descriptions are
  intentionally not copied into the message.
- Reuse of the app's existing native Android share channel, so no additional
  sharing plugin or media cache is introduced.
- Verified Android App Links for
  `https://dalilalhami-share.pages.dev/b/<business-id>`.
- Cold-start and warm-start link routing directly to `MemberDetailsPage`.
- A public Cloudflare Pages fallback for people who do not have the app.
- Optional rich WhatsApp/social previews read from the existing public
  Supabase business row.
- Direct download fallback to the latest stable APK in
  `AwadhObaid/DalilAlHami-Releases`.

## Storage contract

This phase adds no Supabase migration, table, row, bucket, or uploaded media.
The landing Function performs a read-only request for an already-public,
approved, active business. It sends the existing publishable key only through
the Supabase `apikey` header. Cloudflare serves the landing page and App Links
association.

## Production identity

- Android package: `com.awadhobaid.dalilalhami`
- App Link host: `dalilalhami-share.pages.dev`
- Stable signing certificate SHA-256:
  `5B630A18CD75E7A86D530F5FFE5501FEB2453B76137EA5DFFF37150807969124`

Changing either the host or the signing certificate requires updating both the
Android manifest and `share_site/public/.well-known/assetlinks.json` before a
new stable release is published.
