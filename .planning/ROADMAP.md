# Roadmap — ILS iOS/macOS Cross-Platform Audit

## Milestone 1: Cross-Platform Audit & Remediation

### Phase 1: Discovery & Research -- COMPLETE
**Goal**: Complete codebase analysis, technical research, and UX spec research in parallel.
**Validation**: VG-01 (PASS), VG-02 (PASS), VG-03A/B/C (PASS), VG-04 (PASS)
**Summary**: `.planning/phases/01-discovery-research/01-01-SUMMARY.md`
**Duration**: 11min | **Tasks**: 4/4 | **Files**: 4 created

**Tasks**:
1. ~~Scan all available skills, commands, MCP tools — catalog into structured inventory~~ DONE
2. ~~Verify MCP servers (context7, Sequential Thinking) are live~~ DONE
3. ~~[PARALLEL] Sub-Agent A: Complete codebase analysis (every .swift file, nav hierarchy, config flow)~~ DONE
4. ~~[PARALLEL] Sub-Agent B: Technical documentation research via context7 (7 topics)~~ DONE
5. ~~[PARALLEL] Sub-Agent C: Spec & UX research (screen inventory, PASS criteria per platform)~~ DONE
6. ~~Merge all research into unified context~~ DONE

**Evidence**: `evidence/phase-00-discovery/`, `evidence/phase-01-research/`
**Key output**: 23-entry fix registry, 15/15 REQs traced, Phase 2-6 readiness confirmed

---

### Phase 2: Navigation + Layout (Stream 1) -- COMPLETE
**Goal**: Fix home sidebar, session navigation, quick actions ordering, sessions consistency.
**Validation**: VG-05 (PASS), VG-06 (PASS), VG-07 (PASS), VG-08 (PASS)
**Summary**: `.planning/phases/02-navigation-layout/02-02-SUMMARY.md`
**Duration**: 40min | **Tasks**: 6/6 | **Files**: 8 modified

**Tasks**:
1. ~~Fix home screen sidebar/hamburger menu~~ DONE
2. ~~Resolve sidebar vs back button for session detail~~ DONE
3. ~~Reorder: quick actions above recent sessions~~ DONE
4. ~~Unify home recent sessions with dedicated Sessions screen~~ DONE

**Evidence**: `evidence/phase-02-streams/stream1/`
**Key output**: Shared SessionsViewModel pattern, BrowserView initialSegment, chat restoration, sidebar Themes nav

---

### Phase 3: Settings & Config Inheritance (Stream 2) -- COMPLETE
**Goal**: Trace config flow, build inheritance UI, fix 8 individual settings items.
**Validation**: VG-09 (PASS), VG-10 (PASS), VG-11 (PASS)
**Summary**: `.planning/phases/03-settings-config/03-SUMMARY.md`
**Duration**: ~3hrs | **Tasks**: 6/6 | **Files**: 3 modified + 32 evidence

**Tasks**:
1. ~~Trace config flow: CLI -> backend API -> mobile settings~~ DONE
2. ~~Build "Inherited from host" vs "Custom override" visual system~~ DONE
3. ~~Fix 8 individual settings (system prompt, model default, tool controls, permissions, etc.)~~ DONE

**Evidence**: `evidence/phase-02-streams/stream2/`
**Key output**: InheritanceBadge pattern, 5 SettingsInfoButton tooltips, interactive toggles, config save round-trip, REQ-02/03/10 satisfied

---

### Phase 4: Skills, Plugins, Hooks & Theming (Stream 3) -- COMPLETE
**Goal**: Fix MCP backend, skills data source, add status indicators, GitHub browse/install, hooks screen, themes.
**Validation**: VG-12 (PASS), VG-13 (PASS), VG-14 (PASS), VG-15 (PASS), VG-16 (PASS), VG-17 (PASS), VG-18 (PASS)
**Summary**: `.planning/phases/04-skills-plugins-hooks-themes/04-SUMMARY.md`
**Duration**: ~90min | **Tasks**: 7/7 | **Files**: 9 modified + 1 created

**Tasks**:
1. ~~Fix skills data source (1336 clean, no node_modules, no examples/ artifacts)~~ DONE
2. ~~Plugin Detail View (PluginConfigView + NavigationLink pre-existing)~~ DONE
3. ~~GitHub browse UI in Browser skills tab~~ DONE
4. ~~MCP API key masking + 5s auto-hide~~ DONE
5. ~~Hooks Management screen + NavigationLink from Settings~~ DONE
6. ~~Custom Themes end-to-end (CustomThemeAdapter + ThemePickerView sections)~~ DONE
7. ~~Plugin status indicators (version, source, stars, spinner)~~ DONE

**Evidence**: `evidence/phase-02-streams/stream3/`
**Key output**: Skills decontaminated (3505→1336), CustomThemeAdapter bridges backend DTO to AppTheme, GitHub browse with install flow, MCP key masking with auto-hide

---

### Phase 5: System Monitor + Profiles (Stream 4)
**Goal**: Fix SSH pipeline for system monitor, replace Fleet with Host/Backend Profiles.
**Validation**: VG-19 (monitor), VG-20 (profiles)

**Tasks**:
1. Fix system monitor SSH pipeline for real-time metrics
2. Redesign Fleet -> Host/Backend Profiles

**Evidence**: `evidence/phase-02-streams/stream4/`

---

### Phase 6: Backend API Audit (Stream 5)
**Goal**: Enumerate, verify, and fix all API endpoints.
**Validation**: VG-21

**Tasks**:
1. Enumerate all API endpoints
2. Verify response structures with real curl
3. Verify CLI host defaults exposure
4. Verify MCP server registration
5. Test error handling

**Evidence**: `evidence/phase-02-streams/stream5/`

---

### Phase 7: Convergence & Cross-Stream Regression
**Goal**: Full regression sweep across all streams.
**Validation**: VG-25 (convergence)

**Tasks**:
1. Build fresh for iPhone + iPad + Mac
2. Navigate every modified screen
3. Cross-stream regression check
4. Fix any regressions found

**Evidence**: `evidence/phase-03-convergence/`

---

### Phase 8: Full Platform Validation
**Goal**: Visual audit on all 4 platforms in parallel.
**Validation**: VG-26A (iPhone 16 Pro), VG-26B (iPhone 16 PM), VG-26C (iPad Pro), VG-26D (Mac), VG-27 (merge)

**Tasks**:
1. [PARALLEL] iPhone 16 Pro — all screens
2. [PARALLEL] iPhone 16 Pro Max — all screens
3. [PARALLEL] iPad Pro 13" — all screens + sidebar + split view
4. [PARALLEL] Mac Catalyst — all screens + window + keyboard

**Evidence**: `evidence/phase-04-platforms/`

---

### Phase 9: Functional Audit + Bug Hunt
**Goal**: Complete functional verification and edge case testing.
**Validation**: VG-28 (functional), VG-29 (bug hunt)

**Tasks**:
1. Verify every functional area across all platforms
2. Test 20+ edge cases (empty states, long text, offline, rapid nav, VoiceOver, Dynamic Type)
3. Fix all discovered issues

**Evidence**: `evidence/phase-05-functional/`, `evidence/phase-06-bughunt/`

---

### Phase 10: Final Gate
**Goal**: Complete final validation against all 20+ PASS criteria.
**Validation**: VG-30 (FINAL)

**Tasks**:
1. Full iOS Validation Runner on all platforms
2. Compare against Phase 1 PASS criteria
3. Generate final report

**Evidence**: `evidence/final/`
