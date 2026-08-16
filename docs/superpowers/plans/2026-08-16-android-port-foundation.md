# Harvest Android — Foundation & Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the Android app at `android/` and prove the entire stack end to end — theme, Supabase, auth, navigation, and The Field (room list → room chat with Realtime) — running on a device against live data.

**Architecture:** Native Kotlin + Jetpack Compose, single Activity, Navigation Compose, Hilt DI. Package structure mirrors the iOS folder structure 1:1 (`data/model`, `data/service`, `ui/<feature>`, `ui/theme`, `util`) so every Swift file has an obvious counterpart. Design tokens are exposed through a `CompositionLocal` rather than Material3's `ColorScheme` so token names survive verbatim.

**Tech Stack:** Kotlin 2.1.0, AGP 8.7.3, Compose BOM 2024.12.01, supabase-kt 3.0.3 (postgrest, auth, realtime, storage), Ktor 3.0.3, Hilt 2.53, Coil 2.7.0, Navigation Compose 2.8.5, JUnit4 + MockK + kotlinx-coroutines-test.

**Spec:** `docs/superpowers/specs/2026-08-16-android-port-design.md`

## Global Constraints

- **Do not modify anything under `Harvest/`.** That is the shipped iOS app. This plan only creates files under `android/`.
- **compileSdk 35, targetSdk 35, minSdk 26.** Platform 35 is the only one installed locally; minSdk 26 gives `java.time` without desugaring, which the message-timestamp parsing needs.
- **`JAVA_HOME` on this machine points at `jdk-11.0.2`**, below AGP 8.x's minimum of 17. Pin the JDK in `android/gradle.properties` via `org.gradle.java.home`; never change the machine's global environment.
- **Color tokens are copied verbatim** from `Harvest/Theme/HarvestTheme.swift` — same names, same hex values. The `wine*` prefix means "surface, deepest to most lifted" and denotes **light tints**, not darks. Keep the explanatory comment.
- **Light-only.** iOS forces `.preferredColorScheme(.light)`. Android must not follow system dark mode.
- **No Liquid Glass.** `HarvestGlassButtonStyle` uses iOS 26's `.glassEffect()`, which has no Android equivalent. Reproduce color, geometry, padding, and the press spring (scale 0.96, `spring(response: 0.3, dampingFraction: 0.65)`); accept the loss of the translucent material.
- **Supabase project:** URL `https://jutzlxdboayvmcuqwodn.supabase.co`, anon key and `storageBucket = "profile-photos"` copied from `Harvest/Config.swift`. Deep-link scheme is `harvestapp`.
- **User IDs are lowercased UUID strings** everywhere (`session.user.id.uuidString.lowercased()` on iOS). Match this exactly or RLS comparisons silently miss.

---

## File Structure

```
android/
  settings.gradle.kts
  build.gradle.kts
  gradle.properties
  gradle/libs.versions.toml
  app/
    build.gradle.kts
    src/main/AndroidManifest.xml
    src/main/java/com/harvestglass/harvest/
      HarvestApplication.kt          — Hilt entry point
      MainActivity.kt                — single Activity, hosts HarvestApp()
      Config.kt                      — mirrors Harvest/Config.swift
      di/AppModule.kt                — Hilt providers for client + services
      data/SupabaseManager.kt        — mirrors Services/SupabaseManager.swift
      data/model/Community.kt        — mirrors Models/Community.swift
      data/model/UserProfile.kt      — mirrors Models/UserProfile.swift (slice subset)
      data/service/AuthService.kt    — mirrors Services/AuthService.swift
      data/service/CommunityService.kt — mirrors Services/CommunityService.swift
      ui/theme/HarvestTheme.kt       — mirrors Theme/HarvestTheme.swift
      ui/theme/HarvestButton.kt      — mirrors Theme/HarvestButtonStyle.swift
      ui/components/GlassCard.kt
      ui/components/GlassButton.kt
      ui/components/ChipView.kt
      ui/components/SectionHeader.kt
      ui/components/GlassBadge.kt
      ui/HarvestApp.kt               — root gating, mirrors HarvestApp.swift
      ui/LaunchScreen.kt
      ui/MainTabScreen.kt            — mirrors Views/MainTabView.swift
      ui/auth/AuthViewModel.kt
      ui/auth/LoginScreen.kt
      ui/field/FieldViewModel.kt
      ui/field/FieldScreen.kt
      ui/field/CommunityChatViewModel.kt
      ui/field/CommunityChatScreen.kt
    src/test/java/com/harvestglass/harvest/  — unit tests mirroring HarvestTests/
    src/androidTest/java/com/harvestglass/harvest/ — Compose UI tests
```

---

### Task 1: Gradle scaffold that builds and runs

**Files:**
- Create: `android/settings.gradle.kts`, `android/build.gradle.kts`, `android/gradle.properties`, `android/gradle/libs.versions.toml`, `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`
- Create: `android/app/src/main/java/com/harvestglass/harvest/MainActivity.kt`, `HarvestApplication.kt`, `Config.kt`
- Create: `android/.gitignore`

**Interfaces:**
- Consumes: nothing (first task).
- Produces: `Config` object with `SUPABASE_URL: String`, `SUPABASE_ANON_KEY: String`, `APP_SCHEME: String`, `STORAGE_BUCKET: String`. Gradle module `:app` with applicationId `com.harvestglass.harvest`.

- [ ] **Step 1: Generate the Gradle wrapper**

`gradle` is not on PATH, so bootstrap the wrapper from the Android Studio distribution. From `android/`:

```bash
mkdir -p android && cd android
"/c/Program Files/Android/Android Studio/gradle/gradle-8.9/bin/gradle" wrapper --gradle-version 8.9
```

If that path does not exist, locate it with `ls "/c/Program Files/Android/Android Studio/"` and adjust, or download the wrapper jar from `https://services.gradle.org/distributions/gradle-8.9-bin.zip`.

Expected: `gradlew`, `gradlew.bat`, `gradle/wrapper/gradle-wrapper.properties` created.

- [ ] **Step 2: Write `android/gradle.properties`**

```properties
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
org.gradle.java.home=C:\\Program Files\\Eclipse Adoptium\\jdk-21.0.4.7-hotspot
android.useAndroidX=true
kotlin.code.style=official
android.nonTransitiveRClass=true
```

Verify the JDK path first with `java -XshowSettings:properties -version 2>&1 | grep java.home`. Use whatever that prints — it must be 17 or newer. Do **not** edit the machine's `JAVA_HOME`.

- [ ] **Step 3: Write `android/gradle/libs.versions.toml`**

```toml
[versions]
agp = "8.7.3"
kotlin = "2.1.0"
composeBom = "2024.12.01"
coreKtx = "1.15.0"
lifecycle = "2.8.7"
activityCompose = "1.9.3"
navigation = "2.8.5"
hilt = "2.53"
hiltNavigation = "1.2.0"
supabase = "3.0.3"
ktor = "3.0.3"
coil = "2.7.0"
junit = "4.13.2"
mockk = "1.13.13"
coroutinesTest = "1.9.0"
androidxTest = "1.2.1"

[libraries]
androidx-core-ktx = { module = "androidx.core:core-ktx", version.ref = "coreKtx" }
androidx-lifecycle-runtime-compose = { module = "androidx.lifecycle:lifecycle-runtime-compose", version.ref = "lifecycle" }
androidx-lifecycle-viewmodel-compose = { module = "androidx.lifecycle:lifecycle-viewmodel-compose", version.ref = "lifecycle" }
androidx-activity-compose = { module = "androidx.activity:activity-compose", version.ref = "activityCompose" }
androidx-navigation-compose = { module = "androidx.navigation:navigation-compose", version.ref = "navigation" }
compose-bom = { module = "androidx.compose:compose-bom", version.ref = "composeBom" }
compose-ui = { module = "androidx.compose.ui:ui" }
compose-ui-graphics = { module = "androidx.compose.ui:ui-graphics" }
compose-ui-tooling = { module = "androidx.compose.ui:ui-tooling" }
compose-ui-tooling-preview = { module = "androidx.compose.ui:ui-tooling-preview" }
compose-ui-test-junit4 = { module = "androidx.compose.ui:ui-test-junit4" }
compose-ui-test-manifest = { module = "androidx.compose.ui:ui-test-manifest" }
compose-material3 = { module = "androidx.compose.material3:material3" }
compose-material-icons = { module = "androidx.compose.material:material-icons-extended" }
hilt-android = { module = "com.google.dagger:hilt-android", version.ref = "hilt" }
hilt-compiler = { module = "com.google.dagger:hilt-android-compiler", version.ref = "hilt" }
hilt-navigation-compose = { module = "androidx.hilt:hilt-navigation-compose", version.ref = "hiltNavigation" }
supabase-bom = { module = "io.github.jan-tennert.supabase:bom", version.ref = "supabase" }
supabase-postgrest = { module = "io.github.jan-tennert.supabase:postgrest-kt" }
supabase-auth = { module = "io.github.jan-tennert.supabase:auth-kt" }
supabase-realtime = { module = "io.github.jan-tennert.supabase:realtime-kt" }
supabase-storage = { module = "io.github.jan-tennert.supabase:storage-kt" }
ktor-client-android = { module = "io.ktor:ktor-client-android", version.ref = "ktor" }
coil-compose = { module = "io.coil-kt:coil-compose", version.ref = "coil" }
junit = { module = "junit:junit", version.ref = "junit" }
mockk = { module = "io.mockk:mockk", version.ref = "mockk" }
kotlinx-coroutines-test = { module = "org.jetbrains.kotlinx:kotlinx-coroutines-test", version.ref = "coroutinesTest" }
androidx-test-runner = { module = "androidx.test:runner", version.ref = "androidxTest" }

[plugins]
android-application = { id = "com.android.application", version.ref = "agp" }
kotlin-android = { id = "org.jetbrains.kotlin.android", version.ref = "kotlin" }
kotlin-compose = { id = "org.jetbrains.kotlin.plugin.compose", version.ref = "kotlin" }
kotlin-serialization = { id = "org.jetbrains.kotlin.plugin.serialization", version.ref = "kotlin" }
hilt = { id = "com.google.dagger.hilt.android", version.ref = "hilt" }
ksp = { id = "com.google.devtools.ksp", version = "2.1.0-1.0.29" }
```

- [ ] **Step 4: Write `android/settings.gradle.kts` and `android/build.gradle.kts`**

`settings.gradle.kts`:

```kotlin
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "Harvest"
include(":app")
```

`build.gradle.kts`:

```kotlin
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.kotlin.serialization) apply false
    alias(libs.plugins.hilt) apply false
    alias(libs.plugins.ksp) apply false
}
```

- [ ] **Step 5: Write `android/app/build.gradle.kts`**

```kotlin
plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.hilt)
    alias(libs.plugins.ksp)
}

android {
    namespace = "com.harvestglass.harvest"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.harvestglass.harvest"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    buildFeatures { compose = true }
    packaging { resources { excludes += "/META-INF/{AL2.0,LGPL2.1}" } }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.navigation.compose)

    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.graphics)
    implementation(libs.compose.ui.tooling.preview)
    implementation(libs.compose.material3)
    implementation(libs.compose.material.icons)
    debugImplementation(libs.compose.ui.tooling)

    implementation(libs.hilt.android)
    ksp(libs.hilt.compiler)
    implementation(libs.hilt.navigation.compose)

    implementation(platform(libs.supabase.bom))
    implementation(libs.supabase.postgrest)
    implementation(libs.supabase.auth)
    implementation(libs.supabase.realtime)
    implementation(libs.supabase.storage)
    implementation(libs.ktor.client.android)

    implementation(libs.coil.compose)

    testImplementation(libs.junit)
    testImplementation(libs.mockk)
    testImplementation(libs.kotlinx.coroutines.test)

    androidTestImplementation(platform(libs.compose.bom))
    androidTestImplementation(libs.compose.ui.test.junit4)
    androidTestImplementation(libs.androidx.test.runner)
    debugImplementation(libs.compose.ui.test.manifest)
}
```

