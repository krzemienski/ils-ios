# Memory Profiling Guide for ILS iOS App

This guide covers how to profile memory usage in the ILS iOS app using Xcode Instruments, interpret the results, and verify that memory stays within acceptable bounds during extended usage.

## Expected Memory Baseline

**Target:** Peak memory usage should stay **under 200MB** during normal usage
**24-Hour Test:** No unbounded growth over extended sessions
**Cache Limit:** Default 50MB (configurable 25MB - 100MB)

---

## Quick Start

```bash
# 1. Build the app for profiling
xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build

# 2. Launch Instruments from Xcode
# Product > Profile (Cmd+I)

# 3. Select "Allocations" template

# 4. Run and monitor for 24 hours
```

---

## Setting Up Xcode Instruments

### Option 1: Profile from Xcode (Recommended)

1. **Open the Project**
   ```bash
   cd /path/to/ils-ios
   open ILSApp/ILSApp.xcodeproj
   ```

2. **Select the Target Device**
   - Choose "ILSApp" scheme
   - Select destination: `iPhone 16 Pro Max (UDID: 50523130-57AA-48B0-ABD0-4D59CE455F14)`
   - This is our dedicated testing simulator

3. **Build for Profiling**
   - Menu: **Product > Profile** (or `Cmd+I`)
   - Xcode will build in Release mode (optimized)
   - Instruments will launch automatically

4. **Choose Profiling Template**
   - Select **"Allocations"** for memory usage tracking
   - For leak detection, also run **"Leaks"** separately
   - For comprehensive analysis, use **"Memory Graph"**

### Option 2: Launch Instruments Directly

```bash
# Launch Instruments
open -a Instruments

# Select template: File > New > Allocations
# Attach to running app or launch the app from Instruments
```

---

## Memory Profiling Templates

### 1. Allocations (Primary Tool)

**Purpose:** Track memory allocations, deallocations, and growth over time

**What to Monitor:**
- **All Heap & Anonymous VM:** Total memory allocated by the app
- **Live Bytes:** Current memory in use (should not grow unbounded)
- **Persistent Bytes:** Memory that never gets deallocated (potential leaks)
- **Transient Bytes:** Memory that gets allocated and freed

**How to Use:**
1. Launch Allocations template
2. Start recording (red circle button)
3. Perform test scenarios (see below)
4. Monitor "Live Bytes" graph in real-time
5. Take memory snapshots at regular intervals
6. Compare snapshots to detect growth

### 2. Leaks (Secondary Tool)

**Purpose:** Detect memory leaks (allocated memory with no references)

**What to Look For:**
- Red "Leak" markers in timeline
- Leaked objects in the details pane
- Should show **zero leaks** during normal operation

**How to Use:**
1. Launch Leaks template (runs alongside Allocations)
2. Leaks automatically scans every 10 seconds
3. If leaks detected, click to see backtrace
4. Fix any leaks in identified code paths

### 3. VM Tracker (Advanced)

**Purpose:** Track virtual memory regions (useful for low-level analysis)

**When to Use:**
- If memory exceeds 200MB baseline
- To identify large allocations
- To see memory fragmentation

---

## 24-Hour Test Procedure

### Overview

Simulate realistic usage over a 24-hour period to verify:
- ✅ No unbounded memory growth
- ✅ Cache eviction works correctly
- ✅ Memory warnings trigger cache clearing
- ✅ Peak usage stays under 200MB

### Setup

```bash
# 1. Clean build for profiling
cd /path/to/ils-ios
xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' clean build

# 2. Ensure backend is running
curl http://localhost:9999/health
# Should return: OK

# 3. Launch Instruments with Allocations template
# Product > Profile (Cmd+I) > Allocations
```

### Test Scenarios (Automated Loop)

Run these scenarios in a loop for 24 hours:

