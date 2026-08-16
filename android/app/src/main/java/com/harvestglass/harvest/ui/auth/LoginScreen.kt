package com.harvestglass.harvest.ui.auth

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowForward
import androidx.compose.material.icons.filled.Eco
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.PersonAdd
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.blur
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.harvestglass.harvest.R
import com.harvestglass.harvest.ui.components.GlassButton
import com.harvestglass.harvest.ui.theme.HarvestButtonKind
import com.harvestglass.harvest.ui.theme.HarvestTheme

/**
 * Port of Harvest/Views/Auth/LoginView.swift. All user-visible copy is
 * verbatim from that file.
 */
@Composable
fun LoginScreen(
    state: AuthUiState,
    onLogin: (String, String) -> Unit,
    onRegister: (String, String) -> Unit
) {
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var isSignUp by remember { mutableStateOf(false) }
    var showPassword by remember { mutableStateOf(false) }

    // iOS isFormValid: non-blank email containing "@", password >= 6 chars.
    val isFormValid = email.trim().isNotEmpty() && password.length >= 6 && email.contains("@")

    fun submit() {
        if (!isFormValid || state.isLoading) return
        if (isSignUp) onRegister(email, password) else onLogin(email, password)
    }

    Box(Modifier.fillMaxSize()) {
        Image(
            painter = painterResource(R.drawable.splash_page_gradient),
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = Modifier.fillMaxSize()
        )
        // Subtle veil so form text stays legible over the gradient.
        Box(
            Modifier
                .fillMaxSize()
                .background(HarvestTheme.Colors.deepPlum.copy(alpha = 0.35f))
        )

        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xl),
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = HarvestTheme.Spacing.lg)
        ) {
            Spacer(Modifier.height(72.dp))

            Logo()

            FormCard(
                isSignUp = isSignUp,
                email = email,
                onEmailChange = { email = it },
                password = password,
                onPasswordChange = { password = it },
                showPassword = showPassword,
                onToggleShowPassword = { showPassword = !showPassword },
                isFormValid = isFormValid,
                state = state,
                onSubmit = ::submit
            )

            ToggleAuthMode(isSignUp = isSignUp, onToggle = { isSignUp = !isSignUp })

            Spacer(Modifier.height(40.dp))
        }
    }
}

@Composable
private fun Logo() {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md)
    ) {
        Box(contentAlignment = Alignment.Center) {
            Box(
                Modifier
                    .size(160.dp)
                    .blur(4.dp)
                    .background(HarvestTheme.Colors.glowGradient, CircleShape)
            )
            Box(
                Modifier
                    .size(88.dp)
                    .background(HarvestTheme.Colors.primaryGradient, CircleShape)
            )
            Icon(
                imageVector = Icons.Filled.Eco,
                contentDescription = null,
                tint = HarvestTheme.Colors.pureWhite,
                modifier = Modifier.size(38.dp)
            )
        }

        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xs)
        ) {
            Text(
                text = "Harvest",
                style = HarvestTheme.Typography.display,
                color = HarvestTheme.Colors.textPrimary
            )
            Text(
                text = "Understand what you bring.\nGrow connection that lasts.",
                style = HarvestTheme.Typography.bodyRegular,
                color = HarvestTheme.Colors.textSecondary,
                textAlign = TextAlign.Center
            )
        }
    }
}

