# Android release builds

No Expo here — this is a native Kotlin/Compose app, so it builds through Gradle
directly. There is no `eas build` equivalent to run.

## Building

```bash
cd android
./gradlew :app:bundleRelease     # .aab — what Play Console wants
./gradlew :app:assembleRelease   # .apk — sideloading and direct testing
```

Outputs land in `app/build/outputs/bundle/release/` and
`app/build/outputs/apk/release/`, and are copied to `dist/` (gitignored).

**Play Console needs the `.aab`.** New apps have not been accepted as APK since
August 2021. The APK is still the right thing for sideloading, sharing a test
build, or installing over adb.

## Signing

`app/build.gradle.kts` reads `android/keystore.properties` and signs the
release build with the key it names. Both that file and the keystore are
gitignored.

The config is conditional, for the same reason `google-services.json` is: a
checkout without the keystore still builds, it just produces an unsigned
release rather than failing.

### Back up the keystore

`android/harvest-upload-key.jks` — copy it somewhere outside this repo, along
with the passwords in `android/keystore.properties`. It is gitignored, so a
fresh clone will not have it.

This is an **upload key**, not the app signing key. Under Play App Signing
(mandatory for new apps) Google holds the actual signing key and re-signs what
you upload, so losing this one is recoverable — you request a reset from Play
Console rather than losing the app. Still worth backing up, because a reset
takes a couple of days.

Certificate fingerprints for this key:

- SHA-256: `a809b1ff4509651243a4b6ea529151f66170c47050b12978c4562f5ec32a0a8b`
- SHA-1: `e0e7f6872b1c3fb3761ece39ee33316acf0b9104`

If you already had an upload key from an earlier submission, this new one will
be rejected — say so and the config can point at the original instead.

### Firebase and the SHA-1

Firebase features that authenticate the app by certificate — Google Sign-In,
Dynamic Links, App Check — need the SHA-1 above added under **Project settings
→ Your apps → Add fingerprint**. FCM does not, so push works without it.

Play App Signing re-signs your upload, so the fingerprint users actually run is
Google's, not this one. Once the app is on Play, take the SHA-1 from **Play
Console → Setup → App integrity** and add that to Firebase too.

## R8 is off

`isMinifyEnabled = false`. Supabase, Ktor and kotlinx.serialization all lean on
reflection, so enabling shrinking needs keep rules written and then tested
against a real device. That is a deliberate follow-up, not something to switch
on blind for a first upload — a broken release build fails at runtime, not at
compile time, and only on the paths the rules missed.

Cost of leaving it off: about 17 MB rather than perhaps 8-10 MB.

## Verified on this build

- `apksigner verify` — signed, one signer, fingerprints above
- AAB structure — `BundleConfig.pb`, base manifest and dex all present, signed
- Manifest — `com.harvest.meetmindfully`, versionCode 1, versionName 1.0,
  minSdk 26, targetSdk 35
- Installed and launched the signed release APK on API 36: no crash, and
  `FirebaseApp initialization successful` from the app's own PID

## Version bumps

Play rejects a re-upload with a versionCode it has already seen. Bump
`versionCode` in `app/build.gradle.kts` for every upload; `versionName` is the
human-facing string and only needs changing when you want it to read
differently.
