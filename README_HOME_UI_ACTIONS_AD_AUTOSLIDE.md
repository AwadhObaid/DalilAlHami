# Home UI Actions + Advertisement Auto Slide

This patch is based on source commit `0ab4ab9` (`v1.0.6-beta+7`).

Changes:

- The upper Home header button now uses the Settings icon and opens `AppSettingsPage`.
- The filter/tune button beside the Home search launcher opens the Search tab, where the existing directory filter bar is available.
- The synthetic `خدمات النقل` shortcut is removed from Home featured categories only. Transport categories/data remain intact elsewhere.
- The main Home advertisement slider advances automatically every 4 seconds using a 550 ms `easeInOutCubic` animation.
- Auto-slide pauses during touch/drag and resumes after 5 seconds.
- When the final advertisement advances, a duplicate first page provides a seamless forward loop and then resets the controller to page 0.
- A single advertisement does not start auto-slide.
- App lifecycle changes pause/resume the auto-slide timer.

No Supabase migration is required. No app version bump is included in this patch.
