package com.harvestglass.harvest.ui.subscription

import android.app.Activity
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.harvestglass.harvest.billing.BillingPeriod
import com.harvestglass.harvest.billing.PlayBilling
import com.harvestglass.harvest.billing.PurchaseOutcome
import com.harvestglass.harvest.data.model.SubscriptionTier
import com.harvestglass.harvest.data.model.TierName
import com.harvestglass.harvest.data.model.UserSubscription
import com.harvestglass.harvest.data.service.SubscriptionService
import com.harvestglass.harvest.util.userMessage
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class SubscriptionUiState(
    val tiers: List<SubscriptionTier> = emptyList(),
    val currentSubscription: UserSubscription? = null,
    val currentTier: SubscriptionTier? = null,
    /** Play product details, keyed by product id. Empty until Play answers. */
    val products: Map<String, ProductDetails> = emptyMap(),
    val isLoading: Boolean = false,
    val isPurchasing: Boolean = false,
    val error: String? = null,
    val successMessage: String? = null
) {
    fun isCurrentTier(tier: SubscriptionTier): Boolean = currentTier?.id == tier.id

    /** The tier name shown in the header, "Seed" until the real one loads. */
    val currentTierName: String get() = currentTier?.marketingDisplayName ?: "Seed"

    /** Whether the Manage Subscription card shows — paid plans only, as on iOS. */
    val showsManageCard: Boolean get() = currentTier != null && currentTier.name != TierName.SEED

    fun product(tier: SubscriptionTier, period: BillingPeriod): ProductDetails? {
        val id = PlayBilling.Product.forTier(tier.name.raw, period)?.id ?: return null
        return products[id]
    }
}

/**
 * Mirrors Harvest/ViewModels/SubscriptionViewModel.swift, with StoreKit swapped
 * for Play Billing.
 *
 * The one structural difference from iOS: a purchase is not trusted here. iOS
 * verifies the StoreKit transaction on-device and writes the tier itself; this
 * hands the Play token to `verify-play-purchase` and lets the server decide.
 */
