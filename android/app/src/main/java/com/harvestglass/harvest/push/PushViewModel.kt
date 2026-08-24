package com.harvestglass.harvest.push

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.harvestglass.harvest.data.service.NotificationService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * Owns push registration so the UI doesn't have to be handed a service.
 *
 * Every failure here is swallowed: push is a nicety, and without
 * google-services.json Firebase never initialises at all. The app must stay
 * fully usable in that state.
 */
@HiltViewModel
class PushViewModel @Inject constructor(
    private val notificationService: NotificationService
) : ViewModel() {

    fun register(userId: String, context: Context) {
        if (userId.isEmpty()) return
        viewModelScope.launch {
            runCatching { currentToken(context) }
                .getOrNull()
                ?.let { token -> runCatching { notificationService.registerDevice(userId, token) } }
        }
    }

    fun unregister(userId: String) {
        if (userId.isEmpty()) return
        viewModelScope.launch { runCatching { notificationService.unregisterDevice(userId) } }
    }
}
