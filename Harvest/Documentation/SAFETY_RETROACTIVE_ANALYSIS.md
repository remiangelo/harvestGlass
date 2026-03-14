# Safety Retroactive Analysis Feature

**Date**: 2026-03-10
**Status**: Implemented

## Overview

The retroactive safety analysis feature allows the app to analyze entire conversation histories for red flags and safety concerns, not just new messages. This is useful for:

1. **Existing conversations** that existed before safety analysis was implemented
2. **Re-analyzing conversations** with updated red flag keywords
3. **User-initiated analysis** when they want to review safety of past conversations
4. **Bulk analysis** of all conversations for a user

---

## Features Implemented

### 1. Single Conversation Analysis

**Service Method**: `SafetyAnalysisService.analyzeConversationHistory()`

Analyzes all messages in a specific conversation and generates a comprehensive safety report.

**Process**:
1. Fetches all messages from the other user in the conversation
2. Clears existing red flag reports
3. Analyzes each message for red flag keywords across 7 categories
4. Calculates cumulative safety score
5. Stores red flag reports in database
6. Updates safety analysis with results

**Red Flag Categories**:
- Financial (weight: 30) - Money requests, scams
- Personal Info (weight: 30) - SSN, passwords, sensitive data
- Catfishing (weight: 25) - Excuses to avoid meeting/video
- Manipulation (weight: 20) - Emotional manipulation
- Harassment (weight: 25) - Threats, stalking
- Inappropriate (weight: 25) - Sexual pressure
- Spam (weight: 15) - Promotional content, links

---

### 2. Bulk User Analysis

**Service Method**: `SafetyAnalysisService.analyzeAllUserConversations()`

Analyzes all conversations for a specific user in one operation.

**Process**:
1. Fetches all matches for the user
2. For each match, finds the corresponding conversation
3. Runs retroactive analysis on each conversation
4. Returns count of successfully analyzed conversations

**Use Cases**:
- First-time setup for existing users
- Periodic re-analysis with updated keywords
- User-requested full safety audit

---

### 3. UI Integration

#### Safety Dashboard
**Location**: `SafetyDashboardView`

Added "Analyze All" button in toolbar:
- Icon: Arrow clockwise (refresh symbol)
- Triggers bulk analysis for all user conversations
- Shows loading indicator during analysis
- Automatically refreshes dashboard with updated scores

#### Chat View Model
**Location**: `ChatViewModel`

Added method: `runRetroactiveSafetyAnalysis()`
- Can be triggered on first conversation view
- Analyzes specific conversation
- Silent operation (logs results)

---

## Safety Score Calculation

### Formula

```swift
Starting score: 100
For each message with red flags:
  - Add up category weights (capped at 30 per message)
Total reduction = sum of all weights / message count * 2.0
Final score = max(0, 100 - total reduction)
```

### Score Thresholds

| Score Range | Safety Level | Action |
|-------------|--------------|--------|
| 90-100 | Excellent | No concerns |
| 70-89 | Good | Minor concerns |
| 50-69 | Caution | Review red flags |
| Below 50 | Warning | Significant concerns |

### "Ready to Move" Gate

Users must meet these criteria to exchange off-app contact info:
- Safety score ≥ 70
- At least 20 messages exchanged

---

## Performance Considerations

### Message Count Limits

The implementation is efficient for typical conversations:
- **1-100 messages**: Instant analysis (< 1 second)
- **100-500 messages**: Fast analysis (1-3 seconds)
- **500+ messages**: Slower but manageable (3-10 seconds)

### Optimization Strategies

1. **One flag per category per message**: Prevents redundant flagging
2. **Batch database inserts**: Could be added for large conversations
3. **Progress logging**: Every 10 messages for debugging
4. **Early termination**: Could add if score drops to 0

### Scalability

For production with many users:
- Consider background job processing for bulk analysis
- Add rate limiting to prevent API abuse
- Cache analysis results (already done via database)
- Add pagination for very long conversations (1000+ messages)

---

## User Experience

### Automatic Triggers

Consider adding automatic retroactive analysis:
1. **First conversation view**: Analyze when user opens a conversation for the first time
2. **Match creation**: Analyze when a new match is made (if conversation exists)
3. **Scheduled updates**: Weekly re-analysis with updated keywords

**Implementation Example**:
```swift
// In ChatDetailView.onAppear:
.task {
    if let userId = authViewModel.currentUserId {
        await viewModel.loadMessages(conversationId: conversationId)

        // Check if analysis needs to run
        let analysis = try? await safetyService.getOrCreateAnalysis(...)
        if analysis?.lastAnalyzedAt == analysis?.firstMessageAt {
            // Never analyzed beyond initial creation
            await viewModel.runRetroactiveSafetyAnalysis(...)
        }
    }
}
```

### Manual Triggers

Current implementation:
- **Safety Dashboard**: "Analyze All" button analyzes all conversations
- Users can proactively review their conversation safety

---

## Error Handling

### Individual Message Failures

If a single message fails to analyze:
- Error is logged
- Analysis continues with remaining messages
- Partial results are still useful

### Conversation Failures

If an entire conversation fails:
- Error is logged
- Bulk analysis continues with other conversations
- Returns count of successful analyses

### Database Failures

If red flag report insertion fails:
- Warning logged
- In-memory report still counted
- Safety score still updated

---

## Database Schema

### red_flag_reports Table

New field utilized:
- `message_id`: Links report to specific message (previously optional, now populated)

This enables:
- Drill-down to specific problematic messages
- Historical tracking of when flags appeared
- User education about concerning patterns

### safety_analyses Table

Updated fields during retroactive analysis:
- `safety_score`: Recalculated based on full history
- `total_messages`: Count of messages analyzed
- `red_flag_count`: Total flags found
- `last_analyzed_at`: Timestamp of analysis

