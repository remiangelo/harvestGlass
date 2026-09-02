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
- Manifest — `com.harvest.meetmindfully`, versionName 1.0, minSdk 26
- Installed and launched the signed release APK on API 36: no crash, and
  `FirebaseApp initialization successful` from the app's own PID

## Target API level

Play requires apps to target within one year of the latest Android release.
As of 2026-08-27 that means **API 36 (Android 16)**; API 35 is rejected.

Bumping it needed three things, not one:

1. `compileSdk` and `targetSdk` → 36
2. **AGP 8.7.3 → 8.9.2** — 8.7 cannot compile against API 36 at all
3. The `platforms;android-36` SDK package, which was not installed

`cmdline-tools/latest` was empty, so `sdkmanager` had to be unpacked from the
`commandlinetools.zip` sitting in the SDK root first. It also needs JDK 17+,
while `JAVA_HOME` here points at JDK 11 — Android Studio's bundled JBR 21
works:

```bash
export JAVA_HOME="C:\Program Files\Android\Android Studio\jbr"
SDK="$LOCALAPPDATA/Android/Sdk"
"$SDK/cmdline-tools/latest/bin/sdkmanager.bat" --sdk_root="$SDK" "platforms;android-36"
```

### Verified on API 36

- 304 unit tests pass
- Signed release APK installs and launches on an API 36 emulator, no crash,
  `FirebaseApp initialization successful` from the app's own PID
- Manifest reads `targetSdkVersion:'36'`, versionCode 2
- The four `libandroidx.graphics.path.so` slices are uncompressed and
  **16 KB-aligned**, which Android 16 requires. Measure the *data* offset, not
  `header_offset` — the latter is the local file header and is never aligned,
  which makes a naive check report a false failure.

### Behaviour changes that did NOT bite

- **Orientation/resizability**: apps targeting 36 have `screenOrientation` and
  `resizeableActivity` ignored on large screens. The manifest sets neither.
- **Edge-to-edge**: already handled when targetSdk went to 35.

### One that did — see below

**Predictive back** is on by default at targetSdk 36. See the note in the port
status doc: most pushed screens do not register a `BackHandler`, so system back
exits the app rather than returning. Pre-existing, but now visible as an
app-exit animation.

## Version bumps

Play rejects a re-upload with a versionCode it has already seen. Bump
`versionCode` in `app/build.gradle.kts` for every upload; `versionName` is the
human-facing string and only needs changing when you want it to read
differently.

**versionCode 3** was the first build carrying both of the fixes Play warned
about on 2026-08-27: targetSdk 36 and Billing 8.0.0. The target-API side
needed no code change — `targetSdk` was already 36 at versionCode 2; the
warning stands until a build carrying it is actually **uploaded**.

**versionCode 4 / versionName 1.0.1** supersedes it, and is the one to upload.
3 was never uploaded, so it carries the Play fixes forward along with the
sign-up repair: supabase-kt returns no user when sign-up establishes the
session directly, so `createProfile` was skipped and every Android account
reached onboarding with no `public.users` row behind it — then failed at the
last step with `23502 null value in column "email"`. See
`supabase/migrations/20260902120000_profile_row_on_signup.sql`, which has to
be applied whether or not this build ships.

## Play Billing Library version

Play deprecates the Billing Library on a two-year cycle and enforces it as a
**publishing gate, not a runtime one**: builds already live keep transacting,
but uploads are rejected. From 2026-08-31 an upload must use **version 8 or
later** (an extension to 2026-11-01 can be requested). The app was on 7.1.1,
which is what Play's "update to a newer version" warning was about.

Now on **8.0.0**, and that specific version is a ceiling, not a preference:

| billing-ktx | Result with Kotlin 2.1.0 + Hilt 2.53 |
|---|---|
| 8.0.0 | builds |
| 8.1.0 – 8.3.0 | Hilt's `hiltJavaCompileDebug` dies — its bundled kotlinx-metadata-jvm reads at most Kotlin 2.1.0 metadata, these ship 2.2.0 |
| 9.0.0+ | Kotlin compiler itself rejects them — 2.3.0 metadata |

So moving past 8.0.0 means bumping Hilt first, and reaching 9.x means Kotlin
2.3. None of that is needed for the deadline: Play deprecates by **major**
version, so 8.0.0 and 8.3.0 have identical runway (v8 lands ~mid-2027).

### Why no code changed

8.0.0 removes `queryPurchaseHistory()`, `querySkuDetailsAsync()`, the
no-argument `enablePendingPurchases()`, and the `String`-typed
`queryPurchasesAsync` overload. `PlayBilling.kt` used none of them — it was
already on `PendingPurchasesParams` and the params-typed queries.

`queryProductDetailsAsync` did change shape (it now reports *why* a product
could not be fetched, via `QueryProductDetailsResult.unfetchedProductList`),
but the `billing-ktx` suspend wrapper flattens that back into the same
`ProductDetailsResult { billingResult, productDetailsList }` the call site
already reads. Unfetchable products were absent from the list under 7.x too,
so the behaviour is unchanged — only the diagnostics we don't consume are new.

`BillingClient.Builder.enableAutoServiceReconnection()` is new in 8.0 and
deliberately not adopted: `connect()` already re-checks `client.isReady` on
every call, which covers the same ground.

### Verifying an upload before it goes up

Play reads the library version from the AAB's dependency metadata, not the
manifest — so check there rather than grepping for a `<meta-data>` tag:

```bash
unzip -p app/build/outputs/bundle/release/app-release.aab \
  BUNDLE-METADATA/com.android.tools.build.libraries/dependencies.pb \
  | tr -c '[:print:]' '\n' | grep -A3 billingclient
```

targetSdk and versionCode are easier to read from the merged manifest, which
is plain XML (the copy inside the AAB is protobuf, so `grep` will not help):

```bash
grep -oE 'android:(versionCode|targetSdkVersion)="[0-9]+"' \
  app/build/intermediates/merged_manifest/release/processReleaseMainManifest/AndroidManifest.xml
```
