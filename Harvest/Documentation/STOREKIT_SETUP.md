# StoreKit 2 Setup Guide

**Date**: 2026-03-10
**Status**: Implementation Complete - Requires App Store Connect Configuration

## Overview

Harvest now uses StoreKit 2 for in-app subscription purchases. This document guides you through the App Store Connect setup required to activate payments.

---

## Product IDs (Configured in Code)

The following product IDs are defined in `SubscriptionService.swift`:

| Product ID | Tier | Billing Period | Description |
|------------|------|----------------|-------------|
| `com.harvestglass.harvest.grow.weekly` | Grow | Weekly | Mid-tier weekly subscription |
| `com.harvestglass.harvest.grow.monthly` | Grow | Monthly | Mid-tier monthly subscription |
| `com.harvestglass.harvest.gold.weekly` | Gold | Weekly | Premium weekly subscription |
| `com.harvestglass.harvest.gold.monthly` | Gold | Monthly | Premium monthly subscription |

**Note**: The `seed` tier is free and doesn't require a product ID.

---

## App Store Connect Setup

### 1. Create In-App Purchases

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to your Harvest app
3. Go to **Features** → **In-App Purchases**
4. Click **+** to create new subscriptions

### 2. Create Subscription Group

1. Create a subscription group named: `Harvest Premium`
2. Add all four products to this group
3. Set subscription hierarchy:
   - Level 1: Grow Weekly, Grow Monthly
   - Level 2: Gold Weekly, Gold Monthly

### 3. Configure Each Product

For **Grow Weekly** (`com.harvestglass.harvest.grow.weekly`):
- **Reference Name**: Harvest Grow Weekly
- **Product ID**: `com.harvestglass.harvest.grow.weekly`
- **Subscription Duration**: 1 Week
- **Price**: `9.99`

For **Grow Monthly** (`com.harvestglass.harvest.grow.monthly`):
- **Reference Name**: Harvest Grow Monthly
- **Product ID**: `com.harvestglass.harvest.grow.monthly`
- **Subscription Duration**: 1 Month
- **Price**: `19.99`

For **Gold Weekly** (`com.harvestglass.harvest.gold.weekly`):
- **Reference Name**: Harvest Gold Weekly
- **Product ID**: `com.harvestglass.harvest.gold.weekly`
- **Subscription Duration**: 1 Week
- **Price**: `14.99`

For **Gold Monthly** (`com.harvestglass.harvest.gold.monthly`):
- **Reference Name**: Harvest Gold Monthly
- **Product ID**: `com.harvestglass.harvest.gold.monthly`
- **Subscription Duration**: 1 Month
- **Price**: `24.99`

### 4. Set Up Subscription Benefits

For each product, add benefits shown in the app:
- Unlimited matches per week
- Extended search distance
- AI Gardener chat access
- Deep values-based matching
- Advanced filters
- See who likes you
- Optional mindful messaging control

---

## Testing with StoreKit Configuration File

For local testing without App Store Connect:

1. Create a `Configuration.storekit` file in Xcode
2. Add products matching the IDs above
3. Set test prices
4. Enable in scheme settings: **Edit Scheme** → **Run** → **Options** → **StoreKit Configuration**

### Sample StoreKit Configuration

```json
{
  "identifier" : "Configuration",
  "products" : [
    {
      "displayPrice" : "9.99",
      "familyShareable" : false,
      "internalID" : "grow_monthly",
      "localizations" : [
        {
          "description" : "Unlock premium dating features",
          "displayName" : "Grow Weekly",
          "locale" : "en_US"
        }
      ],
      "productID" : "com.harvestglass.harvest.grow.weekly",
      "referenceName" : "Grow Weekly",
      "subscriptionGroupID" : "harvest_premium",
      "type" : "RecurringSubscription"
    }
  ],
  "version" : {
    "major" : 1,
    "minor" : 0
  }
}
```

---

## Code Architecture

### SubscriptionService.swift
- **Product Management**: `fetchProducts()` loads products from App Store
- **Purchase Flow**: `purchase(product:userId:)` handles purchase and verification
- **Transaction Verification**: `checkVerified()` validates receipts
- **Database Sync**: `updateSubscriptionAfterPurchase()` updates Supabase after successful purchase
- **Restore**: `restorePurchases()` restores previous purchases

### SubscriptionViewModel.swift
- **Product Loading**: `loadProducts()` fetches available products
- **Purchase UI**: `purchase(product:userId:)` triggers purchase flow
- **Error Handling**: Displays user-friendly error messages
- **Status Sync**: `checkSubscriptionStatus()` keeps app in sync with App Store