#### Scenario 1: Normal API Usage (30 minutes)
```
1. Fetch sessions list (10 times)
2. Open a session detail
3. Fetch projects list (10 times)
4. Open a project detail
5. Scroll through chat messages
6. Navigate to settings
7. Return to home
8. Wait 2 minutes (app idle)
```

**Expected Memory:** 80-120MB during activity, drops to 60-80MB during idle

#### Scenario 2: Heavy API Load (15 minutes)
```
1. Rapid API calls (sessions, projects, chat)
2. Cache should fill to ~50MB
3. NSCache should evict old entries (LRU)
4. Memory should stabilize, not grow unbounded
```

**Expected Memory:** 100-150MB during load, cache evicts older entries

#### Scenario 3: Background + Memory Warning (5 minutes)
```
1. Send app to background (Cmd+Shift+H in simulator)
2. Trigger memory warning:
   - Simulator menu: Debug > Simulate Memory Warning
3. Bring app to foreground
4. Verify cache was cleared (check Settings > Memory Usage)
```

**Expected Memory:** Drops to <50MB after memory warning

#### Scenario 4: Extended Idle (10 minutes)
```
1. Leave app in foreground, no interaction
2. Monitor for memory creep
3. Should remain stable
```

**Expected Memory:** Stable at 60-80MB

### Automated Test Script (Optional)

For truly unattended 24-hour testing, use UI automation:

```bash
# Create a UI test that loops through scenarios
xcodebuild test -project ILSApp/ILSApp.xcodeproj \
  -scheme ILSApp \
  -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' \
  -only-testing:ILSAppUITests/MemoryStressTests
```

**Manual simulation is recommended** for the first 24-hour test to observe behavior.

---

## Interpreting Results

### Memory Usage Graph

**Healthy Pattern:**
```
Memory (MB)
200 |
    |
150 |     /\    /\    /\
    |    /  \  /  \  /  \
100 |   /    \/    \/    \___
    |  /                      \___
 50 |_/                           \___
    +---------------------------------> Time
    0h   6h   12h  18h  24h
```
- Peaks during activity (API calls)
- Drops during idle (cache eviction)
- **Overall trend is FLAT** (no growth)

**Unhealthy Pattern (Unbounded Growth):**
```
Memory (MB)
200 |                            /
    |                          /
150 |                    /----
    |              /----
100 |        /----
    |  /----
 50 |/
    +---------------------------------> Time
    0h   6h   12h  18h  24h
```
- ❌ Continuous upward trend
- ❌ No memory release during idle
- ❌ Indicates leak or unbounded cache

### Key Metrics

| Metric | Target | Action if Exceeded |
|--------|--------|-------------------|
| **Peak Memory** | < 200MB | Reduce cache size, optimize allocations |
| **Idle Memory** | < 80MB | Check for retained objects, profile allocations |
| **Cache Size** | < 50MB (default) | Verify NSCache `totalCostLimit` is set |
| **Memory Growth** | < 5MB/hour | Investigate leaks, check cache eviction |
| **Leaks** | 0 | Fix reference cycles, weak references |

### Snapshot Analysis

**How to Take Snapshots:**
1. Click "Mark Generation" button in Instruments
2. Take snapshots at: 0h, 6h, 12h, 18h, 24h
3. Compare "Growth" column between snapshots

**What to Look For:**
- **Persistent Growth:** Objects that increase in count/size between snapshots
- **Large Allocations:** Single objects > 10MB (drill down in "Allocations List")
- **Retained Cycles:** Use "Memory Graph" to find strong reference cycles

### Specific Checks

#### 1. Cache Behavior
```
Settings > Memory Usage
- Current Size: should stay under configured limit (50MB default)
- Hit Rate: should be > 50% for good cache efficiency
- Entry Count: should stabilize (LRU eviction working)
```

#### 2. Memory Warning Response
```
Debug > Simulate Memory Warning
- Watch Allocations graph drop immediately
- Cache Size should reset to ~0MB
- AppLogger should show: "Memory warning received, clearing caches"
```

