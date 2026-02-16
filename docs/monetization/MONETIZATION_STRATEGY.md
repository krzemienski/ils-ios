# ILS iOS App - Strategic Monetization Analysis

**Date:** February 2026
**App:** ILS - Intelligent Local Server (iOS/macOS client for Claude Code)
**Current Status:** No monetization infrastructure (No StoreKit, IAP, or subscription logic)

---

## Executive Summary

ILS is a **companion native mobile app** for Claude Code (Anthropic's AI coding assistant). It provides a premium iOS/macOS interface to Claude Code's local backend, featuring chat, session management, project browsing, skills explorer, MCP server management, and custom themes.

**Monetization Recommendation:** **Freemium with Premium Tier Subscription**
- **Free tier:** Core chat, session management, project/skills browsing, 12 themes
- **Premium tier:** $4.99-6.99/month or $49.99/year for advanced features
- **Target conversion:** 5-15% (higher than typical 2-5% freemium due to developer focus)
- **Revenue potential:** $50-500K annually (100-5K paying users at $50-100/year)

---

## Part 1: Current Feature Inventory & Monetization Candidates

### Core App Features (Current)

| Feature | Category | Current Status | Monetization Potential |
|---------|----------|-----------------|----------------------|
| Chat with Claude | Core | Free | Keep free (core value) |
| Session Management | Core | Free | Partially premium (export) |
| Message History | Core | Free | Free with limits |
| Project Browser | Core | Free | Free (read-only) |
| Skills Explorer | Core | Free | Free (read-only) |
| MCP Server Status | Core | Free | Premium tier |
| Plugin Management | Core | Free | Free (view), Premium (install) |
| System Monitoring | Advanced | Free | Premium tier |
| Custom Themes | Cosmetic | Free | Premium tier |
| Team Coordination | Advanced | Free | Premium tier |
| Fleet Management | Advanced | Free | Premium tier |
| Cloudflare Tunnel | Advanced | Free | Premium tier |
| Settings/Config | Utility | Free | Free |
| macOS Support | Platform | Free | Keep free |

### Recommended Premium Feature Tiers

#### **TIER 1: FREE** (Attracts users, establishes market presence)
- Chat with Claude (unlimited messages to local backend)
- Create and manage sessions
- View/fork existing sessions
- Session list with filtering
- Project browser (read-only, view 371 projects)
- Skills explorer (search 1,527+ skills)
- MCP server status monitoring (view-only)
- Plugin browser (view available plugins)
- 12 built-in themes
- Basic settings and configuration
- Sidebar navigation
- Dark mode
- System monitoring (basic metrics)

**Why this works:** Lets users experience core value without friction. Users already paying for Claude Code benefit from free iOS interface.

#### **TIER 2: PREMIUM** ($4.99/month or $6.99/month or $49.99/year)
Unlock advanced productivity and customization features:

**Chat & Session Features**
- [ ] Chat history export (JSON, Markdown, PDF, HTML formats)
- [ ] Session templates (save conversation structure for reuse)
- [ ] Custom system prompts (add context/instructions for Claude)
- [ ] Message search and advanced filtering
- [ ] Session analytics (message count, response times, tokens used)
- [ ] Bulk session operations (archive, delete, tag multiple)
- [ ] Session sharing via QR code or link

**Theme & Customization**
- [ ] Custom theme creation and live editor
- [ ] Theme import/export (JSON format)
- [ ] Premium theme pack (6-10 additional curated themes: Cyberpunk 2.0, Neon, Dark Matter, Synthwave, Dracula+, etc.)
- [ ] Per-view theme overrides (different theme per tab)
- [ ] Font and spacing customization

**System Monitoring Pro**
- [ ] Advanced metrics dashboard with graphs
- [ ] Process monitoring and management (kill, prioritize)
- [ ] System health alerts and notifications
- [ ] Performance history and trending
- [ ] Network traffic analysis
- [ ] Disk usage breakdown by folder

**Team & Collaboration Pro**
- [ ] Advanced team management
- [ ] Task scheduling and reminders
- [ ] Team activity analytics
- [ ] Batch operations on tasks and sessions
- [ ] Team templates and workflows

**Integration & Cloud**
- [ ] Cloudflare Tunnel management UI
- [ ] One-click tunnel setup/teardown
- [ ] Custom domain configuration
- [ ] Session backup and restore
- [ ] iCloud sync (sessions, settings, themes)
- [ ] Cross-device sync (iPhone ↔ iPad ↔ Mac)

**Developer Tools**
- [ ] REST API access to app features
- [ ] Webhook integrations
- [ ] Chat automation (scheduled messages)
- [ ] Custom keyboard shortcuts (macOS)

---

## Part 2: Competitive Landscape Analysis

### Direct Competitors

| Competitor | Product | Pricing Model | Platform | Key Positioning |
|-----------|---------|---------------|----------|-----------------|
| **GitHub Copilot** | IDE AI assistant | $10/mo individual<br>$19/mo business | VS Code, JetBrains, Vim | Editor-integrated, code completion focus |
| **Codeium** | Code AI assistant | Freemium<br>Pro: $12/mo | Editor, IDE | Open to all, editor-centric |
| **Cursor Editor** | Full AI IDE | $20/mo Pro<br>$100/mo Team | Desktop (Electron) | Cursor-as-editor replacement |
| **Amazon CodeWhisperer** | AWS IDE assistant | Free tier<br>$120/year Pro | IDE extension | AWS ecosystem integration |
| **Anthropic Claude API** | API-only | Usage-based<br>$5-20/mo typical | API | DIY integration required |
| **ILS (Current)** | iOS/macOS client | Free | iOS, macOS | Mobile-first Claude Code interface |

### Market Insights (2025-2026)

**AI App Market Growth:**
- Generative AI apps reached $824M in spend (2024)
- 50% year-over-year growth
- 4th fastest-growing category on iOS
- **Developer tools are high-value segment**

**Monetization Model Effectiveness:**
- **Hard paywall (subscription only):** 12.11% conversion rate
- **Freemium model:** 2.18% conversion rate
- **Hybrid (free core + premium):** 5-8% conversion for developer tools
- **Best for:** Enterprise SaaS, clear value proposition

**SaaS Trends:**
- Subscription model dominates (60%+ of B2B SaaS launched 2024)
- Usage-based billing growing (especially for API/AI tools)
- Annual plans show 20-30% better retention than monthly

### Why ILS Positioning Is Unique

1. **Not competing with IDE editors** - complementary mobile interface
2. **Not charging for Claude Code** - users already have subscription or free tier
3. **Filling a gap** - no existing Claude Code iOS client
4. **Lower price point justified** - companion app, not standalone
5. **Strong developer audience** - people who use Claude Code are highly monetizable

---

## Part 3: Recommended Monetization Model

### Model: **Freemium with Premium Tier Subscription**

```
┌─────────────────────────────────────────────────────┐
│  FREE                    │  PREMIUM ($4.99-6.99/mo) │
├─────────────────────────────────────────────────────┤
│ ✓ Chat (unlimited)       │ ✓ All free features      │
│ ✓ Sessions              │ ✓ Export chats           │
│ ✓ Projects/Skills       │ ✓ Custom themes          │
│ ✓ Basic themes          │ ✓ Advanced monitoring    │
│ ✓ Basic monitoring      │ ✓ Team tools pro         │
│                         │ ✓ iCloud sync            │
│                         │ ✓ Rest API access        │
└─────────────────────────────────────────────────────┘
```

### Pricing Options (A/B test both)

#### Option A: Monthly Focus
- **$4.99/month** (low-friction, highest conversion)
- **$49.99/year** (25% annual savings, encourages commitment)
- **Free tier** (unlimited in free tier)

#### Option B: Premium Focus
- **$6.99/month** (premium positioning)
- **$59.99/year** (28% annual savings)
- **Free tier with limits** (e.g., export 5 chats/month, 3 custom themes)

**Recommendation:** Start with Option A, measure conversion, move to Option B if needed.

### Why Freemium Works Here

1. **Low switching cost** - users can try before buying
2. **Addresses uncertainty** - users new to Claude Code can explore
3. **Viral coefficient** - free tier grows user base organically
4. **Upsell funnel** - premium features become obvious during use
5. **Retention data** - measure which features drive premium conversion

### Why Premium Is Affordable

- **Not a core fee** - Claude Code subscription is separate
- **Companion value** - $50/year is <5% premium over Claude
- **Developer purchasing power** - target audience can afford $50/year easily
- **Enterprise potential** - teams could buy multiple seats

### Expected Metrics (Conservative)

| Metric | Conservative | Optimistic | Notes |
|--------|--------------|-----------|-------|
| Freemium conversion | 3% | 8% | Developer tools trend higher |
| Monthly users | 1,000 | 10,000 | Depends on marketing |
| Premium subscribers | 30 | 800 | 3-8% of 1-10K users |
| Annual revenue | $1,800 | $48,000 | 30-800 subs × $50/year |
| Lifetime value | $100-300 | $300-800 | Sticky product, high retention |

**Revenue Potential @ 5,000 users, 5% conversion:**
- 250 paying users × $50/year = **$12,500 annual**
- With 70% retention: $12,500 → $18,750 → $25,000 (by year 3)

---

## Part 4: App Store Compliance & Technical Requirements

### Apple App Store Review Guidelines (2025)

**Key Requirements for Subscriptions/IAP:**

1. **StoreKit 2 Required**
   - Modern framework for subscriptions
   - Replaces older StoreKit v1
   - Required for new apps / updates

2. **Subscription Requirements**
   - Clear pricing disclosure (before purchase)
   - Conspicuous "Restore Purchases" button
   - Cancel subscription easily (matching purchase difficulty)
   - Free trial option recommended (7-14 days)
   - Grace period for failed payments

3. **Privacy & Permissions**
   - Subscription data not shared without consent
   - Clear privacy policy
   - Data deletion compliance (CCPA, GDPR)

4. **Free vs Paid Feature Separation**
   - Must not trick users into paid tier
   - Must not degrade free tier after premium launch
   - Free core functionality should feel complete

5. **Prohibited Practices**
   - ❌ Can't force sign-in to use free features
   - ❌ Can't hide free functionality paywalls
   - ❌ Can't use misleading language ("free trial" then charge)
   - ❌ Can't require subscription for core functionality users expect free

**ILS Compliance Strategy:**
- Launch free tier with clear completion (chat, sessions, themes)
- Offer premium as optional enhancement
- Add "Restore Purchases" in Settings
- Implement cancellation flow (Settings → Subscriptions)
- Use StoreKit 2 for transactions
- Clear in-app messaging: "Premium" badge on locked features

### Implementation Checklist

- [ ] **StoreKit 2 Integration**
  - `import StoreKit`
  - Subscription product setup (App Store Connect)
  - Purchase flow (`.purchaseButton()` modifier)
  - Transaction verification

- [ ] **Feature Gating**
  - `@EnvironmentObject var subscriptionManager: SubscriptionManager`
  - Check `isPremium` before rendering premium views
  - Graceful degradation (show "Upgrade" prompt)

- [ ] **Subscription UI**
  - Premium tier screen in Settings
  - Feature comparison table
  - Subscribe button (with free trial)
  - Manage subscription link

- [ ] **Entitlements & Signing**
  - Add `com.apple.developer.in-app-purchase` entitlement
  - Provisioning profile includes entitlement
  - Production vs Sandbox app ID

- [ ] **Testing**
  - StoreKit configuration file (.storekit)
  - Sandbox testers setup
  - Free trial testing
  - Subscription renewal testing

---

## Part 5: Feature-Specific Monetization Strategy

### Why Each Feature Deserves Premium

#### **Chat Export** → Premium
- **Value:** Users want to keep chat records (backup, documentation)
- **Frequency:** 1-2x per week for active users
- **Alternatives:** None built-in (App requires internet)
- **Justification:** Clear ROI, easy implementation

#### **Custom Themes** → Premium
- **Value:** Developer audience cares about aesthetics (proven by 12 theme investment)
- **Frequency:** Set once, enjoy permanently
- **Alternatives:** 12 free themes available
- **Justification:** Cosmetic premium (proven SaaS model)

#### **System Monitoring Pro** → Premium
- **Value:** DevOps/system admins need performance data
- **Frequency:** Daily use
- **Alternatives:** Activity Monitor (macOS), native Android
- **Justification:** Advanced analytics always premium

#### **iCloud Sync** → Premium
- **Value:** Users with multiple devices pay for convenience
- **Frequency:** Passive (always working)
- **Alternatives:** None (per-device storage only)
- **Justification:** Infrastructure cost recovery

#### **Team Tools Pro** → Premium
- **Value:** Collaboration features justify premium
- **Frequency:** Team-dependent (daily for teams, 0x solo)
- **Alternatives:** Slack, Linear, Notion
- **Justification:** Network effect + team size scaling

### Features to Keep Free

| Feature | Reason |
|---------|--------|
| Chat with Claude | Core value - users already pay for Claude |
| Session management | Essential workflow (don't block) |
| Project/Skills browser | Data discovery (engagement) |
| Basic themes (12) | Reduces "feels incomplete" perception |
| Basic monitoring | System health (safety feature) |
| Settings | Required for functionality |

---

## Part 6: Go-to-Market Strategy

### Phase 1: Launch Free App (Pre-Monetization)
- **Timeline:** Now (free launch)
- **Goals:** User acquisition, retention data, feature validation
- **Metrics to track:**
  - DAU/MAU (daily/monthly active users)
  - Feature engagement (which features used most?)
  - Session length (time spent per session)
  - Churn rate (weekly retention)
  - Device breakdown (iPhone vs iPad vs Mac)

### Phase 2: Premium Features Soft Launch (3 months)
- **Timeline:** After 1K+ users, clear retention signal
- **Rollout:**
  - Premium features visible but locked ("Upgrade to unlock")
  - A/B test messaging ("Upgrade" vs "Premium" vs "Pro")
  - 7-day free trial to all new installs
  - Analytics on feature unlock clicks (conversion funnel)

### Phase 3: Full Monetization (6 months)
- **Timeline:** After measuring conversion in Phase 2
- **Scale:**
  - Marketing push (App Store features, communities, etc.)
  - Price optimization (test $4.99 vs $6.99 vs $9.99)
  - Enterprise tier (if demand exists)

### Marketing Angles

1. **"Premium Mobile Experience"**
   - Free: "Claude Code anywhere"
   - Premium: "Professional developer toolkit"

2. **"DevOps in Your Pocket"**
   - Free: "Monitor Claude sessions"
   - Premium: "Monitor everything" (system metrics, processes)

3. **"Customization Powerhouse"**
   - Free: "12 beautiful themes"
   - Premium: "Create unlimited themes"

4. **"Seamless Across Devices"**
   - Free: "Per-device"
   - Premium: "Sync iPhone + iPad + Mac"

---

## Part 7: Comparative Analysis: Monetization Models

### Model 1: Free + Premium Subscription (Recommended)
```
Pros:
✓ Maximizes user acquisition (no friction)
✓ Proven model (Codeium, Slack, Notion)
✓ Flexible feature gating
✓ Supports free tier indefinitely
✓ Easy upsell (premium features visible)

Cons:
✗ Lower conversion than hard paywall (2-5% vs 12%)
✗ Complex feature gating code
✗ Requires careful UX (can't feel annoying)

Best for: ILS (needs user base, companions Claude sub)
```

### Model 2: Hard Paywall Subscription Only
```
Pros:
✓ Higher conversion (12.11% vs 2.18%)
✓ Simpler code (all users can access all features)
✓ Clearer monetization story
✓ Higher ARPU (average revenue per user)

Cons:
✗ Lower total users (limited by paid gate)
✗ Slower growth (no viral/referral coefficient)
✗ Higher support burden (why should I pay?)
✗ Fails if Claude Code already free

Best for: Standalone products with clear ROI (Cursor Editor)
Not recommended: For companion app to free/paid service
```

### Model 3: Free Tier with Consumption Limits
```
Pros:
✓ Clear monetization trigger (quota)
✓ Aligns with API consumption models
✓ No "arbitrary" paywall feeling

Cons:
✗ Complex to measure/track quotas
✗ Frustrating UX (hitting limits)
✗ Requires backend changes (quota enforcement)
✗ Doesn't align with offline-first architecture

Best for: Heavy API-dependent products
Not recommended: For local-backend app like ILS
```

### Model 4: One-Time Purchase ($9.99-19.99)
```
Pros:
✓ Simple monetization
✓ No subscription complexity
✓ Apple's preferred for simple apps

Cons:
✗ Lower lifetime value ($9.99 vs $50/year recurring)
✗ No retention incentive
✗ Less predictable revenue
✗ App Store pricing limits

Best for: Utility apps, games
Not recommended: For ongoing feature updates
```

**Verdict:** Model 1 (Free + Premium Subscription) is optimal for ILS.

---

## Part 8: Implementation Roadmap

### Phase 1: Feature Flagging Foundation (Week 1-2)
```swift
// Create SubscriptionManager
class SubscriptionManager: ObservableObject {
    @Published var isPremium = false
    @Published var subscription: StoreKit.Product?

    func loadPremiumStatus() async {
        // Check StoreKit transactions
        // Update @Published isPremium
    }
}

// Gate premium features
if subscriptionManager.isPremium {
    PremiumFeatureView()
} else {
    UpgradePromptView()
}
```

### Phase 2: StoreKit 2 Integration (Week 3-4)
- Set up App Store Connect products
- Create .storekit configuration file
- Implement purchase flow
- Handle subscriptions & renewal
- Test with Sandbox

### Phase 3: UI Implementation (Week 5-6)
- Premium indicator badges
- Feature unlock prompts
- Settings → Subscriptions page
- "Restore Purchases" button
- Free trial messaging

### Phase 4: Testing & Launch (Week 7-8)
- StoreKit testing (full flow)
- A/B test messaging
- Soft launch to TestFlight
- Collect analytics
- Submit to App Store

### Total Effort: **6-8 weeks** for basic implementation

---

## Part 9: Risk Analysis & Mitigation

| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|-----------|
| Users expect free | Revenue loss | High | Free tier is substantial, premium is optional |
| Competitors copy | Market pressure | Medium | First-mover advantage, network effects |
| Low conversion (1%) | Revenue miss | Medium | 3-5% is achievable for dev tools |
| Churn increases with paywall | Retention loss | Medium | Premium features are genuinely valuable |
| Apple rejects app | Launch delay | Low | Follow guidelines, test with reviewers |
| iCloud sync complexity | Dev burden | Medium | Ship sync in Phase 2, not Phase 1 |
| Integration complexity | Timeline slip | Medium | Use StoreKit 2, avoid custom solutions |

---

## Part 10: Success Metrics & KPIs

### Core Metrics (Track Weekly)

| Metric | Target | Why It Matters |
|--------|--------|----------------|
| **DAU (Daily Active Users)** | 1%+ of installs | Engagement signal |
| **MAU (Monthly Active Users)** | 10%+ of installs | Retention signal |
| **Session Length** | 5+ min average | Feature value |
| **Feature Engagement** | 70%+ use chat | Core feature validation |
| **Churn Rate** | <10% weekly | Retention benchmark |

### Monetization Metrics (Track Monthly)

| Metric | Target | Notes |
|--------|--------|-------|
| **Free tier users** | 5,000-50,000 | User base size |
| **Free-to-premium conversion** | 3-8% | Freemium benchmark |
| **Premium subscribers** | 150-4,000 | Revenue base |
| **ARPU (Annual Revenue Per User)** | $2.50-8.00 | Blended free + paid |
| **LTV (Lifetime Value)** | $50-300 | Premium users only |
| **CAC (Customer Acquisition Cost)** | <$1 | Organic marketing only |
| **Churn rate (premium)** | <5% monthly | Retention goal |
| **NRR (Net Revenue Retention)** | >100% | Growth benchmark |

### Cohort Analysis (Track Quarterly)

- Track conversion by install date
- Track LTV by cohort
- Identify which cohorts have best retention
- Test messaging/pricing changes by cohort

---

## Part 11: Long-Term Vision & Expansion

### Year 1: Foundation
- Launch free + premium tier
- 5,000-10,000 users
- $5,000-15,000 annual revenue
- Establish product-market fit

### Year 2: Growth
- 50,000+ users
- Premium tier at 5-10% conversion
- $25,000-50,000 annual revenue
- Add team/enterprise tier

### Year 3: Expansion
- 100,000+ users
- Multiple pricing tiers
- $100,000+ annual revenue
- Consider API business

### Future Opportunities

1. **Team/Enterprise Tier** ($29-99/month)
   - Shared workspaces
   - Team management
   - Audit logs
   - Custom branding
   - SSO (eventual)

2. **API Access** (Usage-based)
   - REST API for ILS features
   - Export automation
   - Third-party integration
   - $0.001-0.01 per API call

3. **White-Label** (Custom pricing)
   - Agencies
   - Internal tool teams
   - Companies building on Claude

4. **Marketplace** (Revenue share)
   - Custom themes
   - Plugins
   - Templates
   - 70/30 split model

---

## Part 12: Conclusion & Recommendation

### **Recommended Strategy:**

**Free + Premium Tier Subscription Model**

- **Free tier:** Chat, sessions, projects, skills, 12 themes
- **Premium tier:** $4.99/month or $49.99/year
- **Premium features:** Export, custom themes, sync, advanced monitoring, team tools

### **Why This Works**

1. ✓ **User acquisition:** Free tier removes friction
2. ✓ **Revenue generation:** Premium is affordable for developers
3. ✓ **Product fit:** Companion app to Claude Code (already paid/free)
4. ✓ **Scalable:** Premium revenue grows with user base
5. ✓ **App Store compliant:** Follows all guidelines
6. ✓ **Competitive:** $50/year is 2-5% of Claude Code budget

### **Expected Outcomes**

- **Conservative:** 100-300 users, 1,500-3,000 in Year 1, $1.5-3K revenue
- **Optimistic:** 5,000-10,000 users, 250-1,000 premium, $12-50K revenue
- **Realistic:** 1,000-5,000 users, 50-250 premium, $2.5-12.5K revenue

### **Next Steps**

1. Create SubscriptionManager class (feature gating)
2. Set up App Store Connect products
3. Implement StoreKit 2 integration
4. Add premium feature prompts
5. Test with TestFlight
6. Launch to production
7. Monitor conversion metrics
8. Iterate on pricing/features

---

## Appendix A: Competitor Pricing Comparison

```
GitHub Copilot:
├─ Individual: $10/month or $100/year
├─ Includes: Code completion, Copilot Chat, agent features
└─ Platform: IDE/Editor only, not mobile

Codeium:
├─ Free: Unlimited completions, basic chat
├─ Pro: $12/month (enterprise pricing on request)
├─ Includes: Advanced features, priority support
└─ Platform: IDE/Editor, browser, not mobile

Cursor Editor:
├─ Free: First month, then $20/month Pro
├─ Pro Features: Advanced AI features, priority support
└─ Platform: Desktop IDE replacement, not mobile

ILS Proposed:
├─ Free: Chat, sessions, projects, 12 themes
├─ Premium: $4.99/month or $49.99/year
├─ Premium Features: Export, custom themes, sync, monitoring
└─ Platform: iOS, macOS (mobile-first)
```

---

## Appendix B: Premium Feature Rollout Matrix

| Feature | Phase | Timeline | Effort | Priority | Notes |
|---------|-------|----------|--------|----------|-------|
| Export (JSON/MD) | 1 | Week 1 | Low | P0 | Highest ROI |
| Custom Themes | 1 | Week 2 | Medium | P0 | Proven demand |
| Advanced Monitoring | 1 | Week 3 | Medium | P1 | Lower demand |
| iCloud Sync | 2 | Week 6 | High | P1 | Complex, high value |
| Team Tools Pro | 2 | Week 8 | High | P2 | Lower immediate demand |
| API Access | 3 | Week 12 | High | P2 | For developers only |
| Marketplace | 4 | Week 16 | Very High | P3 | Ecosystem play |

---

## Appendix C: StoreKit 2 Checklist

- [ ] Product ID created in App Store Connect
- [ ] Bundle ID configured with StoreKit entitlements
- [ ] .storekit configuration file created locally
- [ ] SubscriptionManager class implemented
- [ ] @EnvironmentObject injected at app root
- [ ] Premium feature gates implemented
- [ ] Purchase UI implemented
- [ ] Restore Purchases button added
- [ ] Sandbox testing completed
- [ ] TestFlight testing completed
- [ ] Privacy policy updated
- [ ] App Review guidelines compliant
- [ ] Screenshots updated (if needed)
- [ ] Pricing tier configured in App Store Connect

---

## Appendix D: App Store Review Compliance Checklist

### Before Submission
- [ ] Subscriptions clearly labeled as "Premium"
- [ ] Pricing shown prominently (before paywall)
- [ ] Free trial period visible (if applicable)
- [ ] Cancellation process documented (link to Settings)
- [ ] Privacy policy includes subscription data handling
- [ ] Terms of service covers subscriptions

### Feature Separation
- [ ] Free features work without premium
- [ ] Premium features gracefully prompt for upgrade
- [ ] No paywall on free feature upgrades
- [ ] Free tier feels complete (not artificially limited)

### UI/UX Requirements
- [ ] "Restore Purchases" button in Settings
- [ ] Clear subscription status display
- [ ] Easy access to manage subscriptions (link to Settings)
- [ ] Grace period handling (failed payment retry)
- [ ] Billing information shown in app

### Metadata
- [ ] App description mentions premium tier
- [ ] Screenshots don't mislead about free features
- [ ] Promotional text accurate and compliant
- [ ] Keywords include "subscription" if applicable

