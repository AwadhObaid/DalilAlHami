# Phase 12B1.1 — Developer Credits + Startup GitHub Update Check

- App concept: الغريم سالم
- Programming and development: المهندس عوض بن قفلة
- Automatic update check now runs from `SplashScreen` on every app launch.
- Startup network check is capped at 5 seconds and never blocks app launch on failure.
- When a newer eligible GitHub Release is found, SplashScreen shows a dialog with:
  - Later
  - Download update
- Download opens the APK asset from `AwadhObaid/DalilAlHami-Releases` using the external browser/download handler.
- Settings keeps a manual `Check for updates` button, but opening Settings no longer triggers an automatic network check.
- Beta installs can receive newer Beta or Stable releases; Stable installs ignore prereleases.