#### 3. Background Memory
```
Send app to background (Cmd+Shift+H)
- iOS may compress memory (normal behavior)
- On foreground return, memory should stay low
- If memory spikes on return, investigate state restoration
```

---

## Common Issues & Solutions

### Issue: Memory Exceeds 200MB

**Possible Causes:**
- Cache size too large
- Large API responses being cached
- Image caching (if implemented)
- Retained view controllers

**Debugging Steps:**
1. **Check Cache Size**
   ```
   Settings > Memory Usage > Current Size
   If > 50MB, reduce in Cache Limit picker
   ```

2. **Profile Allocations**
   ```
   Instruments > Allocations > Statistics tab
   Sort by "Live Bytes" descending
   Look for unexpected large allocations
   ```

3. **Check for Leaks**
   ```
   Instruments > Leaks
   If any red markers, click to see backtrace
   Fix strong reference cycles
   ```

4. **Reduce Cache Size**
   ```swift
   // In AppConstants.swift
   static let defaultCacheSizeMB = 25  // Reduce from 50MB
   ```

### Issue: Unbounded Growth Over Time

**Symptoms:**
- Memory increases steadily over 24 hours
- Does not drop during idle periods
- Cache size keeps growing

**Debugging Steps:**
1. **Verify NSCache Eviction**
   ```swift
   // In APIClient.swift, check:
   cache.totalCostLimit = AppConstants.defaultCacheSizeMB * 1024 * 1024
   ```

2. **Check for Retain Cycles**
   ```
   Product > Profile > Leaks
   Run for 1 hour, check for accumulating leaked objects
   ```

3. **Monitor Cache Stats**
   ```
   Every hour, check Settings > Memory Usage
   Entry count should plateau, not grow linearly
   ```

4. **Review Cache Key Uniqueness**
   ```
   If cache keys are always unique (e.g., timestamps),
   LRU eviction can't help - fix key generation
   ```

### Issue: Memory Warning Not Clearing Cache

**Symptoms:**
- Simulate memory warning in simulator
- Memory doesn't drop
- App gets killed by iOS

**Debugging Steps:**
1. **Check Memory Warning Handler**
   ```swift
   // In ILSAppApp.swift
   // Should call: await MemoryManager.shared.handleMemoryWarning()
   ```

2. **Verify Logs**
   ```
   Console.app > Filter: "ILS"
   Should see: [Cache] Clearing in-memory cache
   ```

3. **Test Manually**
   ```swift
   // In Settings > Memory Usage
   Tap "Clear Cache" button
   Current Size should drop to ~0MB
   ```

### Issue: Cache Hit Rate Too Low

**Symptoms:**
- Hit rate < 30% in Settings > Memory Usage
- Performance degradation (many API calls)

**Possible Causes:**
- Cache TTL too short (data expires too quickly)
- Cache size too small (frequent evictions)
- Keys not matching (typos in cache key generation)

**Solutions:**
1. **Increase Cache TTL**
   ```swift
   // In AppConstants.swift
   static let defaultCacheTTL: TimeInterval = 600  // 10 minutes instead of 5
   ```

2. **Increase Cache Size**
   ```
   Settings > Memory Usage > Cache Limit > 75MB or 100MB
   ```

3. **Review Cache Keys**
   ```swift
   // Should be stable for same request
   let cacheKey = "\(endpoint)-\(params.sorted())"
   ```

---

## Best Practices

### Before Profiling
- ✅ Use **Release build** (Product > Profile, not Debug)
- ✅ Close other apps on simulator (reduce noise)
- ✅ Use dedicated simulator (iPhone 16 Pro Max)
- ✅ Ensure backend is running and healthy
- ✅ Start with fresh app install (delete and reinstall)

### During Profiling
- ✅ Take snapshots every 6 hours
- ✅ Simulate realistic usage patterns
- ✅ Include idle periods (iOS optimizes during idle)
- ✅ Trigger memory warnings manually (Debug menu)
- ✅ Monitor both Allocations and Leaks

