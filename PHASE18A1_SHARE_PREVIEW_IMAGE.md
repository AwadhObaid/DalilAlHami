# Phase 18A.1 — Existing Business Image in Rich Share Previews

## Change

The Cloudflare Pages Function now selects the preview image in this order:

1. Existing business cover URL.
2. Existing primary active `business_images` gallery image.
3. Existing business logo URL.
4. The generic DalilAlHami share card.

If a gallery row has only `storage_path`, the Function derives its public HTTPS
URL from the existing public `business-media` bucket.

## Social metadata

The landing page provides:

- `og:image`
- `og:image:secure_url`
- `og:image:alt`
- `twitter:image`
- `twitter:image:alt`
- A canonical URL that preserves the Phase 18A App Link host and route.

## Storage and release contract

- No Supabase table, column, row, function, policy, bucket, or object is added.
- No image is uploaded, copied, transformed, or cached by the app.
- The Function performs a read-only nested Data API request protected by the
  existing public-business and business-image RLS policies.
- The Flutter source, Android manifest, version, signing identity, and APK are
  unchanged.
- The App Link remains
  `https://dalilalhami-share.pages.dev/b/<business-id>`.
- No Git commit, tag, push, or public GitHub Release is performed by this phase.