- [ ] **Step 6: Write the manifest, Application, Activity, and Config**

`android/app/src/main/AndroidManifest.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />

    <application
        android:name=".HarvestApplication"
        android:label="Harvest"
        android:icon="@mipmap/ic_launcher"
        android:theme="@style/Theme.Harvest"
        android:supportsRtl="true">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:windowSoftInputMode="adjustResize"
            android:theme="@style/Theme.Harvest">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="harvestapp" android:host="auth" />
            </intent-filter>
        </activity>
    </application>
</manifest>
```

Create `android/app/src/main/res/values/themes.xml`:

```xml
<resources>
    <style name="Theme.Harvest" parent="android:Theme.Material.Light.NoActionBar">
        <item name="android:statusBarColor">#E6C6B6</item>
        <item name="android:windowLightStatusBar">true</item>
    </style>
</resources>
```

Use the default launcher icon for now: create `res/mipmap-anydpi-v26/ic_launcher.xml` referencing a solid rose background, or copy any placeholder — the real icon ports in a later phase.

`Config.kt`:

```kotlin
package com.harvestglass.harvest

// Mirrors Harvest/Config.swift — same project, same bucket, same scheme.
object Config {
    const val SUPABASE_URL = "https://jutzlxdboayvmcuqwodn.supabase.co"
    const val SUPABASE_ANON_KEY =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp1dHpseGRib2F5dm1jdXF3b2RuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI5MTg4MTksImV4cCI6MjA2ODQ5NDgxOX0.SpsUKEH_pxCWVqoVYTsVOz9ULS9oAoz40CqMK-WJG4g"
    const val APP_SCHEME = "harvestapp"
    const val STORAGE_BUCKET = "profile-photos"
}
```

`HarvestApplication.kt`:

```kotlin
package com.harvestglass.harvest

import android.app.Application
import dagger.hilt.android.HiltAndroidApp

@HiltAndroidApp
class HarvestApplication : Application()
```

`MainActivity.kt` (placeholder body; replaced in Task 8):

```kotlin
package com.harvestglass.harvest

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.Text
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { Text("Harvest") }
    }
}
```

- [ ] **Step 7: Build and verify**

Run from `android/`:

```bash
./gradlew :app:assembleDebug
```

Expected: `BUILD SUCCESSFUL`. If a supabase-kt or KSP coordinate fails to resolve, check the published versions on Maven Central and bump only that version in `libs.versions.toml` — do not remove the dependency.

- [ ] **Step 8: Install and run on the emulator**

```bash
"$LOCALAPPDATA/Android/Sdk/emulator/emulator" -avd Medium_Phone -no-snapshot-load &
"$LOCALAPPDATA/Android/Sdk/platform-tools/adb" wait-for-device
./gradlew :app:installDebug
"$LOCALAPPDATA/Android/Sdk/platform-tools/adb" shell am start -n com.harvestglass.harvest/.MainActivity
```

Expected: the app launches showing the text "Harvest".

- [ ] **Step 9: Commit**

```bash
git add android/
git commit -m "feat(android): Gradle scaffold, manifest, and Config"
```

---

### Task 2: HarvestTheme design tokens

**Files:**
- Create: `android/app/src/main/java/com/harvestglass/harvest/ui/theme/HarvestTheme.kt`
- Test: `android/app/src/test/java/com/harvestglass/harvest/ui/theme/HarvestThemeTest.kt`

**Interfaces:**
- Consumes: nothing.
- Produces: `object HarvestTheme` with nested `Colors` (Compose `Color` vals), `Typography` (`TextStyle` vals), `Spacing`/`Radius` (`Dp` vals), `AnimationSpec` (`Int` millis). Also `@Composable fun HarvestAppTheme(content: @Composable () -> Unit)`.

- [ ] **Step 1: Write the failing test**

The test's job is to catch a mistyped hex during the port. Values are read off `Harvest/Theme/HarvestTheme.swift`.

```kotlin
package com.harvestglass.harvest.ui.theme

import androidx.compose.ui.graphics.Color
import org.junit.Assert.assertEquals
import org.junit.Test

class HarvestThemeTest {

    @Test
    fun `core surface tokens match the iOS palette`() {
        assertEquals(Color(0xFFE6C6B6), HarvestTheme.Colors.wineBlack)
        assertEquals(Color(0xFFF0D5C8), HarvestTheme.Colors.deepPlum)
        assertEquals(Color(0xFFFFF9F5), HarvestTheme.Colors.wineCard)
        assertEquals(Color(0xFFFFFFFF), HarvestTheme.Colors.wineRaised)
        assertEquals(Color(0xFF2A1714), HarvestTheme.Colors.photoScrim)
    }

    @Test
    fun `red accent family matches the iOS palette`() {
        assertEquals(Color(0xFFDB2637), HarvestTheme.Colors.rose)
        assertEquals(Color(0xFFEE6A72), HarvestTheme.Colors.roseLight)
        assertEquals(Color(0xFFA81C2B), HarvestTheme.Colors.roseDeep)
        assertEquals(Color(0xFFC94F58), HarvestTheme.Colors.roseBloom)
        assertEquals(Color(0xFFD97A28), HarvestTheme.Colors.amber)
        assertEquals(Color(0xFFC41F2E), HarvestTheme.Colors.accent)
    }

    @Test
    fun `field greens match the iOS palette`() {
        assertEquals(Color(0xFF2E7D5B), HarvestTheme.Colors.fieldGreen)
        assertEquals(Color(0xFF246B4C), HarvestTheme.Colors.fieldGreenLight)
        assertEquals(Color(0xFF1E5A40), HarvestTheme.Colors.fieldGreenDeep)
    }

    @Test
    fun `text tokens are warm darks on a light page`() {
        assertEquals(Color(0xFF2B1A16), HarvestTheme.Colors.textPrimary)
        assertEquals(Color(0xFF6E524A), HarvestTheme.Colors.textSecondary)
        assertEquals(Color(0xFF8A6E66), HarvestTheme.Colors.textTertiary)
        assertEquals(Color(0xFFFFFFFF), HarvestTheme.Colors.textInverse)
    }

    @Test
    fun `semantic aliases point at the same colors as iOS`() {
        assertEquals(HarvestTheme.Colors.rose, HarvestTheme.Colors.primary)
        assertEquals(HarvestTheme.Colors.roseDeep, HarvestTheme.Colors.primaryDark)
        assertEquals(HarvestTheme.Colors.deepPlum, HarvestTheme.Colors.background)
        assertEquals(HarvestTheme.Colors.wineCard, HarvestTheme.Colors.surface)
        assertEquals(HarvestTheme.Colors.wineBlack, HarvestTheme.Colors.tabBarBackground)
        assertEquals(HarvestTheme.Colors.rose, HarvestTheme.Colors.success)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./gradlew :app:testDebugUnitTest --tests "*HarvestThemeTest*"`
Expected: FAIL — `Unresolved reference: HarvestTheme`.

- [ ] **Step 3: Write `HarvestTheme.kt`**

