# Harvest - Project Status

> Last updated: March 26, 2026

## Codebase Summary

| Category | Count |
|----------|-------|
| Views | 47 |
| ViewModels | 12 |
| Services | 15 |
| Models | 11 |
| Other (Config, Theme, App) | 3 |
| **Total Swift source files** | **88** |

---

## Completed Features

### Authentication
- [x] Email/password sign-up and login (`LoginView`, `AuthViewModel`, `AuthService`)
- [x] Supabase Auth integration (`SupabaseManager`, `Config.swift`)
- [x] Custom URL scheme callback (`harvestapp://`)

### Onboarding Flow
- [x] Multi-step onboarding container (`OnboardingContainerView`, `OnboardingViewModel`)
- [x] Nickname entry (`NicknameStepView`)
- [x] Age input (`AgeStepView`)
- [x] Gender selection (`GenderStepView`)
- [x] Interested-in preference (`InterestedInStepView`)
- [x] Location / city entry (`LocationStepView`)
- [x] Photo upload with Supabase Storage (`PhotosStepView`)
- [x] Terms acceptance (`TermsStepView`)
- [x] Goals selection (`GoalsStepView`)
- [x] Completion screen with profile finalization (`CompleteView`)

### Discover / Swiping
- [x] Swipe card UI (`SwipeCardView`, `DiscoverView`)
- [x] Profile detail modal (`ProfileDetailView`)
- [x] Match modal on mutual like (`MatchModalView`)
- [x] Compatibility-ranked profiles (`CompatibilityService`, `SwipeService`)
- [x] Swipe recording (`Swipe` model, `SwipeService`)
- [x] Rate-limited matches per tier (`RateLimitService`)

### Compatibility Matching
- [x] Multi-factor scoring algorithm (`CompatibilityService`)
  - Interests: 40 pts | Values: 30 pts | Goals: 15 pts | Age: 10 pts | Distance: 5 pts
- [x] Profiles sorted by compatibility score in Discover feed

### Chat / Messaging
- [x] Conversation list (`ChatListView`, `ChatViewModel`)
- [x] Real-time message exchange (`ChatDetailView`, `ChatService`)
- [x] Message bubbles with timestamps (`MessageBubbleView`)
- [x] Typing indicator (`TypingIndicatorView`)
- [x] Report user flow (`ReportUserView`)

### Matches
- [x] Matches list view (`MatchesView`, `MatchesViewModel`)
- [x] Match model and service (`Match`, `MatchService`)

### Gardener AI Coach
- [x] Chat interface (`GardenerChatView`, `GardenerViewModel`)
- [x] Daily quiz popup (`DailyQuizPopup`)
- [x] Dating tips view (`TipsView`, `TipsViewModel`)
- [x] Values questionnaire (`ValuesQuestionnaireView`)
- [x] OpenAI service integration (`OpenAIService`, `GardenerService`)
- [x] Rate-limited conversations per tier (`RateLimitService`)

### Safety System
- [x] Safety dashboard (`SafetyDashboardView`, `SafetyDashboardViewModel`)
- [x] Safety warning view (`SafetyWarningView`)
- [x] Ready-to-move gate (`ReadyToMoveGateView`)
- [x] Red flag detection and analysis (`SafetyAnalysisService`)
- [x] Retroactive conversation analysis
- [x] Mindful messaging warnings (`MindfulWarningView`, `MindfulMessagingService`)

### Subscriptions & Monetization
- [x] StoreKit 2 integration (`SubscriptionService`, `SubscriptionViewModel`)
- [x] Subscription tiers: Seed (free) / Green / Gold (`SubscriptionTier` model)
- [x] Purchase sheet UI (`PurchaseSheet`)
- [x] Subscription management view (`SubscriptionView`)
- [x] Premium gate component (`PremiumGateView`)
- [x] Transaction verification and database sync
- [x] Restore purchases support
- [x] Product IDs: `com.harvestglass.harvest.{tier}.{period}`

### Profile
- [x] Profile view (`ProfileView`, `ProfileViewModel`)
- [x] Profile editing (`ProfileEditView`)
- [x] Interest picker (`InterestPickerView`)
- [x] Photo grid display (`ProfilePhotoGrid`)
- [x] Profile service with upsert fallback (`ProfileService`)

### Filters
- [x] Filter preferences UI (`FiltersView`, `FiltersViewModel`)
- [x] Filter persistence as JSON blob (`FilterService`, `FilterPreferences` model)

### Settings
- [x] Settings view (`SettingsView`)
- [x] Account deletion with table-by-table cleanup (11 tables)

### Legal
- [x] Terms of Service (`TermsOfServiceView`)
- [x] Privacy Policy (`PrivacyPolicyView`)
- [x] Community Guidelines (`CommunityGuidelinesView`)

### Help
- [x] Help center (`HelpCenterView`, `HelpCenterViewModel`)

### UI / Theme
- [x] Glass morphism design system (`HarvestTheme`)
- [x] Reusable components: `GlassButton`, `GlassCard`, `GlassBadge`, `ChipView`
- [x] Main tab navigation (`MainTabView`)

