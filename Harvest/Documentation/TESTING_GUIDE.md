## Testing Guide for Harvest App

**Date**: 2026-03-10
**Status**: Test Infrastructure Created

---

## Overview

This document outlines the testing strategy and implementation for the Harvest dating app. We use XCTest framework for unit and integration tests.

---

## Test Structure

```
HarvestTests/
├── Services/           # Service layer tests
│   ├── CompatibilityServiceTests.swift
│   ├── SafetyAnalysisServiceTests.swift
│   └── RateLimitServiceTests.swift
├── ViewModels/         # ViewModel tests
│   ├── DiscoverViewModelTests.swift
│   └── GardenerViewModelTests.swift
└── Mocks/              # Mock objects and test helpers
    └── MockSupabaseClient.swift
```

---

## Running Tests

### Xcode
```bash
# Run all tests
⌘ + U

# Run specific test suite
⌘ + Click on test class/method → "Run"

# Run tests from terminal
xcodebuild test -scheme Harvest -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Continuous Integration
```bash
# GitHub Actions / CI pipeline
- Run on every PR
- Run on main branch commits
- Fail build if tests fail
```

---

## Test Coverage Goals

### Critical Services (Required: 80%+ coverage)
- ✅ **CompatibilityService**: Pure logic, fully testable
- ✅ **SafetyAnalysisService**: Red flag detection logic
- ⚠️ **RateLimitService**: Requires database mocking
- ⚠️ **AuthService**: Requires Supabase auth mocking

### ViewModels (Required: 60%+ coverage)
- ⚠️ **DiscoverViewModel**: Swipe logic and compatibility
- ⚠️ **GardenerViewModel**: Rate limiting and chat logic
- ⚠️ **ChatViewModel**: Mindful messaging integration

### Views (Optional: UI tests)
- Manual testing preferred
- Critical flows: Onboarding, Match, Chat

---

## Implemented Tests

### CompatibilityServiceTests.swift
**Status**: ✅ Complete (18 tests)

**Coverage**:
- Interest/hobby scoring (6 tests)
- Values alignment scoring (3 tests)
- Goals scoring (3 tests)
- Age compatibility scoring (4 tests)
- Total score calculation (2 tests)
- Profile ranking (1 test)

**Key Test Cases**:
```swift
func testInterestScore_AllSharedInterests()
func testValuesScore_PerfectMatch()
func testGoalsScore_MultipleSharedGoals()
func testAgeScore_SmallDifference()
func testTotalScore_ExcellentMatch()
func testRankProfiles_SortsByCompatibility()
```

**Run Time**: < 1 second

---

### SafetyAnalysisServiceTests.swift
**Status**: ⚠️ Partial (Test stubs created, needs mocking)

**Coverage**:
- Red flag detection (7 categories)
- Safety score calculation
- Ready-to-move gate logic
- Retroactive analysis performance
- Edge cases (empty, long messages, unicode)

**Key Test Cases**:
```swift
func testDetectsFinancialRedFlags_SendMoney()
func testDetectsManipulationRedFlags_IfYouLovedMe()
func testDetectsHarassmentRedFlags_Threats()
func testMultipleRedFlags_DifferentCategories()
func testSafetyScore_ReducesWithRedFlags()
func testReadyToMove_RequiresMinimumMessages()
```

**Blocked By**: Need MockSupabaseClient implementation

---

## Mock Infrastructure

### MockSupabaseClient
**Location**: `HarvestTests/Mocks/MockSupabaseClient.swift`
**Status**: ✅ Created

**Features**:
- In-memory data storage
- Method call tracking
- Test data factories

**Usage Example**:
```swift
let mockClient = MockSupabaseClient()
mockClient.addMockUser(
    MockSupabaseClient.createTestUser(
        id: "test-user",
        hobbies: ["Reading", "Hiking"]
    )
)
```

**Test Helpers**:
```swift
static func createTestUser(...) -> UserProfile
static func createTestValue(...) -> Value
static func createTestTier(...) -> SubscriptionTier
```

---

## Test Categories

### Unit Tests
**Purpose**: Test individual functions/methods in isolation

**Examples**:
- Compatibility score calculation
- Red flag keyword matching
- Rate limit validation logic
- Values alignment algorithm

**Characteristics**:
- Fast (< 0.1s per test)
- No external dependencies
- Deterministic results

---

### Integration Tests
**Purpose**: Test interactions between components

**Examples**:
- SwipeService → CompatibilityService → Database
- ChatViewModel → MindfulMessagingService → OpenAI
- AuthService → Supabase → Database cascade deletes

**Characteristics**:
- Slower (0.5-2s per test)
- May require test database
- Test data setup/teardown

---

### UI Tests
**Purpose**: Test user-facing workflows

**Examples**:
- Complete onboarding flow
- Swipe and match flow
- Send message and see response
- Purchase subscription

**Characteristics**:
- Very slow (10-30s per test)
- Brittle (UI changes break tests)
- Best for critical user paths

---

## Critical Test Scenarios

### 1. Compatibility Scoring
**Priority**: 🔴 Critical

**Test Cases**:
- [x] Users with identical hobbies get high score
- [x] Users with no shared interests get low score
- [x] Values matching works bidirectionally
- [x] Age difference affects score appropriately
- [x] Profiles ranked by compatibility

**Status**: ✅ Complete

---

### 2. Safety Analysis
**Priority**: 🔴 Critical

**Test Cases**:
- [ ] Financial red flags detected (send money, bitcoin, etc.)
- [ ] Personal info red flags detected (SSN, passwords)
- [ ] Manipulation red flags detected (if you loved me)
- [ ] Harassment threats detected
- [ ] Safety score reduces with red flags
- [ ] Ready-to-move gate enforces minimums
- [ ] Retroactive analysis works for full conversation

**Status**: ⚠️ Partial (stubs created, needs database mocking)

---

### 3. Rate Limiting
**Priority**: 🟠 High

**Test Cases**:
- [ ] Character limit enforced for Gardener messages
- [ ] Daily conversation limit enforced
- [ ] Weekly match limit enforced
- [ ] Limits vary by subscription tier
- [ ] Unlimited tiers have no limits
- [ ] Error messages clear and actionable

**Status**: ⏳ Not started

---

### 4. Authentication Flow
**Priority**: 🟠 High

**Test Cases**:
- [ ] OAuth callback handled correctly
- [ ] Session persists across app launches
- [ ] Account deletion cascades to all tables
- [ ] Sign out clears local state
- [ ] Expired session handled gracefully

**Status**: ⏳ Not started (requires Supabase auth mocking)

---

### 5. Payment Processing
**Priority**: 🟠 High

**Test Cases**:
- [ ] StoreKit products load correctly
- [ ] Purchase flow completes successfully
- [ ] Transaction verification works
- [ ] Database updated after purchase
- [ ] Restore purchases works
- [ ] Subscription status syncs on launch

**Status**: ⏳ Not started (requires StoreKit testing environment)

---

## Testing Best Practices

### 1. Arrange-Act-Assert (AAA) Pattern
```swift
func testExample() {
    // Arrange: Set up test data
    let user = MockSupabaseClient.createTestUser(age: 28)

    // Act: Execute the code under test
    let result = service.calculateScore(user)

    // Assert: Verify the outcome
    XCTAssertEqual(result, expectedValue)
}
```

### 2. Test One Thing
Each test should verify one specific behavior:
```swift
// Good
func testInterestScore_NoSharedInterests()
func testInterestScore_AllSharedInterests()

