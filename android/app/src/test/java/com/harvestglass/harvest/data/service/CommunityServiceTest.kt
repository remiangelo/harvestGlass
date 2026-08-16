package com.harvestglass.harvest.data.service

import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Network calls need a live backend, so this covers the guard clauses
 * CommunityService.swift implements — the empty-list early returns that keep
 * a malformed `in.()` filter from ever reaching Postgrest.
 *
 * With a relaxed mock client, a missing guard would return a mock value or
 * throw rather than an empty list, so these fail if a guard is dropped.
 */
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
