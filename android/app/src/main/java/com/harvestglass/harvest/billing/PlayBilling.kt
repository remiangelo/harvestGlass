package com.harvestglass.harvest.billing

import android.app.Activity
import android.content.Context
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import com.android.billingclient.api.acknowledgePurchase
import com.android.billingclient.api.queryProductDetails
import com.android.billingclient.api.queryPurchasesAsync
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.coroutines.resume

/** Weekly or monthly, matching BillingPeriod in SubscriptionViewModel.swift. */
enum class BillingPeriod { WEEKLY, MONTHLY }

/** What came back from a launched purchase flow. Mirrors the cases StoreKit reports. */
sealed interface PurchaseOutcome {
    data class Purchased(val purchases: List<Purchase>) : PurchaseOutcome

    /** Google is waiting on the user — slow card, parental approval. Not an error. */
    data object Pending : PurchaseOutcome
    data object Cancelled : PurchaseOutcome
    data class Failed(val message: String) : PurchaseOutcome
}

/**
 * The Play Billing half of the subscription flow — the Android counterpart to
 * StoreKit in Harvest/Services/SubscriptionService.swift.
 *
 * Deliberately dumb: it talks to Play and reports what happened. Deciding what
 * a purchase entitles someone to is the server's job, not this class's.
 */
@Singleton
class PlayBilling @Inject constructor(@ApplicationContext context: Context) {

    /**
     * The four subscription products, ids identical to iOS's `ProductID`.
     *
     * Play needs each of these to exist as a subscription with one base plan;
     * keeping the ids identical means both stores write the same tier rows.
     */
    enum class Product(val id: String, val tier: String, val period: BillingPeriod) {
        GROW_WEEKLY("com.harvestglass.harvest.grow.weekly", "green", BillingPeriod.WEEKLY),
        GROW_MONTHLY("com.harvestglass.harvest.grow.monthly", "green", BillingPeriod.MONTHLY),
        GOLD_WEEKLY("com.harvestglass.harvest.gold.weekly", "gold", BillingPeriod.WEEKLY),
        GOLD_MONTHLY("com.harvestglass.harvest.gold.monthly", "gold", BillingPeriod.MONTHLY);

        companion object {
            fun forTier(tier: String, period: BillingPeriod): Product? =
                entries.firstOrNull { it.tier == tier && it.period == period }
        }
    }

    private val _purchaseOutcomes = MutableSharedFlow<PurchaseOutcome>(extraBufferCapacity = 4)

    /** Purchase results, pushed by Play whenever a flow this app launched settles. */
    val purchaseOutcomes: SharedFlow<PurchaseOutcome> = _purchaseOutcomes.asSharedFlow()

    private val listener = PurchasesUpdatedListener { result, purchases ->
        val outcome = when (result.responseCode) {
            BillingClient.BillingResponseCode.OK -> {
                val settled = purchases.orEmpty()
                    .filter { it.purchaseState == Purchase.PurchaseState.PURCHASED }
                if (settled.isEmpty() && purchases.orEmpty().isNotEmpty()) {
                    PurchaseOutcome.Pending
                } else {
                    PurchaseOutcome.Purchased(settled)
                }
            }

            BillingClient.BillingResponseCode.USER_CANCELED -> PurchaseOutcome.Cancelled

            // Play already owns this subscription; report it as a purchase so the
            // caller re-verifies and repairs a tier row that never got written.
            BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED ->
                PurchaseOutcome.Purchased(emptyList())

            else -> PurchaseOutcome.Failed(result.readableMessage())
        }
        _purchaseOutcomes.tryEmit(outcome)
    }

    private val client = BillingClient.newBuilder(context)
        .setListener(listener)
        .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
        .build()

    private val connectMutex = Mutex()

    /**
     * Connects if needed. Play drops the connection on its own schedule, so
     * every call site goes through this rather than connecting once at startup.
     */
    suspend fun connect(): Boolean = connectMutex.withLock {
        if (client.isReady) return@withLock true

        suspendCancellableCoroutine { continuation ->
            client.startConnection(object : BillingClientStateListener {
                private var resumed = false

                override fun onBillingSetupFinished(result: BillingResult) {
                    // Play can call back more than once; only the first counts.
                    if (resumed) return
                    resumed = true
                    continuation.resume(result.responseCode == BillingClient.BillingResponseCode.OK)
                }

                override fun onBillingServiceDisconnected() {
                    if (resumed) return
                    resumed = true
                    continuation.resume(false)
                }
            })
        }
    }

    /** Product details for the four subscriptions, empty when Play is unreachable. */
    suspend fun products(): List<ProductDetails> {
        if (!connect()) return emptyList()

        val params = QueryProductDetailsParams.newBuilder()
            .setProductList(
                Product.entries.map {
                    QueryProductDetailsParams.Product.newBuilder()
                        .setProductId(it.id)
                        .setProductType(BillingClient.ProductType.SUBS)
                        .build()
                }
            )
            .build()

        val result = client.queryProductDetails(params)
        if (result.billingResult.responseCode != BillingClient.BillingResponseCode.OK) {
            return emptyList()
        }
        return result.productDetailsList.orEmpty()
    }

    /**
     * Opens Play's purchase sheet. The result arrives on [purchaseOutcomes],
     * not from this call — Play hands it back through the listener.
     *
     * Returns null on success, or a message when the sheet couldn't be opened.
     */
    fun launchPurchase(activity: Activity, details: ProductDetails): String? {
        // One base plan per product, so the first offer is the only offer. A
        // product with no offers can't be bought and shouldn't have been shown.
        val offerToken = details.subscriptionOfferDetails?.firstOrNull()?.offerToken
            ?: return "This subscription isn't available right now."

        val params = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(
                listOf(
                    BillingFlowParams.ProductDetailsParams.newBuilder()
                        .setProductDetails(details)
                        .setOfferToken(offerToken)
                        .build()
                )
            )
            .build()

        val result = client.launchBillingFlow(activity, params)
        return if (result.responseCode == BillingClient.BillingResponseCode.OK) {
            null
        } else {
            result.readableMessage()
        }
    }

    /**
     * Subscriptions Play currently considers purchased — the Android answer to
     * `Transaction.currentEntitlements`. Drives both restore and the status
     * check that runs when the screen opens.
     */
    suspend fun activePurchases(): List<Purchase> {
        if (!connect()) return emptyList()

        val params = QueryPurchasesParams.newBuilder()
            .setProductType(BillingClient.ProductType.SUBS)
            .build()

        val result = client.queryPurchasesAsync(params)
        if (result.billingResult.responseCode != BillingClient.BillingResponseCode.OK) {
            return emptyList()
        }
        return result.purchasesList.filter { it.purchaseState == Purchase.PurchaseState.PURCHASED }
    }

    /**
     * Tells Play the entitlement was granted. Google auto-refunds anything left
     * unacknowledged for three days, so this must follow every verified purchase.
     */
    suspend fun acknowledge(purchase: Purchase) {
        if (purchase.isAcknowledged) return
        if (!connect()) return

        client.acknowledgePurchase(
            AcknowledgePurchaseParams.newBuilder()
                .setPurchaseToken(purchase.purchaseToken)
                .build()
        )
    }
}

/** Play's debug message when it bothers to set one, otherwise the raw code. */
private fun BillingResult.readableMessage(): String =
    debugMessage.takeIf { it.isNotBlank() } ?: "Play billing error $responseCode"