// Bad
func testInterestScoring() // Tests everything at once
```

### 3. Use Descriptive Names
```swift
// Good
func testCompatibilityScore_WithSharedHobbiesAndValues_ReturnsHighScore()

// Bad
func testScore()
```

### 4. Avoid Test Interdependence
Tests should be able to run in any order:
```swift
// Bad
static var sharedState: Int = 0

func testA() {
    sharedState = 5 // Test B depends on this
}

func testB() {
    XCTAssertEqual(sharedState, 5) // Fails if testA doesn't run first
}
```

### 5. Keep Tests Fast
- Unit tests: < 0.1s
- Integration tests: < 2s
- UI tests: < 30s

Slow tests won't get run as often.

---

## Mocking Strategies

### 1. Protocol-Based Mocking
```swift
protocol UserServiceProtocol {
    func getUser(id: String) async throws -> User
}

class MockUserService: UserServiceProtocol {
    var mockUser: User?

    func getUser(id: String) async throws -> User {
        guard let user = mockUser else {
            throw TestError.noMockData
        }
        return user
    }
}
```

### 2. Dependency Injection
```swift
// Before (hard to test)
class ViewModel {
    let service = UserService() // Hardcoded dependency
}

// After (testable)
class ViewModel {
    let service: UserServiceProtocol

    init(service: UserServiceProtocol = UserService()) {
        self.service = service
    }
}