```kotlin
package com.harvestglass.harvest.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Port of Harvest/Theme/HarvestTheme.swift. Token names and values are
 * identical by design — do not rename them here without renaming them there.
 *
 * Warm light direction: a blush-cream page with a strong red accent.
 * The `wine*` names are historical — they date from the dark wine/plum theme
 * and are referenced by ~300 call sites on iOS, so they were kept and
 * re-valued rather than renamed. Read "wine*" as "surface, deepest to most
 * lifted"; they are light tints now, not darks.
 */
object HarvestTheme {

    object Colors {
        // Core brand palette
        val wineBlack = Color(0xFFE6C6B6)   // nav / tab bars — deepest tint
        val deepPlum = Color(0xFFF0D5C8)    // app background
        val wineCard = Color(0xFFFFF9F5)    // card / glass surface
        val wineRaised = Color(0xFFFFFFFF)  // elevated surface

        /** The one genuine dark: a scrim over user photography. Never a surface. */
        val photoScrim = Color(0xFF2A1714)

        // Reds (brand accent family)
        val rose = Color(0xFFDB2637)
        val roseLight = Color(0xFFEE6A72)
        val roseDeep = Color(0xFFA81C2B)
        val roseBloom = Color(0xFFC94F58)
        val amber = Color(0xFFD97A28)

        // Field greens — The Field / community rooms accent. Field views only.
        val fieldGreen = Color(0xFF2E7D5B)
        /** Despite the name, the DARKER green: used as a foreground on light surfaces. */
        val fieldGreenLight = Color(0xFF246B4C)
        val fieldGreenDeep = Color(0xFF1E5A40)
        val fieldGreenBorder = fieldGreen.copy(alpha = 0.28f)
        val fieldGreenSoft = fieldGreen.copy(alpha = 0.12f)

        // Legacy brand tokens — kept so ported views compile.
        val iconRed = Color(0xFFB81D2A)
        val appleRed = Color(0xFFBE3A34)
        val heartGlow = rose
        val harvestGold = Color(0xFFC07A3C)
        val harvestCream = Color(0xFFF0D5C8)
        val pureWhite = Color(0xFFFFFFFF)
        val black = Color(0xFF000000)

        // Primary
        val primary = rose
        val primaryDark = roseDeep
        val primaryLight = roseLight
        val primarySoft = rose.copy(alpha = 0.10f)
        val blackSurface = wineBlack
        val redSurface = rose
        val outgoingMessageSurface = rose

        // Accent — deeper than roseLight because accent is a FOREGROUND.
        val accent = Color(0xFFC41F2E)
        val accentLight = Color(0xFFE8555F)
        val accentDark = Color(0xFF8E1622)
        val accentSoft = rose.copy(alpha = 0.10f)

        // Backgrounds
        val background = deepPlum
        val surface = wineCard
        val secondary = harvestCream
        val creamSurface = harvestCream

        // Text — warm darks; the page is light.
        val textPrimary = Color(0xFF2B1A16)
        val textSecondary = Color(0xFF6E524A)
        val textTertiary = Color(0xFF8A6E66)
        val textInverse = pureWhite
        val textOnCream = Color(0xFF2B1A16)
        val textOnRedPrimary = pureWhite
        val textOnRedAccent = pureWhite
        /** Historical name: the surfaces it sits on are light now, so it is dark. */
        val textOnBlack = Color(0xFF2B1A16)
        val textOnWhitePrimary = Color(0xFF2B1A16)
        val textOnWhiteSecondary = Color(0xFF2B1A16).copy(alpha = 0.75f)
        val textOnWhiteTertiary = Color(0xFF2B1A16).copy(alpha = 0.55f)
        val whiteFormSurface = Color.White
        val whiteFormBorder = Color(0xFF2B1A16).copy(alpha = 0.12f)

        // Semantic
        val error = Color(0xFFC62828)
        val success = rose
        val warning = Color(0xFFC77700)
        val info = accent

        // UI
        val border = Color(0xFF2B1A16).copy(alpha = 0.12f)
        val divider = Color(0xFF2B1A16).copy(alpha = 0.10f)
        val glassFill = wineCard
        val glassFillStrong = wineRaised
        val fieldFill = wineCard
        val blackFill = black

        // Swipe actions
        val like = rose
        val nope = iconRed
        val superLike = accent

        // Gradients
        val primaryGradient = Brush.linearGradient(listOf(rose, roseDeep))
        /** Sits over photography, so it stays genuinely dark. */
        val overlayGradient = Brush.verticalGradient(
            listOf(Color.Transparent, photoScrim.copy(alpha = 0.65f))
        )
        val splashGradient = Brush.linearGradient(
            listOf(harvestCream, roseLight, rose, roseDeep)
        )
        val iconGradient = Brush.verticalGradient(listOf(rose, roseDeep))
        val glowGradient = Brush.radialGradient(
            listOf(rose.copy(alpha = 0.55f), rose.copy(alpha = 0.12f), Color.Transparent)
        )

        val cardBackground = surface
        val elevatedSurface = wineRaised

        // Form surfaces
        val formBackground = Color(0xFFFFF4EE)
        val formSurface = Color(0xFFFFFFFF)
        val formSurfaceStrong = Color(0xFFF7E7DE)
        val formBorder = Color(0xFF2B1A16).copy(alpha = 0.12f)
        val formAccent = rose
        val tabBarBackground = wineBlack
        val tabBarSelectedBackground = rose
        val tabBarText = textPrimary
    }

    /**
     * iOS declares "Orange Squash" / "DM Serif Display" name tokens but bundles
     * no font files and declares no UIAppFonts key, so those resolve to system
     * fonts at runtime. We mirror the shipped behaviour, not the aspiration.
     */
    object Typography {
        val h1 = TextStyle(fontSize = 28.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Serif)
        val h2 = TextStyle(fontSize = 24.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Serif)
        val h3 = TextStyle(fontSize = 20.sp, fontWeight = FontWeight.Bold)
        val h4 = TextStyle(fontSize = 18.sp, fontWeight = FontWeight.SemiBold)

        val bodyLarge = TextStyle(fontSize = 18.sp, fontWeight = FontWeight.Normal)
        val bodyRegular = TextStyle(fontSize = 16.sp, fontWeight = FontWeight.Normal)
        val bodySmall = TextStyle(fontSize = 14.sp, fontWeight = FontWeight.Normal)
        val caption = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Medium)

        val buttonText = TextStyle(fontSize = 16.sp, fontWeight = FontWeight.SemiBold)

        val display = TextStyle(fontSize = 48.sp, fontWeight = FontWeight.Normal, fontFamily = FontFamily.Serif)
        val sectionTitle = TextStyle(fontSize = 36.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Serif)
        val subsection = TextStyle(fontSize = 22.sp, fontWeight = FontWeight.Bold)
        val cardTitle = TextStyle(fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
    }

    object Spacing {
        val xxs = 2.dp
        val xs = 4.dp
        val sm = 8.dp
        val md = 16.dp
        val lg = 24.dp
        val xl = 32.dp
        val xxl = 48.dp
    }

    object Radius {
        val xs = 4.dp
        val sm = 8.dp
        val md = 12.dp
        val lg = 16.dp
        val xl = 20.dp
        val xxl = 24.dp
        val full = 9999.dp
    }

    /** Durations in milliseconds; iOS declares them in seconds. */
    object AnimationSpec {
        const val FAST = 200
        const val NORMAL = 300
        const val SLOW = 500
    }
}

/**
 * iOS pins `.preferredColorScheme(.light)`, so we ignore [isSystemInDarkTheme]
 * entirely. Material3 is substrate only — call sites read HarvestTheme tokens
 * directly rather than MaterialTheme.colorScheme.
 */
@Composable
fun HarvestAppTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = lightColorScheme(
            primary = HarvestTheme.Colors.primary,
            background = HarvestTheme.Colors.background,
            surface = HarvestTheme.Colors.surface,
            onPrimary = HarvestTheme.Colors.textOnRedPrimary,
            onBackground = HarvestTheme.Colors.textPrimary,
            onSurface = HarvestTheme.Colors.textPrimary,
            error = HarvestTheme.Colors.error
        ),
        content = content
    )
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./gradlew :app:testDebugUnitTest --tests "*HarvestThemeTest*"`
Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/java/com/harvestglass/harvest/ui/theme/HarvestTheme.kt android/app/src/test/java/com/harvestglass/harvest/ui/theme/HarvestThemeTest.kt
git commit -m "feat(android): port HarvestTheme design tokens"
```

---

### Task 3: Shared components

**Files:**
- Create: `ui/theme/HarvestButton.kt`, `ui/components/GlassCard.kt`, `ui/components/GlassButton.kt`, `ui/components/ChipView.kt`, `ui/components/SectionHeader.kt`, `ui/components/GlassBadge.kt`
- Test: `android/app/src/androidTest/java/com/harvestglass/harvest/ui/components/ComponentsTest.kt`

**Interfaces:**
- Consumes: `HarvestTheme` from Task 2.
- Produces:
  - `enum class HarvestButtonKind { PRIMARY, SECONDARY, DESTRUCTIVE, CHIP_SELECTED, CHIP_UNSELECTED }`
  - `@Composable fun HarvestButton(text: String, kind: HarvestButtonKind = HarvestButtonKind.PRIMARY, icon: ImageVector? = null, modifier: Modifier = Modifier, onClick: () -> Unit)`
  - `@Composable fun GlassCard(modifier: Modifier = Modifier, cornerRadius: Dp = HarvestTheme.Radius.xl, padding: Dp = HarvestTheme.Spacing.md, style: GlassCardStyle = GlassCardStyle.DARK, content: @Composable ColumnScope.() -> Unit)` with `enum class GlassCardStyle { DARK, LIGHT }`
  - `@Composable fun GlassButton(title: String, icon: ImageVector? = null, style: HarvestButtonKind = HarvestButtonKind.PRIMARY, modifier: Modifier = Modifier, onClick: () -> Unit)`
  - `@Composable fun ChipView(title: String, isSelected: Boolean = false, lightStyle: Boolean = false, onTap: (() -> Unit)? = null)`
  - `@Composable fun SectionHeader(title: String)`
  - `@Composable fun GlassBadge(text: String, color: Color = HarvestTheme.Colors.textOnBlack)`

- [ ] **Step 1: Write the failing UI test**

```kotlin
package com.harvestglass.harvest.ui.components

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import com.harvestglass.harvest.ui.theme.HarvestAppTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

class ComponentsTest {
    @get:Rule val rule = createComposeRule()

    @Test
    fun glassCardRendersItsContent() {
        rule.setContent { HarvestAppTheme { GlassCard { SectionHeader("Notifications") } } }
        rule.onNodeWithText("NOTIFICATIONS").assertIsDisplayed()
    }

    @Test
    fun chipInvokesOnTap() {
        var taps = 0
        rule.setContent { HarvestAppTheme { ChipView(title = "Calm", onTap = { taps++ }) } }
        rule.onNodeWithText("Calm").performClick()
        assertEquals(1, taps)
    }

    @Test
    fun glassBadgeRendersText() {
        rule.setContent { HarvestAppTheme { GlassBadge(text = "Gold") } }
        rule.onNodeWithText("Gold").assertIsDisplayed()
    }
}
```

Note: `SectionHeader` uppercases its title (iOS uses `.textCase(.uppercase)`), which is why the assertion looks for `NOTIFICATIONS`.

- [ ] **Step 2: Run test to verify it fails**

Run: `./gradlew :app:connectedDebugAndroidTest --tests "*ComponentsTest*"` (emulator must be running)
Expected: FAIL — unresolved references.

- [ ] **Step 3: Implement `HarvestButton.kt`**

Reproduces `HarvestGlassButtonStyle` minus the unreproducible Liquid Glass material: same capsule, same tints, same paddings, same press spring.

```kotlin
package com.harvestglass.harvest.ui.theme

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

enum class HarvestButtonKind { PRIMARY, SECONDARY, DESTRUCTIVE, CHIP_SELECTED, CHIP_UNSELECTED }

private val HarvestButtonKind.isChip: Boolean
    get() = this == HarvestButtonKind.CHIP_SELECTED || this == HarvestButtonKind.CHIP_UNSELECTED

private val HarvestButtonKind.fill: Color
    get() = when (this) {
        HarvestButtonKind.PRIMARY, HarvestButtonKind.CHIP_SELECTED -> HarvestTheme.Colors.rose
        HarvestButtonKind.DESTRUCTIVE -> HarvestTheme.Colors.error
        HarvestButtonKind.SECONDARY -> HarvestTheme.Colors.glassFillStrong
        HarvestButtonKind.CHIP_UNSELECTED -> Color.Transparent
    }

private val HarvestButtonKind.foreground: Color
    get() = when (this) {
        HarvestButtonKind.PRIMARY, HarvestButtonKind.DESTRUCTIVE, HarvestButtonKind.CHIP_SELECTED ->
            HarvestTheme.Colors.textOnRedPrimary
        else -> HarvestTheme.Colors.textPrimary
    }

@Composable
fun HarvestButton(
    text: String,
    kind: HarvestButtonKind = HarvestButtonKind.PRIMARY,
    icon: ImageVector? = null,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    // iOS: .scaleEffect(pressed ? 0.96 : 1) with spring(response: 0.3, dampingFraction: 0.65)
    val scale by animateFloatAsState(
        targetValue = if (pressed) 0.96f else 1f,
        animationSpec = spring(dampingRatio = 0.65f, stiffness = Spring.StiffnessMediumLow),
        label = "pressScale"
    )

    val shape = RoundedCornerShape(percent = 50)
    val hPad = if (kind.isChip) HarvestTheme.Spacing.md else HarvestTheme.Spacing.lg
    val vPad = if (kind.isChip) HarvestTheme.Spacing.sm else 14.dp

    Row(
        horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
        modifier = modifier
            .scale(scale)
            .clip(shape)
            .background(kind.fill, shape)
            .then(
                if (kind == HarvestButtonKind.CHIP_UNSELECTED)
                    Modifier.border(BorderStroke(1.dp, HarvestTheme.Colors.rose.copy(alpha = 0.3f)), shape)
                else Modifier
            )
            .clickable(interactionSource = interaction, indication = null, onClick = onClick)
            .padding(horizontal = hPad, vertical = vPad)
    ) {
        if (icon != null) Icon(icon, contentDescription = null, tint = kind.foreground)
        Text(
            text = text,
            style = if (kind.isChip) HarvestTheme.Typography.bodySmall else HarvestTheme.Typography.buttonText,
            fontWeight = if (kind == HarvestButtonKind.CHIP_UNSELECTED) FontWeight.Normal else FontWeight.SemiBold,
            color = kind.foreground
        )
    }
}
```

Add `import androidx.compose.ui.draw.clip` if the compiler flags `clip` — it lives in `androidx.compose.ui.draw`.

- [ ] **Step 4: Implement the five component files**

`GlassCard.kt`:

```kotlin
package com.harvestglass.harvest.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.harvestglass.harvest.ui.theme.HarvestTheme

enum class GlassCardStyle { DARK, LIGHT }

@Composable
fun GlassCard(
    modifier: Modifier = Modifier,
    cornerRadius: Dp = HarvestTheme.Radius.xl,
    padding: Dp = HarvestTheme.Spacing.md,
    style: GlassCardStyle = GlassCardStyle.DARK,
    content: @Composable ColumnScope.() -> Unit
) {
    val shape = RoundedCornerShape(cornerRadius)
    val fill = if (style == GlassCardStyle.DARK) HarvestTheme.Colors.glassFill else HarvestTheme.Colors.formSurface
    val stroke = if (style == GlassCardStyle.DARK) HarvestTheme.Colors.border else HarvestTheme.Colors.formBorder
    Column(
        modifier = modifier
            .background(fill, shape)
            .border(1.dp, stroke, shape)
            .padding(padding),
        content = content
    )
}
```

`GlassButton.kt`:

```kotlin
package com.harvestglass.harvest.ui.components

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import com.harvestglass.harvest.ui.theme.HarvestButton
import com.harvestglass.harvest.ui.theme.HarvestButtonKind

@Composable
fun GlassButton(
    title: String,
    icon: ImageVector? = null,
    style: HarvestButtonKind = HarvestButtonKind.PRIMARY,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    HarvestButton(text = title, kind = style, icon = icon, modifier = modifier.fillMaxWidth(), onClick = onClick)
}
```

`ChipView.kt`:

```kotlin
package com.harvestglass.harvest.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.harvestglass.harvest.ui.theme.HarvestButton
import com.harvestglass.harvest.ui.theme.HarvestButtonKind
import com.harvestglass.harvest.ui.theme.HarvestTheme

