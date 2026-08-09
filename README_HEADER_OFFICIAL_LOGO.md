# Home Header — Official Logo v1

This update changes only the visual brand block in the Home page header.

Replaced:
- the location-pin identity icon
- the separate "دليل الحامي" title text
- the separate "دليل الأنشطة والخدمات المحلية" subtitle

With:
- the exact logo supplied by the user, prepared as a tightly cropped transparent
  PNG at `assets/home_header_logo.png`.

Preserved:
- the current teal scenic header background
- notification button
- menu/categories button
- search bar and filter button
- header dimensions
- advertising layout
- Light/Dark behavior
- Favorites, Ratings, Supabase, Firebase, updater and app version

No database migration is required.
`pubspec.yaml` does not need modification because the project already includes
the whole `assets/` directory.