### SubscriptionView.swift
- Displays available subscription tiers
- Shows current subscription status
- "Restore" button for users who purchased on another device

### PurchaseSheet.swift
- Billing period selection (Weekly/Monthly)
- Real-time pricing from StoreKit
- Feature comparison
- Subscription terms and auto-renewal info

---

## Purchase Flow

```
User taps "Upgrade"
  → PurchaseSheet opens
  → User selects billing period
  → User taps "Subscribe Now"
  → StoreKit 2 purchase sheet (system UI)
  → User authenticates (Face ID / Password)
  → Transaction verified
  → Supabase database updated
  → UI refreshes with new tier
  → Sheet dismisses
```

---

## Subscription Management

### Upgrade Flow
Users can upgrade from:
- Seed (free) → Grow or Gold
- Grow → Gold

StoreKit handles prorated billing automatically.

### Downgrade Flow
Users manage subscriptions in iOS Settings:
- Settings → [User Name] → Subscriptions → Harvest

Downgrades take effect at the end of the current billing period.

### Cancellation
Users cancel in iOS Settings. App continues to provide premium features until subscription expires.

---

## Database Sync

### user_subscriptions Table
After successful purchase, updates:
- `tier_id`: Maps to `subscription_tiers.id` for grow/gold
- `status`: Set to `"active"`
- `started_at`: Timestamp of purchase
- `cancelled_at`: Cleared on new purchase

### Subscription Status Check
On app launch, `checkSubscriptionStatus()` verifies:
- Active subscriptions in StoreKit
- Database matches current entitlements
- Expired subscriptions are updated

---

## Error Handling

| Error | User Message | Action |
|-------|--------------|--------|
| User Cancelled | (none) | Dismiss silently |
| Purchase Pending | "Purchase pending approval" | Wait for parent approval |
| Verification Failed | "Transaction verification failed" | Contact support |
| Network Error | "Failed to complete purchase" | Retry |
| No Products | "Products unavailable" | Check internet, retry |

---

## Production Checklist

Before launching subscriptions:

- [ ] All 4 products created in App Store Connect
- [ ] Subscription group configured with correct hierarchy
- [ ] Prices match weekly/monthly pricing
- [ ] Localizations added for all supported languages
- [ ] Subscription terms reviewed and accurate
- [ ] Free trial configured (if offering)
- [ ] Promotional offers set up (if offering)
- [ ] Tested full purchase flow in TestFlight
- [ ] Tested restore purchases
- [ ] Tested subscription upgrades
- [ ] Tested subscription cancellation
- [ ] Verified database sync after purchase
- [ ] Verified feature gating works correctly
- [ ] App Privacy Policy includes subscription terms
- [ ] Customer support flow for subscription issues

---

## Testing Recommendations

### Sandbox Testing
1. Create sandbox test accounts in App Store Connect
2. Sign out of production Apple ID on test device
3. Use sandbox account for test purchases
4. Verify database updates correctly
5. Test restore purchases
6. Test subscription status sync

### TestFlight Testing
1. Upload build to TestFlight
2. Invite internal testers
3. Test full purchase flow with real payment methods (no charge in TestFlight)
4. Verify receipt validation
5. Test edge cases (poor network, cancelled purchases)

### Edge Cases to Test
- Purchase during poor network connectivity
- App force-quit during purchase
- Multiple devices with same account
- Subscription expires and user repurchases
- User restores on new device
- User upgrades from Grow to Gold
- User cancels and resubscribes

---

## Troubleshooting

### "Products not available"
- Check product IDs match exactly (case-sensitive)
- Verify products are approved in App Store Connect
- Check app bundle ID matches
- Verify StoreKit configuration file (if testing locally)

### "Transaction verification failed"
- Check receipt validation logic
- Verify app is signed correctly
- Check network connectivity
- Review device date/time settings

### Database not updating
- Check Supabase connection
- Verify user authentication
- Review error logs in `updateSubscriptionAfterPurchase()`
- Check RLS policies on `user_subscriptions` table

---

## Support Resources

- [StoreKit 2 Documentation](https://developer.apple.com/documentation/storekit)
- [App Store Connect Help](https://help.apple.com/app-store-connect/)
- [Subscription Best Practices](https://developer.apple.com/app-store/subscriptions/)
- [Testing In-App Purchases](https://developer.apple.com/documentation/storekit/in-app_purchase/testing_in-app_purchases)