@Composable
private fun FormCard(
    isSignUp: Boolean,
    email: String,
    onEmailChange: (String) -> Unit,
    password: String,
    onPasswordChange: (String) -> Unit,
    showPassword: Boolean,
    onToggleShowPassword: () -> Unit,
    isFormValid: Boolean,
    state: AuthUiState,
    onSubmit: () -> Unit
) {
    val shape = RoundedCornerShape(HarvestTheme.Radius.xxl)
    Column(
        verticalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.md),
        modifier = Modifier
            .fillMaxWidth()
            .background(HarvestTheme.Colors.glassFillStrong.copy(alpha = 0.92f), shape)
            .border(1.dp, HarvestTheme.Colors.border, shape)
            .padding(HarvestTheme.Spacing.lg)
    ) {
        Text(
            text = if (isSignUp) "Create your account" else "Welcome back",
            style = HarvestTheme.Typography.h3,
            color = HarvestTheme.Colors.textPrimary,
            modifier = Modifier.fillMaxWidth()
        )

        AuthField(
            icon = Icons.Filled.Email,
            placeholder = "Email",
            value = email,
            onValueChange = onEmailChange,
            keyboardType = KeyboardType.Email
        )

        AuthField(
            icon = Icons.Filled.Lock,
            placeholder = "Password",
            value = password,
            onValueChange = onPasswordChange,
            keyboardType = KeyboardType.Password,
            isSecure = !showPassword,
            trailing = {
                Icon(
                    imageVector = if (showPassword) Icons.Filled.VisibilityOff else Icons.Filled.Visibility,
                    contentDescription = null,
                    tint = HarvestTheme.Colors.textTertiary,
                    modifier = Modifier.clickable { onToggleShowPassword() }
                )
            }
        )

        if (isSignUp) {
            Text(
                text = "Use at least 6 characters.",
                style = HarvestTheme.Typography.caption,
                color = HarvestTheme.Colors.textTertiary,
                modifier = Modifier.fillMaxWidth()
            )
        }

        state.error?.let { error ->
            Text(
                text = error,
                style = HarvestTheme.Typography.bodySmall,
                color = HarvestTheme.Colors.error,
                modifier = Modifier.fillMaxWidth()
            )
        }

        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = HarvestTheme.Spacing.xs)
        ) {
            GlassButton(
                title = if (isSignUp) "Create Account" else "Sign In",
                icon = if (isSignUp) Icons.Filled.PersonAdd else Icons.Filled.ArrowForward,
                style = HarvestButtonKind.PRIMARY,
                modifier = Modifier.alpha(if (isFormValid) 1f else 0.55f),
                onClick = onSubmit
            )
            if (state.isLoading) {
                CircularProgressIndicator(color = HarvestTheme.Colors.pureWhite)
            }
        }
    }
}

@Composable
private fun ToggleAuthMode(isSignUp: Boolean, onToggle: () -> Unit) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.xs),
        modifier = Modifier.clickable { onToggle() }
    ) {
        Text(
            text = if (isSignUp) "Already have an account?" else "New to Harvest?",
            style = HarvestTheme.Typography.bodySmall,
            color = HarvestTheme.Colors.textSecondary
        )
        Text(
            text = if (isSignUp) "Sign In" else "Create one",
            style = HarvestTheme.Typography.bodySmall,
            fontWeight = FontWeight.SemiBold,
            color = HarvestTheme.Colors.rose
        )
    }
}

@Composable
private fun AuthField(
    icon: ImageVector,
    placeholder: String,
    value: String,
    onValueChange: (String) -> Unit,
    keyboardType: KeyboardType,
    isSecure: Boolean = false,
    trailing: @Composable (() -> Unit)? = null
) {
    val shape = RoundedCornerShape(HarvestTheme.Radius.lg)

    // The placeholder is drawn inside the field's decorationBox rather than
    // beside it, so it belongs to the text field's semantics — otherwise it
    // is a sibling node and cannot be typed into by placeholder name.
    BasicTextField(
        value = value,
        onValueChange = onValueChange,
        singleLine = true,
        textStyle = LocalTextStyle.current.merge(
            TextStyle(color = HarvestTheme.Colors.textPrimary)
        ),
        cursorBrush = SolidColor(HarvestTheme.Colors.rose),
        visualTransformation = if (isSecure) PasswordVisualTransformation() else VisualTransformation.None,
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        modifier = Modifier
            .fillMaxWidth()
            .semantics { contentDescription = placeholder },
        decorationBox = { innerTextField ->
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(HarvestTheme.Spacing.sm),
                modifier = Modifier
                    .fillMaxWidth()
                    .background(HarvestTheme.Colors.fieldFill, shape)
                    .border(1.dp, HarvestTheme.Colors.border, shape)
                    .padding(HarvestTheme.Spacing.md)
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = HarvestTheme.Colors.rose.copy(alpha = 0.9f),
                    modifier = Modifier.width(22.dp)
                )

                Box(Modifier.weight(1f), contentAlignment = Alignment.CenterStart) {
                    if (value.isEmpty()) {
                        Text(
                            text = placeholder,
                            style = HarvestTheme.Typography.bodyRegular,
                            color = HarvestTheme.Colors.textTertiary
                        )
                    }
                    innerTextField()
                }

                trailing?.invoke()
            }
        }
    )
}