@HiltViewModel
class SubscriptionViewModel @Inject constructor(
    private val service: SubscriptionService,
    private val billing: PlayBilling
) : ViewModel() {

    private val _state = MutableStateFlow(SubscriptionUiState())
    val state: StateFlow<SubscriptionUiState> = _state.asStateFlow()

    /** Set by [purchase] so a purchase Play reports later can be attributed. */
    private var purchasingUserId: String? = null

    init {
        // Play reports every purchase through the listener, including one the
        // user completed while this screen was backgrounded.
        viewModelScope.launch {
            billing.purchaseOutcomes.collect { outcome -> handleOutcome(outcome) }
        }
    }

    fun loadSubscriptionData(userId: String) = viewModelScope.launch {
        _state.update { it.copy(isLoading = true) }
        try {
            coroutineScope {
                val tiersTask = async { service.getSubscriptionTiers() }
                val subTask = async { service.getUserSubscription(userId) }

                val tiers = tiersTask.await()
                val sub = subTask.await()

                _state.update {
                    it.copy(
                        tiers = tiers,
                        currentSubscription = sub,
                        currentTier = tiers.firstOrNull { tier -> tier.id == sub?.tierId }
                            ?: tiers.firstOrNull { tier -> tier.name == TierName.SEED },
                        error = null
                    )
                }
            }
        } catch (e: Exception) {
            _state.update { it.copy(error = e.userMessage()) }
        } finally {
            _state.update { it.copy(isLoading = false) }
        }
    }

    fun loadProducts() = viewModelScope.launch {
        val details = billing.products()
        _state.update {
            it.copy(
                products = details.associateBy { product -> product.productId },
                error = if (details.isEmpty()) PRODUCTS_UNAVAILABLE else it.error
            )
        }
    }

    /**
     * Opens Play's purchase sheet. The outcome arrives asynchronously through
     * [handleOutcome] — Play, not this call, reports what happened.
     */
    fun purchase(activity: Activity, details: ProductDetails, userId: String) {
        purchasingUserId = userId
        _state.update { it.copy(isPurchasing = true, error = null, successMessage = null) }

        val failure = billing.launchPurchase(activity, details)
        if (failure != null) {
            purchasingUserId = null
            _state.update { it.copy(isPurchasing = false, error = failure) }
        }
    }

    /**
     * Re-verifies whatever Play still considers purchased. Mirrors
     * `restorePurchases`, including its "nothing to restore" message.
     */
    fun restorePurchases(userId: String) = viewModelScope.launch {
        _state.update { it.copy(isLoading = true, error = null, successMessage = null) }
        try {
            val restored = syncWithPlay(userId)
            if (restored) {
                loadSubscriptionData(userId).join()
                _state.update { it.copy(successMessage = "Your purchases have been restored.") }
            } else {
                _state.update { it.copy(error = "No previous purchases found to restore.") }
            }
        } catch (e: Exception) {
            _state.update { it.copy(error = e.userMessage()) }
        } finally {
            _state.update { it.copy(isLoading = false) }
        }
    }

    /**
     * Quietly reconciles the tier row with Play on screen open. Mirrors
     * `checkSubscriptionStatus` — failures here are silent by design, since
     * nobody asked for this and a stale row is better than a scary alert.
     */
    fun checkSubscriptionStatus(userId: String) = viewModelScope.launch {
        runCatching { syncWithPlay(userId) }
        loadSubscriptionData(userId)
    }

    fun clearError() = _state.update { it.copy(error = null) }

    fun clearSuccess() = _state.update { it.copy(successMessage = null) }

    /**
     * Verifies every live Play purchase server-side and acknowledges it, or
     * drops the user to Seed when Play reports none.
     *
     * Returns whether anything was verified.
     */
    private suspend fun syncWithPlay(userId: String): Boolean {
        val purchases = billing.activePurchases()
        var verified = false

        for (purchase in purchases) {
            for (productId in purchase.products) {
                runCatching { service.verifyPlayPurchase(userId, productId, purchase.purchaseToken) }
                    .onSuccess { verified = true }
            }
            // Acknowledge only what the server accepted; leaving an unverified
            // purchase unacknowledged lets Google refund it rather than
            // stranding the user on a tier they never got.
            if (verified) billing.acknowledge(purchase)
        }

        if (!verified) service.syncToSeedTier(userId)
        return verified
    }

    private suspend fun handleOutcome(outcome: PurchaseOutcome) {
        val userId = purchasingUserId
        when (outcome) {
            is PurchaseOutcome.Cancelled -> {
                purchasingUserId = null
                // Silent, as on iOS — cancelling isn't an error.
                _state.update { it.copy(isPurchasing = false) }
            }

            is PurchaseOutcome.Pending -> {
                purchasingUserId = null
                _state.update {
                    it.copy(
                        isPurchasing = false,
                        error = "Your purchase is pending approval. Please check back later."
                    )
                }
            }

            is PurchaseOutcome.Failed -> {
                purchasingUserId = null
                _state.update { it.copy(isPurchasing = false, error = outcome.message) }
            }

            is PurchaseOutcome.Purchased -> {
                if (userId == null) {
                    _state.update { it.copy(isPurchasing = false) }
                    return
                }
                purchasingUserId = null
                grant(userId, outcome.purchases)
            }
        }
    }

    private suspend fun grant(userId: String, purchases: List<Purchase>) {
        try {
            // An ITEM_ALREADY_OWNED result carries no purchases; fall back to
            // asking Play what it thinks this account owns.
            val verified = if (purchases.isEmpty()) {
                syncWithPlay(userId)
            } else {
                verifyAll(userId, purchases)
            }

            if (!verified) {
                _state.update {
                    it.copy(
                        isPurchasing = false,
                        error = "We couldn't confirm that purchase. Try Restore Purchases."
                    )
                }
                return
            }

            loadSubscriptionData(userId).join()
            _state.update {
                it.copy(isPurchasing = false, successMessage = "Your subscription is now active.")
            }
        } catch (e: Exception) {
            _state.update { it.copy(isPurchasing = false, error = e.userMessage()) }
        }
    }

    private suspend fun verifyAll(userId: String, purchases: List<Purchase>): Boolean {
        var verified = false
        for (purchase in purchases) {
            var accepted = false
            for (productId in purchase.products) {
                runCatching { service.verifyPlayPurchase(userId, productId, purchase.purchaseToken) }
                    .onSuccess { accepted = true }
            }
            if (accepted) {
                billing.acknowledge(purchase)
                verified = true
            }
        }
        return verified
    }

    companion object {
        const val PRODUCTS_UNAVAILABLE =
            "No subscription products were returned by Google Play."
    }
}
