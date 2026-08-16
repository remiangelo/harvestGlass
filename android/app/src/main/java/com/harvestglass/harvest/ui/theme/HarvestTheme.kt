package com.harvestglass.harvest.ui.theme

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
 *
 * The `wine*` names are historical — they date from the dark wine/plum theme
 * and are referenced by ~300 call sites on iOS, so they were kept and
 * re-valued rather than renamed. Read "wine*" as "surface, deepest to most
 * lifted"; they are light tints now, not darks.
 */
object HarvestTheme {

    object Colors {
        // MARK: Core brand palette
        val wineBlack = Color(0xFFE6C6B6)   // nav / tab bars — deepest tint
        val deepPlum = Color(0xFFF0D5C8)    // app background
        val wineCard = Color(0xFFFFF9F5)    // card / glass surface
        val wineRaised = Color(0xFFFFFFFF)  // elevated surface

        /**
         * The one place a genuine dark is still needed: a scrim over user
         * photography so white text stays legible on top of it.
         * Do not use it as a surface.
         */
        val photoScrim = Color(0xFF2A1714)

        // Reds (brand accent family)
        val rose = Color(0xFFDB2637)        // primary red
        val roseLight = Color(0xFFEE6A72)   // lighter tint / 2nd series
        val roseDeep = Color(0xFFA81C2B)    // gradient end (deeper)
        val roseBloom = Color(0xFFC94F58)   // softer red (labels)
        val amber = Color(0xFFD97A28)       // warm amber — 2nd radar series ("Them")

        // Field greens — The Field / community rooms accent.
        // Used ONLY inside Field views; the rest of the app stays red.
        val fieldGreen = Color(0xFF2E7D5B)

        /**
         * Despite the name this is the DARKER green: it is used as a
         * foreground (labels, metadata), which now sits on light surfaces.
         */
        val fieldGreenLight = Color(0xFF246B4C)
        val fieldGreenDeep = Color(0xFF1E5A40)  // gradient end for Field bubbles
        val fieldGreenBorder = fieldGreen.copy(alpha = 0.28f)
        val fieldGreenSoft = fieldGreen.copy(alpha = 0.12f)

        // Legacy brand tokens — kept defined so ported views compile,
        // but no longer the semantic accent/text.
        val iconRed = Color(0xFFB81D2A)
        val appleRed = Color(0xFFBE3A34)
        val heartGlow = rose
        val harvestGold = Color(0xFFC07A3C)
        val harvestCream = Color(0xFFF0D5C8)
        val pureWhite = Color(0xFFFFFFFF)
        val black = Color(0xFF000000)

        // MARK: Existing tokens (kept for compatibility)
        // Primary
        val primary = rose
        val primaryDark = roseDeep
        val primaryLight = roseLight
        val primarySoft = rose.copy(alpha = 0.10f)
        val blackSurface = wineBlack
        val redSurface = rose
        val outgoingMessageSurface = rose

        // Accent
        // Deeper than `roseLight` because accent is used as a FOREGROUND
        // (icons, links) and needs to hold up against the cream page.
        val accent = Color(0xFFC41F2E)
        val accentLight = Color(0xFFE8555F)
        val accentDark = Color(0xFF8E1622)
        val accentSoft = rose.copy(alpha = 0.10f)

        // Backgrounds
        val background = deepPlum
        val surface = wineCard
        val secondary = harvestCream
        val creamSurface = harvestCream

        // Text — flipped to warm darks; the page is light now.
        val textPrimary = Color(0xFF2B1A16)     // deep warm brown-black
        val textSecondary = Color(0xFF6E524A)   // muted warm brown
        val textTertiary = Color(0xFF8A6E66)
        val textInverse = pureWhite
        val textOnCream = Color(0xFF2B1A16)
        val textOnRedPrimary = pureWhite        // white on red buttons
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
        val border = Color(0xFF2B1A16).copy(alpha = 0.12f)   // warm hairline
        val divider = Color(0xFF2B1A16).copy(alpha = 0.10f)
        val glassFill = wineCard
        val glassFillStrong = wineRaised
        val fieldFill = wineCard
        val blackFill = black

        // Swipe actions
        val like = rose
        val nope = iconRed
        val superLike = accent

        // Gradients — the old names are kept so dependent views still work.
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
 * iOS pins `.preferredColorScheme(.light)`, so this ignores the system dark
 * setting entirely. Material3 is substrate only — call sites read HarvestTheme
 * tokens directly rather than MaterialTheme.colorScheme.
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