@Composable
fun ChipView(
    title: String,
    isSelected: Boolean = false,
    lightStyle: Boolean = false,
    onTap: (() -> Unit)? = null
) {
    if (!lightStyle) {
        HarvestButton(
            text = title,
            kind = if (isSelected) HarvestButtonKind.CHIP_SELECTED else HarvestButtonKind.CHIP_UNSELECTED,
            onClick = { onTap?.invoke() }
        )
        return
    }

    // Light chips live on cream/white form surfaces, so they keep the solid
    // capsule for contrast rather than translucent glass.
    val shape = RoundedCornerShape(percent = 50)
    Text(
        text = title,
        style = HarvestTheme.Typography.bodySmall,
        fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
        color = if (isSelected) HarvestTheme.Colors.textOnRedPrimary else HarvestTheme.Colors.textPrimary,
        modifier = Modifier
            .background(
                if (isSelected) HarvestTheme.Colors.formAccent else HarvestTheme.Colors.formSurface,
                shape
            )
            .then(if (!isSelected) Modifier.border(1.dp, HarvestTheme.Colors.formBorder, shape) else Modifier)
            .clickable { onTap?.invoke() }
            .padding(horizontal = HarvestTheme.Spacing.md, vertical = HarvestTheme.Spacing.sm)
    )
}
```

`SectionHeader.kt`:

```kotlin
package com.harvestglass.harvest.ui.components

import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.harvestglass.harvest.ui.theme.HarvestTheme
import java.util.Locale

@Composable
fun SectionHeader(title: String) {
    Text(
        text = title.uppercase(Locale.getDefault()),
        style = HarvestTheme.Typography.caption.copy(letterSpacing = 0.8.sp),
        fontWeight = FontWeight.Medium,
        color = HarvestTheme.Colors.textSecondary,
        modifier = Modifier.padding(start = HarvestTheme.Spacing.xs)
    )
}
```

`GlassBadge.kt`:

```kotlin
package com.harvestglass.harvest.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.harvestglass.harvest.ui.theme.HarvestTheme

