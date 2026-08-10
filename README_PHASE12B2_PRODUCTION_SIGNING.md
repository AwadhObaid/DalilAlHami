# Dalil Al Hami - Phase 12B2 Production Signing

Android release builds no longer use `debug.keystore`.

## Signing identities

- Direct APK: permanent App Signing key, alias `dalilalhami_app`.
- Google Play upload artifact: separate Upload key, alias `dalilalhami_upload`.

Passwords are never stored in the repository.

`android/key.properties` is Git-ignored and contains only local keystore paths and aliases.

## Direct production APK

Use:

`powershell -ExecutionPolicy Bypass -File .\scripts\build_production_apk.ps1`

The helper prompts for the App Signing keystore password and verifies the final APK signer fingerprint.

## Google Play AAB

In the current Windows/Flutter/AGP environment, AGP's `packageReleaseBundle` rejects an otherwise valid base module with:

`Invalid dex file indices, expecting file 'classes?.dex' but found 'classes2.dex'.`

The generated `base.zip` itself was independently verified to contain both `dex/classes.dex` and `dex/classes2.dex`.

A Play AAB was successfully created with the official standalone bundletool 1.18.3, signed with the Play Upload key, accepted by `bundletool validate`, and its upload certificate fingerprint was verified.

For an already-generated valid `base.zip`, use:

`powershell -ExecutionPolicy Bypass -File .\scripts\build_play_aab_from_existing_base.ps1`

This helper intentionally does not trigger another Flutter/Gradle build. It converts the existing base module into an AAB, signs it with the Play Upload key, validates the bundle, and verifies the signer fingerprint.

## Beta to production signature transition

Beta releases were signed with the Android Debug certificate.

The first production-signed APK cannot update an existing Beta installation in place. Beta testers must uninstall the Beta once before installing the first production-signed build.