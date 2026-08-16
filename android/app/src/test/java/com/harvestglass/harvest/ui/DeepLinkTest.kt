package com.harvestglass.harvest.ui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** Lifted from MainTabView.handleDeepLink in Harvest/Views/MainTabView.swift. */
class DeepLinkTest {
    @Test fun chatOpensSeeds() = assertEquals(HarvestTab.SEEDS, deepLinkTab("chat:abc"))
    @Test fun seedOpensSeeds() = assertEquals(HarvestTab.SEEDS, deepLinkTab("seed:abc"))
    @Test fun bareSeedsOpensSeeds() = assertEquals(HarvestTab.SEEDS, deepLinkTab("seeds"))
    @Test fun matchOpensSeeds() = assertEquals(HarvestTab.SEEDS, deepLinkTab("match:abc"))
    @Test fun gardenerOpensGardener() = assertEquals(HarvestTab.GARDENER, deepLinkTab("gardener"))
    @Test fun communityOpensField() = assertEquals(HarvestTab.FIELD, deepLinkTab("community:abc"))
    @Test fun unknownLinkChangesNothing() = assertNull(deepLinkTab("nonsense"))

    @Test
    fun tabsAreInTheIosOrder() {
        assertEquals(
            listOf("Soil", "The Field", "Gardener", "Seeds", "Profile"),
            HarvestTab.entries.map { it.title }
        )
    }

    @Test
    fun theFieldIsTheLandingTab() {
        // iOS: @State private var selection: Int = 1
        assertEquals(HarvestTab.FIELD, HarvestTab.entries[1])
    }
}
