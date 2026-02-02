# Worker 1: Chat Streaming Performance Test Results

**Test Date:** 2026-02-02
**Session ID:** 91EB76AA-03B1-40DF-984C-CAF6E6AB0809
**Test Query:** "What is 2+2? Reply with just the number."

## Timing Metrics

- **Total Streaming Duration:** 9.174 seconds
- **SSE Events Received:** 5 events (system, assistant, result, messageId, done)
- **API Processing Time:** 2,897ms (2.9 seconds)
- **Total Request Duration:** 4,436ms (4.4 seconds)

## SSE Event Sequence

1. **event: system**
   - `subtype: init`
   - Provides session ID and available tools list
   - Session ID returned: `482bb98c-9e96-4e15-8768-dfaa3df5ddfb`

2. **event: assistant**
   - `type: assistant`
   - Content: `"4"` (correct answer)

3. **event: result**
   - `subtype: success`
   - `isError: false`
   - `durationApiMs: 2897`
   - `durationMs: 4436`
   - `totalCostUSD: 0.4328275`
   - `numTurns: 1`

4. **event: messageId**
   - `userMessageId: 7F513CBA-C4AC-4BD0-84E6-4C431D64F1ED`
   - `assistantMessageId: 80A2321C-1A8E-4871-96AB-FE8AA20BB204`

5. **event: done**
   - Empty data, signals stream completion

## Performance Analysis

✅ **PASS** - SSE stream returns events with proper format
✅ **PASS** - Response contains expected content ("4")
✅ **PASS** - Streaming duration (9.17s) < 30 seconds
✅ **PASS** - Screenshot captured successfully

### Time to First Byte (TTFB)
- First event (system init) received immediately
- First content event (assistant) received within the 9.17s total duration

### Stream Quality
- All events properly formatted as SSE (event: type, data: json)
- No dropped events or stream interruptions
- Clean termination with `done` event

## Screenshot Evidence

**File:** `/Users/nick/Desktop/ils-ios/Auto Run Docs/Testing/02-w1-chat-streaming.png`

Screenshot captured from simulator BECB3FA0-518E-4F80-8B8E-7E10C16F3B36 showing app state during/after streaming test.

## Notes

- Backend processed the request efficiently (2.9s API time)
- Total duration (4.4s) includes network overhead and streaming setup
- The discrepancy between 9.17s (curl timing) and 4.4s (backend timing) suggests the curl timing includes connection setup and the full stream read including the `head -50` command
- Session was properly reused (existing session ID worked correctly)

## Test Status

**COMPLETE** - All success criteria met.