// In tests
let viewModel = ViewModel(service: MockUserService())
```

---

## Code Coverage

### Viewing Coverage
1. Enable coverage in Xcode:
   - Product → Scheme → Edit Scheme
   - Test → Options → Code Coverage
   - Check "Gather coverage for some targets"

2. View report:
   - Run tests (⌘ + U)
   - Open Report Navigator (⌘ + 9)
   - Select test run → Coverage tab

### Coverage Goals
- **Services**: 80%+ (pure logic, fully testable)
- **ViewModels**: 60%+ (some UI dependencies)
- **Views**: 20%+ (mostly manual testing)
- **Overall**: 60%+

---

## Continuous Integration

### GitHub Actions Workflow
```yaml
name: Run Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest

    steps:
    - uses: actions/checkout@v3

    - name: Run tests
      run: |
        xcodebuild test \
          -scheme Harvest \
          -destination 'platform=iOS Simulator,name=iPhone 15' \
          -enableCodeCoverage YES

    - name: Upload coverage
      uses: codecov/codecov-action@v3
```

---

## Future Testing Enhancements

### 1. Snapshot Testing
Test UI layouts don't break:
```swift
func testProfileCardLayout() {
    let view = ProfileCardView(profile: mockProfile)
    assertSnapshot(matching: view, as: .image)
}
```

### 2. Performance Testing
```swift
func testDiscoverProfileLoading_Performance() {
    measure {
        // Code to measure
    }
    // XCTest will report avg time, std dev
}
```

### 3. Network Mocking
Use frameworks like:
- OHHTTPStubs for URLSession
- Mocked Supabase responses

### 4. UI Automation
```swift
func testOnboardingFlow() {
    let app = XCUIApplication()
    app.launch()

    app.buttons["Get Started"].tap()
    app.textFields["Nickname"].typeText("TestUser")
    // ... complete flow
}
```

---

## Common Testing Pitfalls

### 1. Testing Implementation Instead of Behavior
```swift
// Bad: Tests internal implementation
func testServiceUsesCorrectURL() {
    XCTAssertEqual(service.baseURL, "https://api.example.com")
}

// Good: Tests behavior
func testServiceFetchesUserData() async throws {
    let user = try await service.getUser(id: "123")
    XCTAssertEqual(user.name, "Test User")
}
```

### 2. Overly Complex Test Setup
If setup is complex, extract to helper methods:
```swift
func createTestScenario() -> (user: User, matches: [Match], messages: [Message]) {
    // Complex setup here
}

func testMatchesDisplay() {
    let scenario = createTestScenario()
    // Test with scenario.user, scenario.matches, etc.
}
```

### 3. Ignoring Async/Await
```swift
// Bad: Doesn't wait for async
func testAsyncFunction() {
    service.fetchData() // Returns immediately
    XCTAssertNotNil(service.data) // Will fail
}

// Good: Properly awaits
func testAsyncFunction() async throws {
    try await service.fetchData()
    XCTAssertNotNil(service.data)
}
```

---

## Resources

- [XCTest Documentation](https://developer.apple.com/documentation/xctest)
- [Testing with Async/Await](https://developer.apple.com/videos/play/wwdc2021/10132/)
- [UI Testing in Xcode](https://developer.apple.com/library/archive/documentation/DeveloperTools/Conceptual/testing_with_xcode/)
- [Test-Driven Development Guide](https://www.raywenderlich.com/books/ios-test-driven-development-by-tutorials)

---

## Getting Started

### For New Contributors
1. Read this guide
2. Run existing tests to verify setup (⌘ + U)
3. Write tests for new features BEFORE implementation
4. Aim for 80%+ coverage on new code
5. Run tests before committing

### When Fixing Bugs
1. Write a failing test that reproduces the bug
2. Fix the bug
3. Verify test now passes
4. Commit both test and fix together

---

## Test Maintenance

### Monthly Review
- Remove obsolete tests
- Update mocks for API changes
- Refactor duplicated test code
- Check coverage reports

### Red-Green-Refactor Cycle
1. 🔴 Red: Write failing test
2. 🟢 Green: Make test pass (minimal code)
3. 🔵 Refactor: Improve code while keeping tests green

---

## Summary

**Current Status**:
- ✅ Test infrastructure created
- ✅ Mock helpers implemented
- ✅ Compatibility tests complete (18 tests)
- ⚠️ Safety tests stubbed (needs mocking)
- ⏳ Rate limit tests not started
- ⏳ Integration tests not started

**Next Steps**:
1. Complete MockSupabaseClient implementation
2. Write rate limiting tests
3. Integrate tests into CI/CD pipeline
4. Add UI automation for critical flows
5. Achieve 60%+ overall code coverage
