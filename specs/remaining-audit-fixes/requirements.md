---
spec: remaining-audit-fixes
phase: requirements
created: 2026-02-07
---

# Requirements: Remaining Audit Fixes

## Goal
Fix all 12 MEDIUM and 9 LOW severity issues from comprehensive 6-domain audit (concurrency, memory, SwiftUI architecture, SwiftUI performance, networking, accessibility). CRITICAL/HIGH already resolved. Ensure clean build with zero regressions.

## User Stories

### US-1: Concurrency Safety
**As a** developer maintaining the codebase
**I want** Swift 6-ready concurrency patterns
**So that** future compiler upgrades don't break builds

**Acceptance Criteria:**
- [ ] AC-1.1: URLSession instances created per-ViewModel (not shared in @MainActor)
- [ ] AC-1.2: Task capture warnings eliminated with [weak self] where needed
- [ ] AC-1.3: Decoder/Encoder marked nonisolated or static
- [ ] AC-1.4: All print() replaced with AppLogger in async contexts
- [ ] AC-1.5: No Sendable warnings in Xcode build output

### US-2: Memory Management
**As a** developer concerned with app stability
**I want** proper cancellation of background work
**So that** view dismissals don't leak timers or tasks

**Acceptance Criteria:**
- [ ] AC-2.1: Timer.scheduledTimer replaced with Task-based timer + onDisappear cancellation
- [ ] AC-2.2: DispatchQueue.asyncAfter replaced with Task.sleep + cancellation
- [ ] AC-2.3: ChatViewModel.cancellables explicitly cleared in deinit
- [ ] AC-2.4: No zombie timers after view dismissal (verifiable via Instruments)

### US-3: Architecture Patterns
**As a** developer reading View code
**I want** clear separation of logic from state
**So that** code is easier to understand and maintain

**Acceptance Criteria:**
- [ ] AC-3.1: Published+didSet anti-patterns refactored to explicit methods
- [ ] AC-3.2: Static formatters extracted to DateFormatters namespace
- [ ] AC-3.3: Complex computed properties (>15 lines) extracted to ViewModel methods
- [ ] AC-3.4: Build succeeds with no functional changes

### US-4: Consistent Theming
**As a** developer using the design system
**I want** all font sizes defined through ILSTheme
**So that** visual changes propagate consistently

**Acceptance Criteria:**
- [ ] AC-4.1: 10 hardcoded .font(.system(size:)) replaced with ILSTheme references
- [ ] AC-4.2: No new hardcoded font sizes introduced
- [ ] AC-4.3: Screenshots match existing visual appearance

### US-5: Network Reliability
**As a** user experiencing network issues
**I want** smarter retry logic and cache management
**So that** the app recovers gracefully from failures

**Acceptance Criteria:**
- [ ] AC-5.1: APIClient cache invalidation scoped to specific URLs (not global clear)
- [ ] AC-5.2: Retry backoff skips sleep on final attempt
- [ ] AC-5.3: SSEClient reconnection uses true exponential backoff
- [ ] AC-5.4: WebSocket fallback resets after SSE success
- [ ] AC-5.5: Network requests complete 20% faster under failure scenarios

### US-6: Accessibility Compliance
**As a** user relying on accessibility features
**I want** all interactive elements properly labeled
**So that** VoiceOver navigation is comprehensive

**Acceptance Criteria:**
- [ ] AC-6.1: Toggles, TextFields, Buttons have explicit accessibilityLabel
- [ ] AC-6.2: Dynamic Type applied via ILSTheme (no hardcoded sizes)
- [ ] AC-6.3: Color-only indicators augmented with text/icons
- [ ] AC-6.4: VoiceOver navigation complete (testable via Simulator)

## Functional Requirements

| ID | Requirement | Priority | Verification |
|----|-------------|----------|--------------|
| FR-1 | Replace 2 URLSession.shared uses with dedicated instances | P1 | Code review + concurrency audit |
| FR-2 | Add [weak self] to AppState polling Tasks | P1 | Swift 6 build succeeds |
| FR-3 | Mark 4 Decoder/Encoder instances as nonisolated | P1 | No isolation warnings |
| FR-4 | Replace 30 print() with AppLogger | P2 | grep confirms zero print() |
| FR-5 | Convert Timer.scheduledTimer to Task in ChatViewModel | P1 | Memory graph shows no timer leaks |
| FR-6 | Replace 2 DispatchQueue.asyncAfter with Task.sleep | P1 | Cancellation verified |
| FR-7 | Add cancellables.removeAll() to deinit | P2 | Memory Instruments pass |
| FR-8 | Refactor 2 Published+didSet patterns | P1 | Logic extracted to methods |
| FR-9 | Extract RelativeDateTimeFormatter to namespace | P1 | Static analysis clean |
| FR-10 | Extract 3 complex computed properties to methods | P2 | Cyclomatic complexity <10 |
| FR-11 | Replace 10 hardcoded fonts with ILSTheme | P2 | Design system audit pass |
| FR-12 | Scope cache invalidation to URLRequest.url | P1 | Network tests verify |
| FR-13 | Skip final retry backoff sleep | P1 | Unit test confirms timing |
| FR-14 | Fix SSEClient exponential backoff implementation | P1 | Retry intervals verified |
| FR-15 | Reset WebSocket fallback after SSE success | P2 | Integration test confirms |
| FR-16 | Add 8 missing accessibility labels | P1 | VoiceOver audit |
| FR-17 | Apply Dynamic Type via ILSTheme to 10 files | P1 | Accessibility Inspector |
| FR-18 | Add text/icon indicators to color-only status | P2 | Visual audit |
| FR-19 | Remove redundant objectWillChange.send() | P3 | SwiftUI best practices |