### Values System
- [x] Values service (`ValuesService`)
- [x] Value model (`Value`)

---

## Recently Fixed

| Fix | Files Changed | Commit |
|-----|---------------|--------|
| Onboarding "Start Exploring" not navigating to main app | `CompleteView`, `OnboardingViewModel` | `b33b338` |
| Sign-out button on onboarding (escape hatch for stuck users) | `OnboardingContainerView` | `8efbe54` |
| Upsert fallback for missing profiles | `ProfileService` | `8efbe54` |
| App icon added + build errors fixed | Asset catalog, `project.pbxproj` | `8d06628` |
| CLAUDE.md duplicate output build error | `project.pbxproj` | `8d06628` |

---

## In Progress / Needs Testing

| Item | Status | Notes |
|------|--------|-------|
| End-to-end onboarding flow | Needs testing | Sign up -> onboarding -> main app; recent bug fixes should resolve navigation |
| StoreKit 2 purchase flow | Needs TestFlight | Cannot fully test in simulator; requires App Store Connect products |
| OpenAI Gardener integration | Placeholder API key | `Config.swift` has `"YOUR_OPENAI_API_KEY"`; service code is complete |
| Photo upload reliability | Needs testing | Recently fixed; uses Supabase Storage bucket `profile-photos` |

---

## Testing Infrastructure

| Component | Status | Details |
|-----------|--------|---------|
| `CompatibilityServiceTests` | 18 tests passing | Interest, values, goals, age scoring + ranking |
| `SafetyAnalysisServiceTests` | Test stubs written | Red flag categories, weights, edge cases; 7 tests need mocked Supabase |
| `MockSupabaseClient` | Complete | Factory methods for test users, values, tiers; call tracking |
| `HarvestTests` | Template only | Default Xcode test file |

---

## Pre-Launch TODO

### Required

- [ ] **App Store Connect**: Create 4 subscription products matching product IDs
  - `com.harvestglass.harvest.green.monthly`
  - `com.harvestglass.harvest.green.yearly`
  - `com.harvestglass.harvest.gold.monthly`
  - `com.harvestglass.harvest.gold.yearly`
- [ ] **OpenAI API key**: Replace placeholder in `Config.swift`
- [ ] **TestFlight**: Full purchase flow testing with sandbox accounts
- [ ] **End-to-end test**: Complete sign-up through onboarding to main app

### Recommended

- [ ] **Accessibility audit**: VoiceOver support, Dynamic Type, color contrast
- [ ] **UI polish pass**: Animations, loading states, empty states
- [ ] **Test coverage expansion**: ChatService, AuthService, ProfileService
  - Complete `SafetyAnalysisServiceTests` stubs with mocked Supabase
- [ ] **Error handling review**: Ensure user-facing errors are clear and actionable
- [ ] **Analytics integration**: Track key user events and funnel metrics

### Nice to Have

- [ ] **Push notifications**: Match alerts, new messages, Gardener reminders
- [ ] **Deep linking**: Handle `harvestapp://` URLs for matches and chats
- [ ] **Offline support**: Cache profiles and messages for spotty connectivity
- [ ] **Localization**: String catalogs for multi-language support
- [ ] **Performance profiling**: Image loading, scroll performance, memory usage

---

## Architecture Reference

```
Harvest/
├── Config.swift                    # Supabase + OpenAI configuration
├── HarvestApp.swift                # App entry point
├── Theme/
│   └── HarvestTheme.swift          # Glass morphism design system
├── Models/          (11 files)     # Data models (Codable structs)
├── Services/        (15 files)     # Business logic + API calls
├── ViewModels/      (12 files)     # UI state management
└── Views/           (47 files)     # SwiftUI views
    ├── Auth/                       # Login
    ├── Chat/                       # Messaging
    ├── Components/                 # Reusable UI
    ├── Discover/                   # Swiping
    ├── Filters/                    # Search filters
    ├── Gardener/                   # AI coach
    ├── Help/                       # Help center
    ├── Legal/                      # ToS, Privacy, Guidelines
    ├── Matches/                    # Match list
    ├── Onboarding/                 # 9-step onboarding
    ├── Profile/                    # User profile
    ├── Safety/                     # Safety dashboard
    ├── Settings/                   # App settings
    └── Subscription/               # Payments
```

---

## Subscription Tiers

| Tier | Matches/Week | Gardener Chats/Day | Char Limit |
|------|-------------|-------------------|------------|
| Seed (Free) | 10 | 1 | 1,000 |
| Green | 50 | 5 | 3,000 |
| Gold | Unlimited | Unlimited | 10,000 |

---

## Related Documentation

- [StoreKit Setup Guide](STOREKIT_SETUP.md)
- [Safety Retroactive Analysis](SAFETY_RETROACTIVE_ANALYSIS.md)
- [Testing Guide](TESTING_GUIDE.md)
- [Error Handling Improvements](ERROR_HANDLING_IMPROVEMENTS.md)