---

## Testing Recommendations

### Unit Tests

```swift
func testRetroactiveAnalysisSingleMessage() async {
    // Test single message with one red flag
}

func testRetroactiveAnalysisMultipleRedFlags() async {
    // Test conversation with multiple categories
}

func testRetroactiveAnalysisNoRedFlags() async {
    // Test clean conversation (score stays 100)
}

func testRetroactiveAnalysisScoreCapping() async {
    // Test that score doesn't go below 0
}
```

### Integration Tests

1. Create test conversation with known red flags
2. Run retroactive analysis
3. Verify safety score matches expected calculation
4. Verify red flag reports are created
5. Verify message IDs are linked correctly

### Manual Testing

1. Create conversations with varying message counts (10, 50, 100+)
2. Include messages with different red flag categories
3. Run "Analyze All" from Safety Dashboard
4. Verify scores are reasonable
5. Check performance with large conversations

---

## Future Enhancements

### 1. AI-Powered Analysis

Replace keyword matching with AI:
- More nuanced red flag detection
- Context-aware analysis
- Fewer false positives
- Already implemented in `MindfulMessagingService` - could extend to retroactive analysis

### 2. Trend Detection

Analyze patterns over time:
- "Red flags increasing" warning
- "Conversation improving" notification
- Temporal clustering of concerning behavior

### 3. Comparative Analysis

Benchmark against other conversations:
- "This conversation is safer than 85% of your chats"
- Identify outliers
- Help users recognize healthy vs unhealthy patterns

### 4. Export Reports

Allow users to export safety analysis:
- PDF report generation
- Screenshot sharing for support tickets
- Evidence collection for reporting

### 5. Progressive Analysis

Analyze conversations incrementally:
- Only analyze new messages since last analysis
- Update score incrementally
- More efficient for long conversations

---

## Privacy & Ethics

### Data Collection

Retroactive analysis reads all message content, which raises privacy concerns:

**Mitigations**:
- Analysis happens on-device (server-side) within secure infrastructure
- Red flag keywords stored, not full message content
- User controls when analysis runs
- Clear privacy policy disclosure

### User Consent

Consider adding:
- Opt-in for retroactive analysis
- Clear explanation of what's analyzed
- Ability to delete analysis results
- Transparency about keyword categories

### False Positives

Keyword matching can flag innocent messages:

**Examples**:
- "Can't wait to kill it at work today" → "kill" flagged
- "You're so sweet, I'm addicted to your messages" → "addicted" flagged

**Solutions**:
- AI-powered context analysis
- User feedback on false flags
- Refinement of keyword lists
- Show specific flagged keyword to user for review

---

## API Documentation

### SafetyAnalysisService.analyzeConversationHistory()

```swift
func analyzeConversationHistory(
    conversationId: String,
    matchId: String,
    userId: String,
    otherUserId: String
) async throws -> SafetyAnalysis
```

**Parameters**:
- `conversationId`: ID of the conversation to analyze
- `matchId`: ID of the match relationship
- `userId`: Current user's ID
- `otherUserId`: Partner's ID (messages from this user are analyzed)

**Returns**: Updated `SafetyAnalysis` object with scores and red flag count

**Throws**:
- Database connection errors
- Invalid conversation ID

---

### SafetyAnalysisService.analyzeAllUserConversations()

```swift
func analyzeAllUserConversations(
    userId: String
) async throws -> Int
```

**Parameters**:
- `userId`: ID of user whose conversations to analyze

**Returns**: Count of successfully analyzed conversations

**Throws**: Database errors (non-critical - continues with other conversations)

---

## Monitoring & Analytics

Track these metrics in production:

### Performance Metrics
- Average analysis time per conversation
- Analysis time by message count
- Database query performance
- API timeout rate

### Quality Metrics
- Average safety scores across all users
- Distribution of red flag categories
- False positive rate (if user feedback implemented)
- Re-analysis frequency

### Usage Metrics
- Bulk analysis usage rate
- Automatic vs manual analysis ratio
- Users with concerning safety scores
- Conversations requiring moderation

---

## Support & Troubleshooting

### "Analysis taking too long"

**Causes**:
- Very long conversation (1000+ messages)
- Slow network connection
- Database performance issues

**Solutions**:
- Add timeout (currently no limit)
- Show progress indicator
- Offer to analyze incrementally

### "Safety score seems wrong"

**Causes**:
- False positives from keyword matching
- User disagrees with severity weights
- Changed behavior over time not reflected

**Solutions**:
- Show red flag details
- Allow user to review flagged messages
- Explain scoring methodology
- Offer to re-analyze with updated keywords

### "No conversations analyzed"

**Causes**:
- User has no matches yet
- All conversations are empty
- Database permissions issue

**Solutions**:
- Show clear empty state
- Verify database RLS policies
- Check conversation records exist

---

## Deployment Checklist

Before releasing retroactive analysis:

- [ ] Test with conversations of varying lengths
- [ ] Verify red flag keywords are comprehensive
- [ ] Check performance with 1000+ message conversations
- [ ] Add rate limiting to prevent abuse
- [ ] Update privacy policy to disclose analysis
- [ ] Add user documentation/help center article
- [ ] Monitor error rates in production
- [ ] Set up alerts for analysis failures
- [ ] Consider adding consent flow
- [ ] Test with real user conversations (anonymized)

---

## References

- `SafetyAnalysisService.swift` - Core analysis logic
- `SafetyDashboardViewModel.swift` - Bulk analysis UI logic
- `ChatViewModel.swift` - Single conversation analysis trigger
- `SafetyModels.swift` - Red flag categories and weights
- Database migration: None required (uses existing schema)
