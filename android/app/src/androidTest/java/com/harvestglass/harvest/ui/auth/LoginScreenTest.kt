package com.harvestglass.harvest.ui.auth

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import com.harvestglass.harvest.ui.theme.HarvestAppTheme
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test

/** Copy asserted here is verbatim from Harvest/Views/Auth/LoginView.swift. */
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
        rule.onNodeWithContentDescription("Email").performTextInput("ada@example.com")
        rule.onNodeWithContentDescription("Password").performTextInput("hunter2")
        rule.onNodeWithText("Sign In").performClick()
        assertEquals("ada@example.com" to "hunter2", captured)
    }

    @Test
    fun submitIsInertWhileTheFormIsInvalid() {
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
        // iOS isFormValid: non-blank email containing "@", password >= 6 chars.
        rule.onNodeWithContentDescription("Email").performTextInput("ada@example.com")
        rule.onNodeWithContentDescription("Password").performTextInput("short")
        rule.onNodeWithText("Sign In").performClick()
        assertNull(captured)
    }

    @Test
    fun togglingToSignUpSwitchesTheCopyAndCallsOnRegister() {
        var registered: Pair<String, String>? = null
        rule.setContent {
            HarvestAppTheme {
                LoginScreen(
                    state = AuthUiState(isLoading = false),
                    onLogin = { _, _ -> },
                    onRegister = { e, p -> registered = e to p }
                )
            }
        }
        rule.onNodeWithText("Welcome back").assertIsDisplayed()
        rule.onNodeWithText("Create one").performClick()
        rule.onNodeWithText("Create your account").assertIsDisplayed()
        rule.onNodeWithText("Use at least 6 characters.").assertIsDisplayed()

        rule.onNodeWithContentDescription("Email").performTextInput("ada@example.com")
        rule.onNodeWithContentDescription("Password").performTextInput("hunter2")
        rule.onNodeWithText("Create Account").performClick()
        assertEquals("ada@example.com" to "hunter2", registered)
    }

    @Test
    fun errorFromStateIsShown() {
        rule.setContent {
            HarvestAppTheme {
                LoginScreen(
                    state = AuthUiState(isLoading = false, error = "Invalid login credentials"),
                    onLogin = { _, _ -> },
                    onRegister = { _, _ -> }
                )
            }
        }
        rule.onNodeWithText("Invalid login credentials").assertIsDisplayed()
    }

    @Test
    fun taglineIsTheIosCopy() {
        rule.setContent {
            HarvestAppTheme {
                LoginScreen(AuthUiState(isLoading = false), { _, _ -> }, { _, _ -> })
            }
        }
        rule.onNodeWithText("Understand what you bring.\nGrow connection that lasts.")
            .assertIsDisplayed()
    }
}