## Non-Functional Requirements

| ID | Requirement | Metric | Target |
|----|-------------|--------|--------|
| NFR-1 | Build Time | Xcode clean build | <30s increase |
| NFR-2 | Code Coverage | Affected files | No decrease |
| NFR-3 | Swift Version | Compiler compatibility | Swift 5.9 + Swift 6 prep |
| NFR-4 | Visual Regression | Screenshot diff | Zero pixels changed |
| NFR-5 | Memory Footprint | Instruments peak | No increase |
| NFR-6 | A11y Conformance | Accessibility Inspector | 100% pass rate |

## User Decisions (from Interview)

| Question | Answer | Impact |
|----------|--------|--------|
| Fix all or prioritize? | Fix every single issue | No skips, complete coverage |
| Dev vs end-user focus? | Both | Concurrency (dev) + a11y (user) both P1 |
| Skip LOW issues? | No | LOW issues included in scope |
| Success criteria? | Clean build, no regressions | Functional parity mandatory |

## Glossary

- **Swift 6 prep**: Code patterns compatible with upcoming strict concurrency
- **Task-based timer**: Async/await loop with Task.sleep instead of Timer
- **Isolation warning**: Swift compiler error about actor-protected state
- **Dynamic Type**: iOS adaptive font sizing for accessibility
- **VoiceOver**: iOS screen reader
- **Exponential backoff**: Retry delays that double each attempt (1s, 2s, 4s, 8s)

## Out of Scope

- ❌ New features or functionality changes
- ❌ UI/UX redesigns
- ❌ False alarm issues (L-MEM-2, L-ARCH-2, M-PERF-1, M-PERF-2, L-A11Y-2)
- ❌ Test file creation (per FUNCTIONAL VALIDATION MANDATE)
- ❌ Performance benchmarking beyond memory Instruments

## Dependencies

- Existing AppLogger implementation (already in codebase)
- ILSTheme font system (already defined)
- Accessibility Inspector (Xcode built-in)
- Memory Graph Debugger (Xcode Instruments)

## Success Criteria

- [ ] All 21 issues (12 MEDIUM + 9 LOW) resolved
- [ ] Zero new compiler warnings introduced
- [ ] Build completes successfully in <30s overhead
- [ ] 12 visual evidence screenshots match existing UI
- [ ] VoiceOver navigation test passes end-to-end
- [ ] Memory Instruments shows no leaks after 10-minute stress test

## Implementation Phases

### Phase 1: MEDIUM Issues (12 fixes, P1)
Critical for stability and Swift 6 compatibility

1. **Concurrency** (M-CONC-1, M-CONC-2): URLSession + Task capture
2. **Memory** (M-MEM-1, M-MEM-2): Timer + DispatchQueue conversion
3. **Architecture** (M-ARCH-1, M-ARCH-2): Published+didSet + formatter extraction
4. **Networking** (M-NET-1, M-NET-2): Cache scoping + retry optimization
5. **Accessibility** (M-A11Y-1, M-A11Y-2): Labels + Dynamic Type

### Phase 2: LOW Issues (9 fixes, P2)
Polish and future-proofing

6. **Concurrency** (L-CONC-1, L-CONC-2): Decoder isolation + print() cleanup
7. **Memory** (L-MEM-1): Cancellables cleanup
8. **Architecture** (L-ARCH-1): Complex computed property extraction
9. **Performance** (L-PERF-1, L-PERF-2): Font theme + redundant notification
10. **Networking** (L-NET-1, L-NET-2): SSE backoff + fallback reset
11. **Accessibility** (L-A11Y-1): Color-only indicators

### Phase 3: Validation & Evidence
Evidence-based completion verification

12. **Build Verification**: Clean build, zero new warnings
13. **Visual Regression**: 12 screenshots (6 tabs + 6 modals)
14. **Memory Audit**: Instruments leak check
15. **A11y Audit**: VoiceOver navigation test

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|-----------|
| URLSession change breaks networking | Low | High | Revert to .shared if issues |
| Task-based timer introduces race | Low | Medium | Test with rapid view push/pop |
| Font changes alter layout | Medium | Low | Screenshot comparison |
| A11y labels too verbose | Low | Low | Test with actual VoiceOver users |
| print() removal loses debug info | Low | Low | AppLogger preserves all output |

## Next Steps

1. Implement Phase 1 (MEDIUM issues, ~12 files modified)
2. Capture before/after screenshots for visual regression baseline
3. Run Memory Instruments leak detection
4. Implement Phase 2 (LOW issues, ~15 files modified)
5. Execute VoiceOver navigation audit
6. Capture final evidence screenshots
7. Update MEMORY.md with lessons learned