@Composable
fun GlassBadge(text: String, color: Color = HarvestTheme.Colors.textOnBlack) {
    val shape = RoundedCornerShape(percent = 50)
    Text(
        text = text,
        style = HarvestTheme.Typography.caption,
        fontWeight = FontWeight.SemiBold,
        color = color,
        modifier = Modifier
            .background(HarvestTheme.Colors.formSurfaceStrong, shape)
            .border(1.dp, HarvestTheme.Colors.formBorder, shape)
            .padding(horizontal = HarvestTheme.Spacing.sm, vertical = HarvestTheme.Spacing.xs)
    )
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `./gradlew :app:connectedDebugAndroidTest --tests "*ComponentsTest*"`
Expected: PASS, 3 tests.

- [ ] **Step 6: Commit**

```bash
git add android/app/src/main/java/com/harvestglass/harvest/ui android/app/src/androidTest
git commit -m "feat(android): port shared glass components and button style"
```

---

### Task 4: Supabase client and DI

**Files:**
- Create: `data/SupabaseManager.kt`, `di/AppModule.kt`
- Test: `android/app/src/test/java/com/harvestglass/harvest/data/SupabaseManagerTest.kt`

**Interfaces:**
- Consumes: `Config` from Task 1.
- Produces: `object SupabaseManager { val client: SupabaseClient }` with Postgrest, Auth, Realtime and Storage installed. Hilt `AppModule` providing `SupabaseClient`, `AuthService`, `CommunityService` as `@Singleton`.

- [ ] **Step 1: Write the failing test**

```kotlin
package com.harvestglass.harvest.data

import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.realtime.Realtime
import io.github.jan.supabase.storage.Storage
import org.junit.Assert.assertNotNull
import org.junit.Test

class SupabaseManagerTest {
    @Test
    fun `client installs the four plugins the app uses`() {
        val client = SupabaseManager.client
        assertNotNull(client.pluginManager.getPluginOrNull(Postgrest))
        assertNotNull(client.pluginManager.getPluginOrNull(Auth))
        assertNotNull(client.pluginManager.getPluginOrNull(Realtime))
        assertNotNull(client.pluginManager.getPluginOrNull(Storage))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./gradlew :app:testDebugUnitTest --tests "*SupabaseManagerTest*"`
Expected: FAIL — `Unresolved reference: SupabaseManager`.

- [ ] **Step 3: Implement `SupabaseManager.kt`**

```kotlin
package com.harvestglass.harvest.data

import com.harvestglass.harvest.Config
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.realtime.Realtime
import io.github.jan.supabase.serializer.KotlinXSerializer
import io.github.jan.supabase.storage.Storage
import kotlinx.serialization.json.Json

/** Mirrors Harvest/Services/SupabaseManager.swift. */
object SupabaseManager {
    val client: SupabaseClient by lazy {
        createSupabaseClient(
            supabaseUrl = Config.SUPABASE_URL,
            supabaseKey = Config.SUPABASE_ANON_KEY
        ) {
            // Rows carry columns the slice models don't declare yet; ignoring
            // unknown keys keeps decoding from breaking as the port fans out.
            defaultSerializer = KotlinXSerializer(Json { ignoreUnknownKeys = true })
            install(Postgrest)
            install(Auth) { host = "auth"; scheme = Config.APP_SCHEME }
            install(Realtime)
            install(Storage)
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./gradlew :app:testDebugUnitTest --tests "*SupabaseManagerTest*"`
Expected: PASS.

If the `pluginManager.getPluginOrNull` API differs in 3.0.3, assert instead that `client.auth`, `client.postgrest`, `client.realtime` and `client.storage` accessors do not throw — the point of the test is that all four plugins are installed.

- [ ] **Step 5: Write `di/AppModule.kt`**

```kotlin
package com.harvestglass.harvest.di

import com.harvestglass.harvest.data.SupabaseManager
import com.harvestglass.harvest.data.service.AuthService
import com.harvestglass.harvest.data.service.CommunityService
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import io.github.jan.supabase.SupabaseClient
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object AppModule {
    @Provides @Singleton fun provideClient(): SupabaseClient = SupabaseManager.client
    @Provides @Singleton fun provideAuthService(client: SupabaseClient) = AuthService(client)
    @Provides @Singleton fun provideCommunityService(client: SupabaseClient) = CommunityService(client)
}
```

This will not compile until Tasks 5 and 6 land; write it now and let the next tasks satisfy it, or comment out the two service providers and restore them in Task 6.

- [ ] **Step 6: Commit**

```bash
git add android/app/src/main/java/com/harvestglass/harvest/data android/app/src/main/java/com/harvestglass/harvest/di android/app/src/test
git commit -m "feat(android): Supabase client and Hilt module"
```

---

### Task 5: Data models

**Files:**
- Create: `data/model/Community.kt`, `data/model/UserProfile.kt`
- Test: `android/app/src/test/java/com/harvestglass/harvest/data/model/CommunityTest.kt`

**Interfaces:**
- Consumes: nothing.
- Produces: `@Serializable data class Community(id, slug, name, description, kind, memberCount, displayOrder, imageUrl)`, `CommunityMessage(id, communityId, senderId, content, isRemoved, createdAt, replyToId, mentions)`, `CommunityReaction(messageId, userId, emoji, communityId)` with `companion object { val CURATED_EMOJI: List<String> }`, `CommunityPrompt(id, text)`, `CommunitySender(id, nickname, photos)` with `val photoUrl: String?`, and a slice-subset `UserProfile`.

- [ ] **Step 1: Write the failing test**

Column names must match the Swift `CodingKeys` exactly or Postgrest decoding silently misses.

```kotlin
package com.harvestglass.harvest.data.model

import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class CommunityTest {
    private val json = Json { ignoreUnknownKeys = true }

    @Test
    fun `community decodes snake_case columns`() {
        val row = """
            {"id":"c1","slug":"single-parents","name":"Single Parents","description":"A room",
             "kind":"status","member_count":12,"display_order":2,"image_url":"https://x/y.png"}
        """.trimIndent()
        val c = json.decodeFromString<Community>(row)
        assertEquals("c1", c.id)
        assertEquals("single-parents", c.slug)
        assertEquals(12, c.memberCount)
        assertEquals(2, c.displayOrder)
        assertEquals("https://x/y.png", c.imageUrl)
    }

    @Test
    fun `community tolerates absent optional columns`() {
        val c = json.decodeFromString<Community>("""{"id":"c1","slug":"s","name":"N","kind":"k"}""")
        assertNull(c.description)
        assertNull(c.memberCount)
        assertNull(c.imageUrl)
    }

    @Test
    fun `message decodes reply and mentions`() {
        val row = """
            {"id":"m1","community_id":"c1","sender_id":"u1","content":"hi","is_removed":false,
             "created_at":"2026-08-16T10:00:00.123456+00:00","reply_to_id":"m0","mentions":["u2"]}
        """.trimIndent()
        val m = json.decodeFromString<CommunityMessage>(row)
        assertEquals("c1", m.communityId)
        assertEquals("u1", m.senderId)
        assertEquals(false, m.isRemoved)
        assertEquals("m0", m.replyToId)
        assertEquals(listOf("u2"), m.mentions)
    }

    @Test
    fun `curated emoji matches the DB check constraint`() {
        assertEquals(
            listOf("\uD83C\uDF31", "\uD83D\uDC9A", "\uD83C\uDF3B", "\uD83D\uDE02", "\uD83D\uDC4F", "\uD83E\uDD14"),
            CommunityReaction.CURATED_EMOJI
        )
    }

    @Test
    fun `sender photoUrl is the first photo`() {
        val s = json.decodeFromString<CommunitySender>(
            """{"id":"u1","nickname":"Ada","photos":["a.png","b.png"]}"""
        )
        assertEquals("a.png", s.photoUrl)
    }

    @Test
    fun `sender photoUrl is null when there are no photos`() {
        val s = json.decodeFromString<CommunitySender>("""{"id":"u1","nickname":"Ada","photos":[]}""")
        assertNull(s.photoUrl)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./gradlew :app:testDebugUnitTest --tests "*CommunityTest*"`
Expected: FAIL — unresolved references.

- [ ] **Step 3: Implement `Community.kt`**

```kotlin
package com.harvestglass.harvest.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Mirrors Harvest/Models/Community.swift. */
@Serializable
data class Community(
    val id: String,
    val slug: String,
    val name: String,
    val description: String? = null,
    val kind: String,
    @SerialName("member_count") val memberCount: Int? = null,
    @SerialName("display_order") val displayOrder: Int? = null,
    @SerialName("image_url") val imageUrl: String? = null
)

@Serializable
data class CommunityMessage(
    val id: String,
    @SerialName("community_id") val communityId: String,
    @SerialName("sender_id") val senderId: String,
    val content: String,
    @SerialName("is_removed") val isRemoved: Boolean = false,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("reply_to_id") val replyToId: String? = null,
    val mentions: List<String>? = null
)

/**
 * One emoji reaction by one user on one message. community_id is filled
 * server-side by a trigger; it exists so realtime can filter per room.
 */
@Serializable
data class CommunityReaction(
    @SerialName("message_id") val messageId: String,
    @SerialName("user_id") val userId: String,
    val emoji: String,
    @SerialName("community_id") val communityId: String? = null
) {
    companion object {
        /** The curated set — must match the DB check constraint exactly. */
        val CURATED_EMOJI = listOf("🌱", "💚", "🌻", "😂", "👏", "🤔")
    }
}

@Serializable
data class CommunityPrompt(val id: String, val text: String)

/** Lightweight sender info for community chat (name + avatar). */
@Serializable
data class CommunitySender(
    val id: String,
    val nickname: String? = null,
    val photos: List<String>? = null
) {
    val photoUrl: String? get() = photos?.firstOrNull()
}
```

- [ ] **Step 4: Implement the slice subset of `UserProfile.kt`**

Read `Harvest/Models/UserProfile.swift` and port only the fields the slice reads — `id`, `email`, `nickname`, `age`, `gender`, `photos`, `onboardingCompleted`, `isBanned` — each with `@SerialName` matching the Swift `CodingKeys`, all nullable with defaults except `id`. The remaining fields port with their owning features in P2.

```kotlin
package com.harvestglass.harvest.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Slice subset of Harvest/Models/UserProfile.swift. Remaining fields port
 * with the features that read them.
 */
@Serializable
data class UserProfile(
    val id: String,
    val email: String? = null,
    val nickname: String? = null,
    val age: Int? = null,
    val gender: String? = null,
    val photos: List<String>? = null,
    @SerialName("onboarding_completed") val onboardingCompleted: Boolean? = null,
    @SerialName("is_banned") val isBanned: Boolean? = null
)
```

Confirm each `@SerialName` against the Swift `CodingKeys` before moving on.

- [ ] **Step 5: Run tests to verify they pass**

Run: `./gradlew :app:testDebugUnitTest --tests "*CommunityTest*"`
Expected: PASS, 6 tests.

- [ ] **Step 6: Commit**

```bash
git add android/app/src/main/java/com/harvestglass/harvest/data/model android/app/src/test
git commit -m "feat(android): port Community and UserProfile models"
```

---

### Task 6: AuthService and AuthViewModel

**Files:**
- Create: `data/service/AuthService.kt`, `ui/auth/AuthViewModel.kt`
- Test: `android/app/src/test/java/com/harvestglass/harvest/ui/auth/AuthViewModelTest.kt`

**Interfaces:**
- Consumes: `SupabaseClient` (Task 4), `UserProfile` (Task 5).
- Produces:
  - `class AuthService(private val client: SupabaseClient)` with `suspend fun signUp(email: String, password: String): String?` (returns lowercased user id), `suspend fun signIn(email: String, password: String): String`, `suspend fun signOut()`, `suspend fun currentUserId(): String?`, `fun currentUserIdOrNull(): String?`, `fun sessionStatus(): Flow<SessionStatus>`, `suspend fun loadProfile(userId: String): UserProfile?`.
  - `data class AuthUiState(val isLoading: Boolean = true, val isAuthenticated: Boolean = false, val profile: UserProfile? = null, val currentUserId: String? = null, val error: String? = null)` with `val needsOnboarding: Boolean`.
  - `@HiltViewModel class AuthViewModel @Inject constructor(...)` exposing `val state: StateFlow<AuthUiState>`, `fun checkSession()`, `fun login(email, password)`, `fun register(email, password)`, `fun logout()`.

- [ ] **Step 1: Write the failing test**

The critical behaviour to lock down is `needsOnboarding`, which gates the whole root navigation and is easy to get subtly wrong.

```kotlin
package com.harvestglass.harvest.ui.auth

import com.harvestglass.harvest.data.model.UserProfile
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AuthViewModelTest {

    @Test
    fun `no profile needs onboarding`() {
        assertTrue(AuthUiState(profile = null).needsOnboarding)
    }

    @Test
    fun `completed flag alone satisfies onboarding`() {
        val p = UserProfile(id = "u1", onboardingCompleted = true)
        assertFalse(AuthUiState(profile = p).needsOnboarding)
    }

    @Test
    fun `full profile without the flag does not need onboarding`() {
        // iOS: !completed AND (age == nil || gender == nil || photos.isEmpty)
        val p = UserProfile(id = "u1", age = 33, gender = "female", photos = listOf("a.png"))
        assertFalse(AuthUiState(profile = p).needsOnboarding)
    }

    @Test
    fun `missing age needs onboarding`() {
        val p = UserProfile(id = "u1", gender = "female", photos = listOf("a.png"))
        assertTrue(AuthUiState(profile = p).needsOnboarding)
    }

    @Test
    fun `empty photos needs onboarding`() {
        val p = UserProfile(id = "u1", age = 33, gender = "female", photos = emptyList())
        assertTrue(AuthUiState(profile = p).needsOnboarding)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./gradlew :app:testDebugUnitTest --tests "*AuthViewModelTest*"`
Expected: FAIL — `Unresolved reference: AuthUiState`.

- [ ] **Step 3: Implement `AuthService.kt`**

```kotlin
package com.harvestglass.harvest.data.service

import com.harvestglass.harvest.data.model.UserProfile
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.builtin.Email
import io.github.jan.supabase.auth.status.SessionStatus
import io.github.jan.supabase.postgrest.postgrest
import kotlinx.coroutines.flow.Flow

/** Mirrors Harvest/Services/AuthService.swift. */
class AuthService(private val client: SupabaseClient) {

    /** iOS lowercases the UUID everywhere; RLS comparisons depend on it. */
    private fun String.normalizedId() = lowercase()

    suspend fun signUp(email: String, password: String): String? {
        val user = client.auth.signUpWith(Email) {
            this.email = email
            this.password = password
        }
        return user?.id?.normalizedId()
    }

    suspend fun signIn(email: String, password: String): String {
        client.auth.signInWith(Email) {
            this.email = email
            this.password = password
        }
        return requireNotNull(currentUserId()) { "Sign-in returned no session" }
    }

    suspend fun signOut() = client.auth.signOut()

    fun currentUserIdOrNull(): String? = client.auth.currentUserOrNull()?.id?.normalizedId()

    suspend fun currentUserId(): String? = currentUserIdOrNull()

    fun sessionStatus(): Flow<SessionStatus> = client.auth.sessionStatus

    suspend fun loadProfile(userId: String): UserProfile? =
        client.postgrest.from("users")
            .select { filter { eq("id", userId) } }
            .decodeSingleOrNull<UserProfile>()
}
```

- [ ] **Step 4: Implement `AuthViewModel.kt`**

```kotlin
package com.harvestglass.harvest.ui.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.harvestglass.harvest.data.model.UserProfile
import com.harvestglass.harvest.data.service.AuthService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class AuthUiState(
    val isLoading: Boolean = true,
    val isAuthenticated: Boolean = false,
    val profile: UserProfile? = null,
    val currentUserId: String? = null,
    val error: String? = null
) {
    /**
     * Mirrors AuthViewModel.swift exactly:
     *   onboardingCompleted != true && (age == nil || gender == nil || photos.isEmpty)
     */
    val needsOnboarding: Boolean
        get() {
            val p = profile ?: return true
            return p.onboardingCompleted != true &&
                (p.age == null || p.gender == null || p.photos.isNullOrEmpty())
        }
}

@HiltViewModel
class AuthViewModel @Inject constructor(
    private val authService: AuthService
) : ViewModel() {

    private val _state = MutableStateFlow(AuthUiState())
    val state: StateFlow<AuthUiState> = _state.asStateFlow()

    fun checkSession() = viewModelScope.launch {
        _state.update { it.copy(isLoading = true) }
        val userId = runCatching { authService.currentUserId() }.getOrNull()
        if (userId == null) {
            _state.update { it.copy(isLoading = false, isAuthenticated = false) }
            return@launch
        }
        val profile = runCatching { authService.loadProfile(userId) }.getOrNull()
        _state.update {
            it.copy(isLoading = false, isAuthenticated = true, currentUserId = userId, profile = profile)
        }
    }

    fun login(email: String, password: String) = viewModelScope.launch {
        _state.update { it.copy(isLoading = true, error = null) }
        runCatching { authService.signIn(email, password) }
            .onSuccess { userId ->
                val profile = runCatching { authService.loadProfile(userId) }.getOrNull()
                _state.update {
                    it.copy(isLoading = false, isAuthenticated = true, currentUserId = userId, profile = profile)
                }
            }
            .onFailure { e -> _state.update { it.copy(isLoading = false, error = e.message) } }
    }

    fun register(email: String, password: String) = viewModelScope.launch {
        _state.update { it.copy(isLoading = true, error = null) }
        runCatching { authService.signUp(email, password) }
            .onSuccess { userId ->
                // iOS also creates the profile row and initializes the
                // subscription here; both port with their features in P2.
                _state.update {
                    it.copy(isLoading = false, isAuthenticated = userId != null, currentUserId = userId)
                }
            }
            .onFailure { e -> _state.update { it.copy(isLoading = false, error = e.message) } }
    }

    fun logout() = viewModelScope.launch {
        runCatching { authService.signOut() }
        _state.value = AuthUiState(isLoading = false, isAuthenticated = false)
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `./gradlew :app:testDebugUnitTest --tests "*AuthViewModelTest*"`
Expected: PASS, 5 tests.

- [ ] **Step 6: Restore the `AuthService` provider in `di/AppModule.kt` if it was commented out, then build**

Run: `./gradlew :app:assembleDebug`
Expected: BUILD SUCCESSFUL.

- [ ] **Step 7: Commit**

```bash
git add android/app/src/main/java/com/harvestglass/harvest android/app/src/test
git commit -m "feat(android): port AuthService and AuthViewModel"
```

---

### Task 7: Login screen and root gating

**Files:**
- Create: `ui/auth/LoginScreen.kt`, `ui/LaunchScreen.kt`, `ui/HarvestApp.kt`
- Modify: `MainActivity.kt`
- Test: `android/app/src/androidTest/java/com/harvestglass/harvest/ui/auth/LoginScreenTest.kt`

**Interfaces:**
- Consumes: `AuthViewModel`, `AuthUiState` (Task 6), components (Task 3), theme (Task 2).
- Produces: `@Composable fun LoginScreen(state: AuthUiState, onLogin: (String, String) -> Unit, onRegister: (String, String) -> Unit)`, `@Composable fun LaunchScreen()`, `@Composable fun HarvestApp()`.

- [ ] **Step 1: Read the iOS source**

Read `Harvest/Views/Auth/LoginView.swift` in full (238 lines) and reproduce its layout, copy strings, field order, validation, and the sign-in/sign-up mode toggle. Do not invent copy — every user-visible string must match the Swift file verbatim.

- [ ] **Step 2: Write the failing UI test**

```kotlin
package com.harvestglass.harvest.ui.auth

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import com.harvestglass.harvest.ui.theme.HarvestAppTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

class LoginScreenTest {
    @get:Rule val rule = createComposeRule()

    @Test
    fun submittingCredentialsCallsOnLogin() {
        var captured: Pair<String, String>? = null
        rule.setContent {
            HarvestAppTheme {
                LoginScreen(
                    state = AuthUiState(isLoading = false),
                    onLogin = { e, p -> captured = e to p },
                    onRegister = { _, _ -> }
                )
            }
        }
        rule.onNodeWithText("Email").performTextInput("ada@example.com")
        rule.onNodeWithText("Password").performTextInput("hunter2")
        rule.onNodeWithText("Sign In").performClick()
        assertEquals("ada@example.com" to "hunter2", captured)
    }

    @Test
    fun errorFromStateIsShown() {
        rule.setContent {
            HarvestAppTheme {
                LoginScreen(
                    state = AuthUiState(isLoading = false, error = "Invalid login credentials"),
                    onLogin = { _, _ -> }, onRegister = { _, _ -> }
                )
            }
        }
        rule.onNodeWithText("Invalid login credentials").assertIsDisplayed()
    }
}
```

Adjust the label and button strings to whatever `LoginView.swift` actually uses — the test must assert the real copy.

- [ ] **Step 3: Run test to verify it fails**

Run: `./gradlew :app:connectedDebugAndroidTest --tests "*LoginScreenTest*"`
Expected: FAIL — unresolved reference.

- [ ] **Step 4: Implement `LoginScreen.kt`**

A stateless composable taking `AuthUiState` plus two callbacks, holding only the email/password/mode fields in `remember { mutableStateOf(...) }`. Background `HarvestTheme.Colors.background`, primary CTA via `GlassButton(style = HarvestButtonKind.PRIMARY)`, error text in `HarvestTheme.Colors.error`, spinner while `state.isLoading`.

- [ ] **Step 5: Implement `LaunchScreen.kt`**

Port `LaunchScreenView` from `HarvestApp.swift`: the splash gradient behind a centered wordmark at 240.dp width, with the 2.4-second ease-in-out scale pulse from 1.0 to 1.02, reversing and repeating forever. Copy `Splash Page Gradient` and `Harvest_Wordmark_Black` out of `Harvest/Assets.xcassets/` into `android/app/src/main/res/drawable-nodpi/`.

- [ ] **Step 6: Implement `HarvestApp.kt` and wire `MainActivity`**

```kotlin
package com.harvestglass.harvest.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.hilt.navigation.compose.hiltViewModel
import com.harvestglass.harvest.ui.auth.AuthViewModel
import com.harvestglass.harvest.ui.auth.LoginScreen

/** Mirrors the root gating in Harvest/HarvestApp.swift. */
@Composable
fun HarvestApp(authViewModel: AuthViewModel = hiltViewModel()) {
    val state by authViewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) { authViewModel.checkSession() }

    when {
        state.isLoading -> LaunchScreen()
        !state.isAuthenticated -> LoginScreen(
            state = state,
            onLogin = authViewModel::login,
            onRegister = authViewModel::register
        )
        // Onboarding ports in P2; until then a completed-profile user goes
        // straight to the tabs and an incomplete one is told to finish on iOS.
        state.needsOnboarding -> OnboardingPlaceholderScreen(onSignOut = authViewModel::logout)
        else -> MainTabScreen(state = state, onSignOut = authViewModel::logout)
    }
}
```

Write `OnboardingPlaceholderScreen` as a `GlassCard` reading "Finish setting up your profile in the iOS app for now." with a sign-out button. It is replaced wholesale by the real onboarding port in P2 — this is a deliberate, labelled stub, not a gap.

`MainActivity.kt` becomes:

```kotlin
setContent { HarvestAppTheme { HarvestApp() } }
```

- [ ] **Step 7: Run tests and the app**

Run: `./gradlew :app:connectedDebugAndroidTest --tests "*LoginScreenTest*"` — expect PASS.
Then `./gradlew :app:installDebug` and sign in with a real account. Expected: splash, then the login form, then the placeholder or tab shell.

- [ ] **Step 8: Commit**

```bash
git add android/app/src/main android/app/src/androidTest
git commit -m "feat(android): login screen, launch screen, and root gating"
```

---

### Task 8: Main tab shell

**Files:**
- Create: `ui/MainTabScreen.kt`
- Test: `android/app/src/androidTest/java/com/harvestglass/harvest/ui/MainTabScreenTest.kt`

**Interfaces:**
- Consumes: `AuthUiState` (Task 6), theme (Task 2).
- Produces: `@Composable fun MainTabScreen(state: AuthUiState, onSignOut: () -> Unit)`, `enum class HarvestTab(val title: String, val icon: ImageVector)` with entries in iOS order — `SOIL("Soil")`, `FIELD("The Field")`, `GARDENER("Gardener")`, `SEEDS("Seeds")`, `PROFILE("Profile")` — and `fun deepLinkTab(link: String): HarvestTab?`.

- [ ] **Step 1: Write the failing test**

Deep-link routing is pure logic lifted from `MainTabView.handleDeepLink`, so it gets a unit test rather than a UI test. Put this in `src/test/`.

```kotlin
package com.harvestglass.harvest.ui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class DeepLinkTest {
    @Test fun chatOpensSeeds() = assertEquals(HarvestTab.SEEDS, deepLinkTab("chat:abc"))
    @Test fun seedOpensSeeds() = assertEquals(HarvestTab.SEEDS, deepLinkTab("seed:abc"))
    @Test fun bareSeedsOpensSeeds() = assertEquals(HarvestTab.SEEDS, deepLinkTab("seeds"))
    @Test fun matchOpensSeeds() = assertEquals(HarvestTab.SEEDS, deepLinkTab("match:abc"))
    @Test fun gardenerOpensGardener() = assertEquals(HarvestTab.GARDENER, deepLinkTab("gardener"))
    @Test fun communityOpensField() = assertEquals(HarvestTab.FIELD, deepLinkTab("community:abc"))
    @Test fun unknownLinkChangesNothing() = assertNull(deepLinkTab("nonsense"))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./gradlew :app:testDebugUnitTest --tests "*DeepLinkTest*"`
Expected: FAIL — unresolved reference.

- [ ] **Step 3: Implement `MainTabScreen.kt`**

`HarvestTab` uses `material-icons-extended` as the nearest equivalents to the SF Symbols in `MainTabView.swift`: Soil `Icons.Filled.Favorite`, The Field `Icons.Filled.Eco`, Gardener `Icons.Filled.Spa`, Seeds `Icons.Filled.Chat`, Profile `Icons.Filled.Person`.

```kotlin
fun deepLinkTab(link: String): HarvestTab? = when {
    link.startsWith("chat:") -> HarvestTab.SEEDS
    link.startsWith("seed:") || link == "seeds" || link.startsWith("match:") -> HarvestTab.SEEDS
    link == "gardener" -> HarvestTab.GARDENER
    link.startsWith("community:") -> HarvestTab.FIELD
    else -> null
}
```

The `Scaffold` uses a `NavigationBar` with `containerColor = HarvestTheme.Colors.tabBarBackground` (`wineBlack`), selected icon/label `HarvestTheme.Colors.rose`, unselected `HarvestTheme.Colors.textTertiary` — matching the `UITabBarAppearance` block in `MainTabView.swift`. **Initial selection is `FIELD` (index 1)**, as iOS does. Only `FIELD` has real content in this phase; the other four render a centered "Coming in a later phase" placeholder plus, on `PROFILE`, a sign-out button wired to `onSignOut`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `./gradlew :app:testDebugUnitTest --tests "*DeepLinkTest*"`
Expected: PASS, 7 tests.

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/java/com/harvestglass/harvest/ui/MainTabScreen.kt android/app/src/test
git commit -m "feat(android): main tab shell with deep-link routing"
```

---

### Task 9: CommunityService

**Files:**
- Create: `data/service/CommunityService.kt`
- Test: `android/app/src/test/java/com/harvestglass/harvest/data/service/CommunityServiceTest.kt`

**Interfaces:**
- Consumes: `SupabaseClient` (Task 4), models (Task 5).
- Produces: `class CommunityService(private val client: SupabaseClient)` with `suspend fun availableCommunities(userId: String): List<Community>`, `joinedCommunityIds(userId: String): Set<String>`, `join(communityId, userId)`, `leave(communityId, userId)`, `messagesPage(communityId: String, before: String? = null, limit: Int = 50): List<CommunityMessage>`, `messagesByIds(ids: List<String>): List<CommunityMessage>`, `post(communityId, senderId, content, replyToId: String? = null, mentions: List<String> = emptyList()): CommunityMessage?`, `senderProfiles(ids: List<String>): List<CommunitySender>`, `reactions(messageIds: List<String>): List<CommunityReaction>`, `addReaction(messageId, userId, emoji)`, `removeReaction(messageId, userId, emoji)`, `members(communityId): List<CommunitySender>`, `prompts(communityId): List<CommunityPrompt>`, `fun subscribeMessages(communityId: String): Flow<CommunityMessage>`, `fun subscribeReactions(communityId: String): Flow<ReactionEvent>` where `sealed interface ReactionEvent { data class Added(val reaction: CommunityReaction); data class Removed(val reaction: CommunityReaction) }`.

- [ ] **Step 1: Write the failing test**

Network calls are not unit-testable without a live backend, so the unit test covers the guard clauses that `CommunityService.swift` implements — the empty-list early returns that prevent malformed `in.()` queries.

```kotlin
package com.harvestglass.harvest.data.service

import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertTrue
import org.junit.Test

class CommunityServiceTest {
    private val service = CommunityService(mockk(relaxed = true))

    @Test
    fun `messagesByIds short-circuits on an empty list`() = runTest {
        assertTrue(service.messagesByIds(emptyList()).isEmpty())
    }

    @Test
    fun `senderProfiles short-circuits on an empty list`() = runTest {
        assertTrue(service.senderProfiles(emptyList()).isEmpty())
    }

    @Test
    fun `reactions short-circuits on an empty list`() = runTest {
        assertTrue(service.reactions(emptyList()).isEmpty())
    }
}
```

These pass only if the guards run *before* any client call — with a relaxed mock, a missing guard throws or returns a mock value rather than an empty list.

- [ ] **Step 2: Run test to verify it fails**

Run: `./gradlew :app:testDebugUnitTest --tests "*CommunityServiceTest*"`
Expected: FAIL — unresolved reference.

- [ ] **Step 3: Implement `CommunityService.kt`**

Port method-for-method from `Harvest/Services/CommunityService.swift`. Key details that must carry over:

- `availableCommunities` calls the **RPC** `available_communities` with param `p_user`, not a table select.
- `joinedCommunityIds` selects `community_id` from `community_members` filtered `user_id = userId` and `status = "active"`.
- `messagesPage` filters `community_id` and `is_removed = false`, applies `lt("created_at", before)` when `before != null`, orders `created_at` **descending**, limit 50.
- `messagesByIds` deliberately **includes removed rows** so the UI can render "Message removed" for quoted replies.
- `post` inserts and selects back the inserted row so the sender sees the message without waiting for the realtime echo.
- `addReaction` upserts `(message_id, user_id, emoji)` and **must never send `community_id`** — a DB trigger fills it.
- `members` selects the nested shape `users(id, nickname, photos)` from `community_members` and maps out the nested object.
- `prompts` uses `or("community_id.eq.$communityId,community_id.is.null")` with `is_active = true`, ordered by `display_order` ascending.
- `subscribeMessages` opens channel `community:$communityId` on `postgresChangeFlow<PostgresAction.Insert>` for table `community_messages` filtered `community_id=eq.$communityId`, decoding each record to `CommunityMessage`.
- `subscribeReactions` opens channel `community-reactions:$communityId`; INSERTs are server-filtered by `community_id`, DELETEs are **not filterable** and carry only primary-key columns under RLS — that is sufficient, because removal matches on `(messageId, userId, emoji)` and events for unloaded messages no-op. Preserve that comment.

Use `flow { ... }` wrapping `channel.postgresChangeFlow` and `channel.subscribe()`, emitting decoded records; expose `Flow` rather than the callback shape the Swift version uses, since the Kotlin caller collects in a coroutine.

- [ ] **Step 4: Run tests to verify they pass**

Run: `./gradlew :app:testDebugUnitTest --tests "*CommunityServiceTest*"`
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/java/com/harvestglass/harvest/data/service/CommunityService.kt android/app/src/test
git commit -m "feat(android): port CommunityService"
```

---

### Task 10: FieldViewModel

**Files:**
- Create: `ui/field/FieldViewModel.kt`
- Test: `android/app/src/test/java/com/harvestglass/harvest/ui/field/FieldViewModelTest.kt`

**Interfaces:**
- Consumes: `CommunityService` (Task 9), `Community` (Task 5).
- Produces: `data class FieldUiState(val available: List<Community> = emptyList(), val joinedIds: Set<String> = emptySet(), val isLoading: Boolean = false, val error: String? = null)` with `fun isJoined(c: Community): Boolean`; `@HiltViewModel class FieldViewModel` exposing `val state: StateFlow<FieldUiState>`, `fun load(userId: String)`, `fun toggleJoin(community: Community, userId: String)`.

- [ ] **Step 1: Write the failing test**

```kotlin
package com.harvestglass.harvest.ui.field

import com.harvestglass.harvest.data.model.Community
import com.harvestglass.harvest.data.service.CommunityService
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.test.*
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class FieldViewModelTest {
    private val service: CommunityService = mockk()
    private lateinit var vm: FieldViewModel

    private val room = Community(id = "c1", slug = "s", name = "Room", kind = "status")

    @Before fun setUp() { Dispatchers.setMain(StandardTestDispatcher()) }
    @After fun tearDown() { Dispatchers.resetMain() }

    @Test
    fun `load populates available rooms and joined ids`() = runTest {
        coEvery { service.availableCommunities("u1") } returns listOf(room)
        coEvery { service.joinedCommunityIds("u1") } returns setOf("c1")
        vm = FieldViewModel(service)

        vm.load("u1")
        advanceUntilIdle()

        assertEquals(listOf(room), vm.state.value.available)
        assertTrue(vm.state.value.isJoined(room))
        assertFalse(vm.state.value.isLoading)
    }

    @Test
    fun `toggleJoin on a joined room leaves and drops the id`() = runTest {
        coEvery { service.availableCommunities("u1") } returns listOf(room)
        coEvery { service.joinedCommunityIds("u1") } returns setOf("c1")
        coEvery { service.leave("c1", "u1") } returns Unit
        vm = FieldViewModel(service)
        vm.load("u1"); advanceUntilIdle()

        vm.toggleJoin(room, "u1"); advanceUntilIdle()

        coVerify(exactly = 1) { service.leave("c1", "u1") }
        assertFalse(vm.state.value.isJoined(room))
    }

    @Test
    fun `toggleJoin on an unjoined room joins and adds the id`() = runTest {
        coEvery { service.availableCommunities("u1") } returns listOf(room)
        coEvery { service.joinedCommunityIds("u1") } returns emptySet()
        coEvery { service.join("c1", "u1") } returns Unit
        vm = FieldViewModel(service)
        vm.load("u1"); advanceUntilIdle()

        vm.toggleJoin(room, "u1"); advanceUntilIdle()

        coVerify(exactly = 1) { service.join("c1", "u1") }
        assertTrue(vm.state.value.isJoined(room))
    }

    @Test
    fun `load surfaces the error message and clears loading`() = runTest {
        coEvery { service.availableCommunities("u1") } throws RuntimeException("boom")
        coEvery { service.joinedCommunityIds("u1") } returns emptySet()
        vm = FieldViewModel(service)

        vm.load("u1"); advanceUntilIdle()

        assertEquals("boom", vm.state.value.error)
        assertFalse(vm.state.value.isLoading)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./gradlew :app:testDebugUnitTest --tests "*FieldViewModelTest*"`
Expected: FAIL — unresolved reference.

- [ ] **Step 3: Implement `FieldViewModel.kt`**

Mirror `FieldViewModel.swift`, including its concurrency: iOS runs `availableCommunities` and `joinedCommunityIds` concurrently via `async let`, so use `coroutineScope { val a = async {...}; val b = async {...}; a.await() to b.await() }`. `isLoading` is set true on entry and false on exit **including on failure** (the Swift `defer`).

```kotlin
@HiltViewModel
class FieldViewModel @Inject constructor(
    private val service: CommunityService
) : ViewModel() {

    private val _state = MutableStateFlow(FieldUiState())
    val state: StateFlow<FieldUiState> = _state.asStateFlow()

    fun load(userId: String) = viewModelScope.launch {
        _state.update { it.copy(isLoading = true) }
        try {
            coroutineScope {
                val available = async { service.availableCommunities(userId) }
                val joined = async { service.joinedCommunityIds(userId) }
                val a = available.await()
                val j = joined.await()
                _state.update { it.copy(available = a, joinedIds = j) }
            }
        } catch (e: Exception) {
            _state.update { it.copy(error = e.message) }
        } finally {
            _state.update { it.copy(isLoading = false) }
        }
    }

    fun toggleJoin(community: Community, userId: String) = viewModelScope.launch {
        try {
            if (_state.value.joinedIds.contains(community.id)) {
                service.leave(community.id, userId)
                _state.update { it.copy(joinedIds = it.joinedIds - community.id) }
            } else {
                service.join(community.id, userId)
                _state.update { it.copy(joinedIds = it.joinedIds + community.id) }
            }
        } catch (e: Exception) {
            _state.update { it.copy(error = e.message) }
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `./gradlew :app:testDebugUnitTest --tests "*FieldViewModelTest*"`
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/java/com/harvestglass/harvest/ui/field android/app/src/test
git commit -m "feat(android): port FieldViewModel"
```

---

### Task 11: Field screen

**Files:**
- Create: `ui/field/FieldScreen.kt`, `ui/field/EventsComingSoonBanner.kt`
- Modify: `ui/MainTabScreen.kt` — replace the `FIELD` placeholder with `FieldScreen`
- Test: `android/app/src/androidTest/java/com/harvestglass/harvest/ui/field/FieldScreenTest.kt`

**Interfaces:**
- Consumes: `FieldUiState`, `FieldViewModel` (Task 10), `Community` (Task 5), components (Task 3).
- Produces: `@Composable fun FieldScreen(userId: String, onOpenRoom: (Community) -> Unit, viewModel: FieldViewModel = hiltViewModel())`, the stateless `@Composable fun FieldContent(state: FieldUiState, onToggle: (Community) -> Unit, onOpenRoom: (Community) -> Unit)` that `FieldScreen` delegates to, and a private `CommunityCard`.

- [ ] **Step 1: Read the iOS source**

Read `Harvest/Views/Field/FieldView.swift` (194 lines) and `EventsComingSoonBanner.swift`. All copy is verbatim: header "Join the spaces where you're hoping to grow connection.", empty state "No spaces yet" / "Update your relationship status in Profile to unlock connection spaces.", the member-count label pluralisation `"$count member" + if (count == 1) "" else "s"`, and "Tap to open room".

- [ ] **Step 2: Write the failing UI test**

```kotlin
package com.harvestglass.harvest.ui.field

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import com.harvestglass.harvest.data.model.Community
import com.harvestglass.harvest.ui.theme.HarvestAppTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

class FieldScreenTest {
    @get:Rule val rule = createComposeRule()

    private val joined = Community(id = "c1", slug = "s1", name = "Single Parents", kind = "status", memberCount = 1)
    private val notJoined = Community(id = "c2", slug = "s2", name = "New Here", kind = "status", memberCount = 4)

    @Test
    fun emptyStateShowsWhenThereAreNoRooms() {
        rule.setContent {
            HarvestAppTheme { FieldContent(FieldUiState(isLoading = false), {}, {}) }
        }
        rule.onNodeWithText("No spaces yet").assertIsDisplayed()
    }

    @Test
    fun memberCountIsSingularForOne() {
        rule.setContent {
            HarvestAppTheme {
                FieldContent(FieldUiState(available = listOf(joined), joinedIds = setOf("c1")), {}, {})
            }
        }
        rule.onNodeWithText("1 member").assertIsDisplayed()
    }

    @Test
    fun memberCountIsPluralForMany() {
        rule.setContent {
            HarvestAppTheme { FieldContent(FieldUiState(available = listOf(notJoined)), {}, {}) }
        }
        rule.onNodeWithText("4 members").assertIsDisplayed()
    }

    @Test
    fun joiningAnUnjoinedRoomInvokesToggle() {
        var toggled: Community? = null
        rule.setContent {
            HarvestAppTheme {
                FieldContent(FieldUiState(available = listOf(notJoined)), onToggle = { toggled = it }, onOpenRoom = {})
            }
        }
        rule.onNodeWithText("Join").performClick()
        assertEquals(notJoined, toggled)
    }

    @Test
    fun tappingAJoinedRoomOpensIt() {
        var opened: Community? = null
        rule.setContent {
            HarvestAppTheme {
                FieldContent(
                    FieldUiState(available = listOf(joined), joinedIds = setOf("c1")),
                    onToggle = {}, onOpenRoom = { opened = it }
                )
            }
        }
        rule.onNodeWithText("Single Parents").performClick()
        assertEquals(joined, opened)
    }
}
```

Split the screen into a stateful `FieldScreen` (owns the ViewModel) and a stateless `FieldContent(state, onToggle, onOpenRoom)` so the UI is testable without Hilt.

- [ ] **Step 3: Run test to verify it fails**

Run: `./gradlew :app:connectedDebugAndroidTest --tests "*FieldScreenTest*"`
Expected: FAIL — unresolved reference.

- [ ] **Step 4: Implement `FieldScreen.kt`**

Structure mirroring `FieldView.swift`: a `LazyColumn` on `HarvestTheme.Colors.background` with `Spacing.md` padding and `Spacing.md` item spacing, holding the banner, the header text, and one `CommunityCard` per room. Pull-to-refresh calls `viewModel.load(userId)`, matching iOS's `.refreshable`.

`CommunityCard` details that must carry over exactly:
- Card surface `wineCard`, clipped to `Radius.xl`, 1.dp border — `fieldGreenBorder` when joined, `border` when not.
- A 110.dp banner: Coil `AsyncImage` of `community.imageUrl` cropped to fill, or a `wineRaised` placeholder with a leaf icon tinted `fieldGreen.copy(alpha = 0.4f)`.
- A top-to-bottom gradient over the banner from transparent to `photoScrim.copy(alpha = 0.85f)` — note this is **0.85**, not the 0.65 used by `overlayGradient`.
- Room name over the scrim in `Typography.h4`, colored `textInverse` (stays white — it sits on the photo, not the page).
- Description in `bodySmall`/`textSecondary`; member count and "Tap to open room" in `caption`/`accent`.
- Joined cards are clickable (opening the room) and show a chevron; unjoined cards show a rose capsule "Join" button with `textOnRedPrimary` text.

- [ ] **Step 5: Wire it into the tab shell**

In `MainTabScreen.kt`, replace the `FIELD` placeholder with `FieldScreen(userId = state.currentUserId.orEmpty(), onOpenRoom = { ... })`, navigating to the chat route added in Task 13.

- [ ] **Step 6: Run tests to verify they pass**

Run: `./gradlew :app:connectedDebugAndroidTest --tests "*FieldScreenTest*"`
Expected: PASS, 5 tests.

- [ ] **Step 7: Commit**

```bash
git add android/app/src/main/java/com/harvestglass/harvest/ui android/app/src/androidTest
git commit -m "feat(android): port The Field room list"
```

---

### Task 12: CommunityChatViewModel

**Files:**
- Create: `ui/field/CommunityChatViewModel.kt`
- Test: `android/app/src/test/java/com/harvestglass/harvest/ui/field/CommunityChatViewModelTest.kt`

**Interfaces:**
- Consumes: `CommunityService` (Task 9), models (Task 5).
- Produces: `data class CommunityChatUiState(val messages: List<CommunityMessage> = emptyList(), val senders: Map<String, CommunitySender> = emptyMap(), val reactions: Map<String, List<CommunityReaction>> = emptyMap(), val isLoading: Boolean = false, val isSending: Boolean = false, val error: String? = null)`; `@HiltViewModel class CommunityChatViewModel` exposing `val state: StateFlow<CommunityChatUiState>`, `fun start(communityId: String, userId: String)`, `fun send(content: String, replyToId: String? = null, mentions: List<String> = emptyList())`, `fun loadOlder()`, `fun toggleReaction(messageId: String, emoji: String)`, and `override fun onCleared()` closing the realtime channels.

- [ ] **Step 1: Read the iOS source**

Read `Harvest/ViewModels/CommunityChatViewModel.swift` (355 lines) in full before writing anything. It is the most behaviour-dense file in the slice: paging, realtime merge, de-duplication of the echo against the optimistic insert, sender hydration, reaction bulk-loading, and reply-preview backfill via `messagesByIds`.

Note commit `bd4528a` ("fix(chat): parse Postgres microsecond timestamps") — `created_at` arrives with microsecond precision, which `java.time.OffsetDateTime.parse` handles but `SimpleDateFormat` does not. Use `java.time`.

Note commit `72f4202` ("guard re-entry on send so a double tap can't insert twice") — `send` must be a no-op while `isSending` is true. That behaviour is tested below.

- [ ] **Step 2: Write the failing test**

```kotlin
package com.harvestglass.harvest.ui.field

import com.harvestglass.harvest.data.model.CommunityMessage
import com.harvestglass.harvest.data.service.CommunityService
import io.mockk.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.emptyFlow
import kotlinx.coroutines.test.*
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class CommunityChatViewModelTest {
    private val service: CommunityService = mockk(relaxed = true)
    private lateinit var vm: CommunityChatViewModel

    private fun msg(id: String, at: String) =
        CommunityMessage(id = id, communityId = "c1", senderId = "u1", content = "hi", createdAt = at)

    @Before fun setUp() {
        Dispatchers.setMain(StandardTestDispatcher())
        every { service.subscribeMessages(any()) } returns emptyFlow()
        every { service.subscribeReactions(any()) } returns emptyFlow()
    }
    @After fun tearDown() { Dispatchers.resetMain() }

    @Test
    fun `start loads the newest page oldest-first for display`() = runTest {
        // service returns newest-first; the UI renders oldest-first
        coEvery { service.messagesPage("c1", null, any()) } returns
            listOf(msg("m2", "2026-08-16T10:01:00.000001+00:00"), msg("m1", "2026-08-16T10:00:00.000001+00:00"))
        coEvery { service.senderProfiles(any()) } returns emptyList()
        coEvery { service.reactions(any()) } returns emptyList()
        vm = CommunityChatViewModel(service)

        vm.start("c1", "u1"); advanceUntilIdle()

        assertEquals(listOf("m1", "m2"), vm.state.value.messages.map { it.id })
    }

    @Test
    fun `send is a no-op while a send is already in flight`() = runTest {
        coEvery { service.messagesPage(any(), any(), any()) } returns emptyList()
        coEvery { service.senderProfiles(any()) } returns emptyList()
        coEvery { service.reactions(any()) } returns emptyList()
        coEvery { service.post(any(), any(), any(), any(), any()) } coAnswers {
            kotlinx.coroutines.delay(1_000); msg("m9", "2026-08-16T10:02:00.000001+00:00")
        }
        vm = CommunityChatViewModel(service)
        vm.start("c1", "u1"); advanceUntilIdle()

        vm.send("hello")
        vm.send("hello")          // double tap, before the first resolves
        advanceUntilIdle()

        coVerify(exactly = 1) { service.post("c1", "u1", "hello", null, emptyList()) }
    }

    @Test
    fun `blank content is not sent`() = runTest {
        coEvery { service.messagesPage(any(), any(), any()) } returns emptyList()
        coEvery { service.senderProfiles(any()) } returns emptyList()
        coEvery { service.reactions(any()) } returns emptyList()
        vm = CommunityChatViewModel(service)
        vm.start("c1", "u1"); advanceUntilIdle()

        vm.send("   "); advanceUntilIdle()

        coVerify(exactly = 0) { service.post(any(), any(), any(), any(), any()) }
    }

    @Test
    fun `a realtime echo of an already-inserted message does not duplicate it`() = runTest {
        coEvery { service.messagesPage(any(), any(), any()) } returns emptyList()
        coEvery { service.senderProfiles(any()) } returns emptyList()
        coEvery { service.reactions(any()) } returns emptyList()
        val posted = msg("m9", "2026-08-16T10:02:00.000001+00:00")
        coEvery { service.post(any(), any(), any(), any(), any()) } returns posted
        every { service.subscribeMessages("c1") } returns kotlinx.coroutines.flow.flowOf(posted)
        vm = CommunityChatViewModel(service)
        vm.start("c1", "u1"); advanceUntilIdle()

        vm.send("hi"); advanceUntilIdle()

        assertEquals(1, vm.state.value.messages.count { it.id == "m9" })
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `./gradlew :app:testDebugUnitTest --tests "*CommunityChatViewModelTest*"`
Expected: FAIL — unresolved reference.

- [ ] **Step 4: Implement `CommunityChatViewModel.kt`**

Port the Swift behaviour. Non-negotiable details:
- `messagesPage` returns **newest-first**; the state holds them **oldest-first** for rendering. Reverse on load, prepend on `loadOlder`.
- Merging a realtime message is keyed on `id` — never append blindly, or the sender sees their own message twice (the optimistic insert plus the echo).
- `send` returns early if `isSending` is true or the trimmed content is empty, sets `isSending = true`, and clears it in a `finally`.
- After each page load, hydrate senders via `senderProfiles` for the distinct `senderId`s not already in the map, and bulk-load `reactions` for the page's message ids.
- `toggleReaction` checks whether the current user already reacted with that emoji and calls `removeReaction` or `addReaction` accordingly, updating state optimistically.
- `onCleared` cancels the collection jobs so the channels unsubscribe.

- [ ] **Step 5: Run tests to verify they pass**

Run: `./gradlew :app:testDebugUnitTest --tests "*CommunityChatViewModelTest*"`
Expected: PASS, 4 tests.

- [ ] **Step 6: Commit**

```bash
git add android/app/src/main/java/com/harvestglass/harvest/ui/field android/app/src/test
git commit -m "feat(android): port CommunityChatViewModel with realtime merge"
```

---

### Task 13: Community chat screen

**Files:**
- Create: `ui/field/CommunityChatScreen.kt`, `ui/components/chat/ChatBubble.kt`, `ui/components/chat/ChatComposer.kt`, `ui/components/chat/DateSeparator.kt`, `ui/components/chat/MessageGrouping.kt`
- Modify: `ui/MainTabScreen.kt` — add the chat route
- Test: `android/app/src/test/java/com/harvestglass/harvest/ui/components/chat/MessageGroupingTest.kt`

**Interfaces:**
- Consumes: `CommunityChatViewModel` (Task 12), theme and components (Tasks 2–3).
- Produces: `@Composable fun CommunityChatScreen(community: Community, userId: String, onBack: () -> Unit, viewModel: CommunityChatViewModel = hiltViewModel())`; `fun groupMessages(messages: List<CommunityMessage>): List<ChatRow>` where `sealed interface ChatRow { data class DateHeader(val label: String); data class Bubble(val message: CommunityMessage, val isFirstInGroup: Boolean, val isLastInGroup: Boolean) }`.

- [ ] **Step 1: Read the iOS source**

Read `Harvest/Views/Field/CommunityChatView.swift` (667 lines) and every file in `Harvest/Views/Components/Chat/` — `ChatAccent`, `ChatBackdrop`, `ChatBubbleBackground`, `ChatBubbleShape`, `ChatComposer`, `DateSeparator`, `MessageGrouping`. The Field uses the **green** accent (`fieldGreen`/`fieldGreenDeep`), not rose — that is what `ChatAccent` parameterises.

- [ ] **Step 2: Write the failing test for grouping**

Grouping is pure logic, so it is unit-tested.

```kotlin
package com.harvestglass.harvest.ui.components.chat

import com.harvestglass.harvest.data.model.CommunityMessage
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class MessageGroupingTest {
    private fun msg(id: String, sender: String, at: String) =
        CommunityMessage(id = id, communityId = "c1", senderId = sender, content = "x", createdAt = at)

    @Test
    fun `consecutive messages from one sender group together`() {
        val rows = groupMessages(listOf(
            msg("m1", "u1", "2026-08-16T10:00:00.000001+00:00"),
            msg("m2", "u1", "2026-08-16T10:00:30.000001+00:00")
        )).filterIsInstance<ChatRow.Bubble>()
        assertTrue(rows[0].isFirstInGroup)
        assertTrue(!rows[1].isFirstInGroup)
        assertTrue(rows[1].isLastInGroup)
    }

    @Test
    fun `a different sender starts a new group`() {
        val rows = groupMessages(listOf(
            msg("m1", "u1", "2026-08-16T10:00:00.000001+00:00"),
            msg("m2", "u2", "2026-08-16T10:00:30.000001+00:00")
        )).filterIsInstance<ChatRow.Bubble>()
        assertTrue(rows[0].isFirstInGroup && rows[0].isLastInGroup)
        assertTrue(rows[1].isFirstInGroup && rows[1].isLastInGroup)
    }

    @Test
    fun `a date header is inserted when the day changes`() {
        val rows = groupMessages(listOf(
            msg("m1", "u1", "2026-08-15T23:59:00.000001+00:00"),
            msg("m2", "u1", "2026-08-16T00:01:00.000001+00:00")
        ))
        assertEquals(2, rows.filterIsInstance<ChatRow.DateHeader>().size)
    }

    @Test
    fun `microsecond timestamps parse without throwing`() {
        val rows = groupMessages(listOf(msg("m1", "u1", "2026-08-16T10:00:00.123456+00:00")))
        assertTrue(rows.isNotEmpty())
    }
}
```

Match the exact grouping window and header format used by `MessageGrouping.swift` — read it before finalising these assertions and adjust them to the real rule.

- [ ] **Step 3: Run test to verify it fails**

Run: `./gradlew :app:testDebugUnitTest --tests "*MessageGroupingTest*"`
Expected: FAIL — unresolved reference.

- [ ] **Step 4: Implement grouping, bubbles, composer, and the screen**

`MessageGrouping.kt` parses `created_at` with `java.time.OffsetDateTime.parse` (microsecond-safe) and emits `DateHeader` + `Bubble` rows.

`ChatBubble.kt` reproduces `ChatBubbleShape`/`ChatBubbleBackground`: asymmetric corner radii by group position, outgoing bubbles filled with the Field gradient (`fieldGreen` → `fieldGreenDeep`) and `textInverse` text, incoming bubbles on `wineCard` with `textPrimary`. Avatars via Coil from `CommunitySender.photoUrl`.

`ChatComposer.kt` reproduces the composer: rounded field on `formSurface` with `formBorder`, send button tinted `fieldGreen`, disabled while blank or `isSending`. Commit `0ecd728` ("last message no longer clipped by the composer") means the message list must be padded by the composer's height — reproduce that with `imePadding()` plus bottom content padding, and verify the last bubble is fully visible with the keyboard open.

`CommunityChatScreen.kt` assembles them: a top bar with the room name and back arrow, the `LazyColumn` (with `reverseLayout = false` and auto-scroll to the newest message on arrival), and the composer pinned at the bottom. Reaction long-press opens the curated emoji row from `CommunityReaction.CURATED_EMOJI`.

- [ ] **Step 5: Add the navigation route**

In `MainTabScreen.kt`, add a `composable("room/{communityId}")` destination; `FieldScreen.onOpenRoom` navigates to it. Pass the `Community` through a shared ViewModel or re-fetch by id — do not serialise the whole object into the route.

- [ ] **Step 6: Run tests to verify they pass**

Run: `./gradlew :app:testDebugUnitTest --tests "*MessageGroupingTest*"`
Expected: PASS, 4 tests.

- [ ] **Step 7: Commit**

```bash
git add android/app/src/main/java/com/harvestglass/harvest/ui android/app/src/test
git commit -m "feat(android): port community room chat"
```

---

### Task 14: End-to-end verification

**Files:**
- Create: `docs/verification/2026-08-16-android-slice-checklist.md`

**Interfaces:**
- Consumes: everything.
- Produces: a signed-off checklist.

- [ ] **Step 1: Run the full test suite**

```bash
cd android && ./gradlew :app:testDebugUnitTest :app:connectedDebugAndroidTest
```

Expected: all green. Record the actual counts — do not claim a pass without reading the output.

- [ ] **Step 2: Run the app against live data on the emulator**

```bash
./gradlew :app:installDebug
```

- [ ] **Step 3: Write and complete the verification checklist**

Create `docs/verification/2026-08-16-android-slice-checklist.md` covering, each with a pass/fail box:
- Launch shows the splash with the pulsing wordmark, then the login form.
- Sign in with a real account succeeds; killing and reopening the app restores the session without a re-login.
- The tab bar shows five tabs in the order Soil / The Field / Gardener / Seeds / Profile, opens on **The Field**, and uses the cream `wineBlack` bar with a rose selected item.
- The Field lists the same rooms, in the same order, with the same member counts as the iOS app for the same account.
- Joining a room moves it to the joined treatment; the change survives a pull-to-refresh and is visible on iOS.
- Opening a joined room loads history oldest-first and scrolls to the newest message.
- Sending a message shows it immediately and does **not** duplicate when the realtime echo arrives.
- A message sent from the iOS app appears live in the Android room without a refresh.
- Double-tapping send inserts exactly one message.
- With the keyboard open, the last message is fully visible above the composer.
- Reactions add and remove, and reflect changes made on iOS.
- Side-by-side screenshot against iOS: page background, card surfaces, room-name-over-scrim, member-count accent, and the green Field chat bubbles match.

- [ ] **Step 4: Commit**

```bash
git add docs/verification/2026-08-16-android-slice-checklist.md
git commit -m "docs: Android slice verification checklist"
```

---

## What this plan deliberately does not cover

These are P2 subsystems, each getting its own spec-derived plan:

- Onboarding + Values (Soil) — replaces `OnboardingPlaceholderScreen` from Task 7
- Seeds, Discover, Compatibility, Filters
- Chat / DM + mindful messaging
- Gardener, including screenshot review
- Profile, Settings, Help, Legal, Safety
- Subscription (Play Billing) + Notifications (FCM), carrying the `user_devices`
  platform CHECK migration and the `send-push` FCM branch described in the spec
