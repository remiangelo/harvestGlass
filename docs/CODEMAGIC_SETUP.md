# Shipping Harvest to TestFlight with Codemagic (no Mac required)

`codemagic.yaml` (repo root) already defines the build → sign → TestFlight
pipeline. Signing is **fully automatic**: Codemagic uses an App Store Connect
API key to create the distribution certificate and provisioning profile in the
cloud. You never touch a Mac or a `.p12`.

Do the one-time steps below, then every push to `main` builds and uploads to
TestFlight (you can also press **Start new build** manually).

---

## Prerequisites (Apple side — only you can do these)

### 1. Apple Developer Program
Your project's team is `L3P46Q9398`, so you're likely already enrolled. Confirm
at <https://developer.apple.com/account> (membership is $99/year).

### 2. Register the app in App Store Connect
If it doesn't exist yet:
1. <https://appstoreconnect.apple.com> → **Apps** → **+** → **New App**.
2. Platform **iOS**, Bundle ID **`HarvestGlass.Harvest`** (it must already exist
   under Certificates, Identifiers & Profiles → Identifiers; if not, add it there
   first), pick an SKU and name.
   - TestFlight does **not** require the app to be submitted for review — only
     that the app record + bundle ID exist.

### 3. Create an App Store Connect API key
1. <https://appstoreconnect.apple.com> → **Users and Access** → **Integrations**
   tab → **App Store Connect API** → **+**.
2. Access role: **App Manager** (or Admin).
3. Download the **`.p8`** file (you can only download it once) and note:
   - **Issuer ID** (top of the Keys page)
   - **Key ID** (the row you just created)

---

## Codemagic setup

### 4. Connect the repo
1. Sign up at <https://codemagic.io> with your GitHub account (free tier ≈ 500
   macOS build-minutes/month).
2. **Add application** → authorize GitHub → pick the repo that holds `main`
   (the local `main` currently tracks the **remiangelo/harvestGlass** remote —
   connect that one, or whichever remote you push `main` to).
3. When asked, choose **codemagic.yaml** as the configuration (it's auto-detected
   in the repo root).

### 5. Add the App Store Connect API key
1. Codemagic → **Teams** (or the app's settings) → **Integrations** →
   **App Store Connect** → **Connect**.
2. Upload the `.p8`, paste the **Issuer ID** and **Key ID**.
3. Name the key **exactly**: `Harvest ASC API Key`
   - This string must match `integrations.app_store_connect` in `codemagic.yaml`.
     If you name it differently, update that line in the yaml.

### 6. Run it
- Push any commit to `main`, **or** open the app in Codemagic → **Start new
  build** → workflow **Harvest iOS — TestFlight**.
- On success the build appears in **App Store Connect → TestFlight** in a few
  minutes. Add it to an internal tester group there (or uncomment `beta_groups`
  in `codemagic.yaml`).

---

## Notes & gotchas

- **Encryption compliance prompt.** The first TestFlight build may ask about
  export compliance. If Harvest only uses standard HTTPS, set
  `ITSAppUsesNonExemptEncryption` to `NO` — either answer it once per build in
  App Store Connect, or add `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`
  to the target's build settings in Xcode to suppress it permanently.
- **Build numbers.** The pipeline sets `CFBundleVersion` to Codemagic's
  auto-incrementing `$BUILD_NUMBER`, so TestFlight never rejects a duplicate. If
  the `agvtool` step warns, enable Apple-generic versioning on the target
  (Build Settings → Versioning System = "Apple Generic").
- **Xcode version.** `xcode: latest` is used because the deployment target is
  iOS 26. If a build fails on an SDK mismatch, pin a specific version (e.g.
  `xcode: 26.0`) per Codemagic's available versions.
- **Auto-trigger.** Remove the `triggering:` block in `codemagic.yaml` if you'd
  rather only build manually instead of on every push to `main`.
- **Shared scheme.** `Harvest.xcscheme` is committed as a *shared* scheme so CI
  can find it — don't delete it.
- **Backend.** TestFlight builds talk to the live Supabase project
  (`jutzlxdboayvmcuqwodn`); the pivot migrations are already applied there. Push
  notifications remain unconfigured (see the pivot memory/notes).