### After Profiling
- ✅ Compare first and last snapshots (should be similar)
- ✅ Save Instruments trace file (File > Save)
- ✅ Document any anomalies in build-progress.txt
- ✅ If baseline exceeded, reduce cache size and re-test
- ✅ Commit any optimizations with clear messages

---

## Memory Optimization Checklist

When optimizing memory usage, check these areas:

### Caching
- [ ] NSCache `totalCostLimit` is set to reasonable value
- [ ] Cache TTL prevents stale data accumulation
- [ ] Cache keys are deterministic (same request = same key)
- [ ] Large objects (>1MB) are not cached unnecessarily
- [ ] Memory warnings clear all caches

### View Lifecycle
- [ ] View controllers are deallocated when popped/dismissed
- [ ] No strong reference cycles (`self` captured in closures)
- [ ] Images are released when off-screen (use `LazyVStack`)
- [ ] @State/@StateObject used correctly in SwiftUI

### API Responses
- [ ] Responses are parsed and only necessary data retained
- [ ] Raw JSON strings are not kept in memory
- [ ] Pagination is used for large lists (sessions, projects)
- [ ] Old data is discarded when new data arrives

### Background Tasks
- [ ] Background tasks release resources when done
- [ ] No infinite loops or timers holding memory
- [ ] URLSession tasks are cancelled when view disappears

---

## Reporting Results

After completing a 24-hour profile, document the results:

### Memory Profile Report Template

```markdown
# Memory Profile Report - [Date]

## Configuration
- **Device:** iPhone 16 Pro Max Simulator (iOS 18.6)
- **Build:** Release (Xcode Profile)
- **Cache Size:** 50MB (default)
- **Duration:** 24 hours
- **Test Type:** Manual simulation of normal usage

## Results

### Peak Memory
- **Maximum:** XXX MB (at HH:MM)
- **Target:** < 200MB
- **Status:** ✅ PASS / ❌ FAIL

### Memory Growth
- **Start (0h):** XX MB
- **End (24h):** XX MB
- **Delta:** +/- X MB
- **Growth Rate:** X MB/hour
- **Status:** ✅ Flat / ❌ Growing

### Cache Performance
- **Hit Rate:** XX%
- **Average Size:** XX MB
- **Max Size:** XX MB
- **Evictions:** XXX times

### Leaks
- **Leaks Detected:** 0 / X
- **Leaked Memory:** 0 KB / X KB
- **Status:** ✅ No leaks / ❌ Leaks found

## Issues Found
- [List any memory issues, leaks, or unexpected behavior]

## Optimizations Applied
- [List any changes made to reduce memory usage]

## Conclusion
[Summary: does the app meet the < 200MB baseline? Is memory growth bounded?]
```

---

## Additional Resources

- [Apple Instruments Help](https://help.apple.com/instruments/)
- [WWDC: Instruments Tutorial](https://developer.apple.com/videos/instruments)
- [Finding Memory Leaks in Swift](https://developer.apple.com/documentation/xcode/gathering-information-about-memory-use)
- [NSCache Documentation](https://developer.apple.com/documentation/foundation/nscache)

---

## Quick Reference

```bash
# Build for profiling
xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp \
  -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build

# Check backend health
curl http://localhost:9999/health

# Simulate memory warning (in simulator Debug menu)
# Hardware > Simulate Memory Warning

# View console logs
log stream --predicate 'subsystem == "com.ils.app"' --level debug

# Monitor memory from command line (while running)
instruments -t Allocations -D memory_trace.trace \
  -w 50523130-57AA-48B0-ABD0-4D59CE455F14 \
  com.ils.app
```

---

**Last Updated:** March 4, 2026
**Maintainer:** ILS Development Team
**Related Docs:** [RUNNING_BACKEND.md](./RUNNING_BACKEND.md), [CLAUDE.md](./CLAUDE.md)
