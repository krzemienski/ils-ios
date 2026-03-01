# Phase 46: Security & Compliance - Research

**Researched:** 2026-02-27
**Domain:** Backend authorization, request validation, GDPR data deletion, StoreKit 2 subscription compliance
**Confidence:** HIGH

## Summary

Phase 46 addresses five security and compliance gaps identified in the Gap Analysis (Spec C items 1.2, 1.8, 1.11, 10.10, 10.12). The backend currently has global API key authentication via `APIKeyMiddleware` but no role-based distinction. Request body size is set globally at 10MB but lacks explicit per-route enforcement middleware that returns clear errors. Individual DELETE endpoints exist for sessions, projects, themes, etc., but there is no single "delete all my data" endpoint. StoreKit 2 integration is functional (SubscriptionManager, FeatureGate, PremiumView all exist) but lacks a `.storekit` configuration file for sandbox testing and does not surface trial period information from `Product.SubscriptionInfo`.

All five requirements are achievable with the existing Vapor + StoreKit 2 stack. No new dependencies are needed. The primary work is adding a role-based middleware layer to the backend, creating a GDPR data erasure controller, adding a `.storekit` configuration file, and enhancing the paywall to display dynamic trial information from StoreKit 2's `introductoryOffer` API.

**Primary recommendation:** Use Vapor's route-group middleware pattern (`routes.grouped(AdminMiddleware())`) for role-based auth, create a dedicated `DataErasureController` for GDPR, create a `Products.storekit` configuration file for sandbox testing, and use `Product.SubscriptionInfo.introductoryOffer` + `isEligibleForIntroOffer` for dynamic trial display.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SEC-01 | Per-route authorization (admin vs user distinction) beyond global API key middleware | Vapor `grouped()` middleware pattern enables route-group-level auth. Create `AdminMiddleware` that checks a role header/token claim. Apply to sensitive route groups (config, system, fleet, tunnel). See Architecture Pattern 1. |
| SEC-02 | Request size limits explicitly configured in Vapor middleware | Already have `app.routes.defaultMaxBodySize = "10mb"` globally. Add explicit `RequestSizeLimitMiddleware` that catches `Abort(.payloadTooLarge)` with a clear JSON error. Can also use per-route `body: .collect(maxSize:)` for specific routes. See Architecture Pattern 2. |
| SEC-03 | GDPR single "delete all my data" endpoint aggregating all user data deletion | Create `DataErasureController` with `DELETE /api/v1/data/all`. Aggregates deletion across 6 Fluent models: SessionModel, MessageModel, ProjectModel, ThemeModel, FleetHostModel, CachedResult. Uses database transaction for atomicity. See Architecture Pattern 3. |
| SEC-04 | Free trial StoreKit configuration verified and functional | Create `ILSApp/Products.storekit` configuration file with monthly + annual products and 7-day free trial offer. Reference in Xcode scheme. Use `product.subscription?.introductoryOffer` to read trial details dynamically. See Architecture Pattern 4. |
| SEC-05 | Receipt validation flow verified with StoreKit 2 server-side | Existing `SubscriptionManager.checkVerified()` already does JWS verification via `VerificationResult`. Enhance `checkSubscriptionStatus()` to update premium state immediately on purchase. Verify `Transaction.currentEntitlements` flow handles renewal, revocation, and refund. See Architecture Pattern 5. |
</phase_requirements>

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Vapor 4 | 4.x (current) | Backend framework, middleware, route groups | Already in use; native middleware grouping pattern |
| Fluent | 4.x (current) | ORM for database transactions (GDPR deletion) | Already in use; transaction support built-in |
| StoreKit 2 | iOS 15+ / macOS 12+ | Subscription management, receipt verification | Already in use via `SubscriptionManager.swift` |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| FluentSQLiteDriver | 4.x | SQLite database driver | Already in use; needed for batch deletion |
| CryptoKit | iOS 13+ | Constant-time comparison (already in APIKeyMiddleware) | Token validation |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom AdminMiddleware | Vapor's built-in `ModelAuthenticatable` + `GuardMiddleware` | `ModelAuthenticatable` requires a User model with database-backed sessions. Overkill for a local-first app with simple admin/user distinction. Custom middleware is simpler. |
| Per-route body size via middleware | Vapor's `body: .collect(maxSize:)` on individual routes | Per-route is more granular but requires touching every route registration. Global middleware with override capability is more maintainable. |
| Server-side receipt validation endpoint | StoreKit 2 JWS local verification | StoreKit 2 JWS verification is built into the framework -- no need for a separate server endpoint. Apple recommends local verification for most use cases. |

## Architecture Patterns

### Recommended Project Structure

```
Sources/ILSBackend/
├── Middleware/
│   ├── APIKeyMiddleware.swift       # (existing) Global API key auth
│   ├── AdminMiddleware.swift        # (NEW) Role-based route guard
│   ├── RequestSizeLimitMiddleware.swift  # (NEW) Explicit size limit with clear errors
│   ├── RateLimitMiddleware.swift    # (existing)
│   ├── ILSErrorMiddleware.swift     # (existing)
│   └── RequestLoggingMiddleware.swift   # (existing)
├── Controllers/
│   ├── DataErasureController.swift  # (NEW) GDPR "delete all my data"
│   └── ... (existing controllers)
└── App/
    └── routes.swift                 # Updated with admin-protected groups

ILSApp/
├── ILSApp/
│   ├── Services/
│   │   └── SubscriptionManager.swift  # Enhanced with trial detection
│   └── Views/
│       └── Premium/
│           └── PremiumView.swift      # Enhanced with dynamic trial info
└── Products.storekit                  # (NEW) StoreKit configuration file
```

### Pattern 1: Role-Based Route Authorization (SEC-01)

**What:** An `AdminMiddleware` that checks for an admin role indicator and returns 403 Forbidden for non-admin requests to sensitive endpoints.

**When to use:** Applied to route groups for config, system, fleet, and tunnel controllers -- endpoints that modify server configuration.

**Design decision:** The ILS backend is local-first (runs on the user's own machine). The admin/user distinction is lightweight -- not a full RBAC system. Use an environment variable `ILS_ADMIN_KEY` separate from `ILS_API_KEY`. Requests to admin routes must include `X-Admin-Token` header matching the admin key. When no admin key is configured (development mode), all requests pass through (same pattern as `APIKeyMiddleware`).

**Example:**
```swift
// Source: Vapor docs - route group middleware pattern
// https://docs.vapor.codes/security/authentication/

struct AdminMiddleware: AsyncMiddleware {
    private let adminKey: String?

    init() {
        self.adminKey = Environment.get("ILS_ADMIN_KEY")
    }

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Development mode: no admin key configured means open access
        guard let adminKey = adminKey, !adminKey.isEmpty else {
            return try await next.respond(to: request)
        }

        guard let providedKey = request.headers.first(name: "X-Admin-Token") else {
            throw Abort(.forbidden, reason: "Admin access required. Include 'X-Admin-Token' header.")
        }

        guard constantTimeEqual(providedKey, adminKey) else {
            throw Abort(.forbidden, reason: "Invalid admin token.")
        }

        return try await next.respond(to: request)
    }

    private func constantTimeEqual(_ a: String, _ b: String) -> Bool {
        let aBytes = Array(a.utf8)
        let bBytes = Array(b.utf8)
        guard aBytes.count == bBytes.count else { return false }
        var result: UInt8 = 0
        for i in 0..<aBytes.count {
            result |= aBytes[i] ^ bBytes[i]
        }
        return result == 0
    }
}

// In routes.swift:
func routes(_ app: Application) throws {
    let api = app.grouped("api", "v1")

    // Public routes (API key only)
    try api.register(collection: SessionsController(...))
    try api.register(collection: ChatController())
    // ...

    // Admin-protected routes
    let admin = api.grouped(AdminMiddleware())
    try admin.register(collection: ConfigController(...))
    try admin.register(collection: SystemController())
    try admin.register(collection: FleetController())
    try admin.register(collection: TunnelController())
    try admin.register(collection: DataErasureController())
}
```

### Pattern 2: Request Size Limit Middleware (SEC-02)

**What:** Explicit middleware that intercepts Vapor's `.payloadTooLarge` abort and returns a structured JSON error with the configured limit.

**When to use:** Applied globally via `app.middleware.use()`. The existing `app.routes.defaultMaxBodySize = "10mb"` already enforces the limit, but when exceeded, Vapor throws a generic error. This middleware wraps it in the app's standard `ErrorBody` format.

**Current state:** `configure.swift` line 55 already sets `app.routes.defaultMaxBodySize = "10mb"`. The `ILSErrorMiddleware` already handles `Abort` errors. So SEC-02 is partially met. The enhancement is: (a) make the limit configurable via environment variable, (b) ensure the error message explicitly states the limit, and (c) optionally set tighter limits on specific routes.

**Example:**
```swift
// In configure.swift:
let maxBodyMB = Int(Environment.get("ILS_MAX_BODY_MB") ?? "10") ?? 10
app.routes.defaultMaxBodySize = "\(maxBodyMB)mb"

// ILSErrorMiddleware already catches Abort(.payloadTooLarge) via the default case.
// Enhancement: add explicit case in httpStatusToCode():
case .payloadTooLarge: return "PAYLOAD_TOO_LARGE"

// Per-route override for chat (which may have large message content):
chat.on(.POST, "stream", body: .collect(maxSize: "2mb")) { req in ... }
```

### Pattern 3: GDPR Data Erasure (SEC-03)

**What:** A single `DELETE /api/v1/data/all` endpoint that deletes all user data in a database transaction.

**When to use:** GDPR Article 17 "Right to Erasure" compliance. User triggers from Settings screen.

**Data scope (6 Fluent tables):**
1. `messages` -- All chat messages (FK to sessions, must delete first due to foreign key)
2. `sessions` -- All chat sessions
3. `projects` -- All project records
4. `themes` -- All custom themes
5. `fleet_hosts` -- All fleet host configurations
6. `cached_results` -- All cached search results

**Example:**
```swift
// Source: Fluent transaction documentation
struct DataErasureController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let data = routes.grouped("data")
        data.delete("all", use: deleteAllData)
    }

    @Sendable
    func deleteAllData(req: Request) async throws -> APIResponse<DataErasureResponse> {
        var counts = DataErasureResponse()

        try await req.db.transaction { db in
            // Delete in FK-safe order (children before parents)
            counts.messagesDeleted = try await MessageModel.query(on: db).count()
            try await MessageModel.query(on: db).delete()

            counts.sessionsDeleted = try await SessionModel.query(on: db).count()
            try await SessionModel.query(on: db).delete()

            counts.projectsDeleted = try await ProjectModel.query(on: db).count()
            try await ProjectModel.query(on: db).delete()

            counts.themesDeleted = try await ThemeModel.query(on: db).count()
            try await ThemeModel.query(on: db).delete()

            counts.fleetHostsDeleted = try await FleetHostModel.query(on: db).count()
            try await FleetHostModel.query(on: db).delete()

            counts.cacheEntriesDeleted = try await CachedResult.query(on: db).count()
            try await CachedResult.query(on: db).delete()
        }

        return APIResponse(success: true, data: counts)
    }
}

// In ILSShared/DTOs/ResponseDTOs.swift:
public struct DataErasureResponse: Codable, Sendable {
    public var messagesDeleted: Int = 0
    public var sessionsDeleted: Int = 0
    public var projectsDeleted: Int = 0
    public var themesDeleted: Int = 0
    public var fleetHostsDeleted: Int = 0
    public var cacheEntriesDeleted: Int = 0
}
```

### Pattern 4: StoreKit Configuration File (SEC-04)

**What:** A `.storekit` configuration file that defines subscription products with free trial offers for Xcode sandbox testing.

**When to use:** Required for local development and Xcode simulator testing of subscription flows.

**Current state:** No `.storekit` file exists. `SubscriptionManager` references `com.ils.app.premium.monthly` and `com.ils.app.premium.annual` product IDs. `PremiumView` has a hardcoded "7-day free trial" callout but does not read the actual trial period from StoreKit.

**Example:**
```json
// Products.storekit (Xcode StoreKit Configuration File)
{
  "identifier": "ILS Products",
  "type": "Configuration",
  "version": 3,
  "subscriptionGroups": [
    {
      "id": "premium_subscriptions",
      "localizations": [{ "locale": "en_US", "displayName": "Premium" }],
      "subscriptions": [
        {
          "adHocOffers": [],
          "codeOffers": [],
          "displayPrice": "4.99",
          "familyShareable": false,
          "groupNumber": 1,
          "introductoryOffer": {
            "ineligibleAfterPurchase": true,
            "numberOfPeriods": 1,
            "paymentMode": "free",
            "subscriptionPeriod": "P1W"
          },
          "productID": "com.ils.app.premium.monthly",
          "recurringSubscriptionPeriod": "P1M",
          "referenceName": "ILS Premium Monthly",
          "subscriptionGroupID": "premium_subscriptions",
          "type": "RecurringSubscription"
        },
        {
          "adHocOffers": [],
          "codeOffers": [],
          "displayPrice": "49.99",
          "familyShareable": false,
          "groupNumber": 1,
          "introductoryOffer": {
            "ineligibleAfterPurchase": true,
            "numberOfPeriods": 1,
            "paymentMode": "free",
            "subscriptionPeriod": "P1W"
          },
          "productID": "com.ils.app.premium.annual",
          "recurringSubscriptionPeriod": "P1Y",
          "referenceName": "ILS Premium Annual",
          "subscriptionGroupID": "premium_subscriptions",
          "type": "RecurringSubscription"
        }
      ]
    }
  ]
}
```

### Pattern 5: Receipt Validation & Trial Display (SEC-05)

**What:** Enhance `SubscriptionManager` to expose trial eligibility and `PremiumView` to display dynamic trial information from StoreKit 2.

**Current state:** `SubscriptionManager.checkVerified()` already does JWS verification via `VerificationResult.verified`/`.unverified`. The `checkSubscriptionStatus()` method iterates `Transaction.currentEntitlements`. `PremiumView` hardcodes "7-day free trial" text.

**Enhancement:**
```swift
// Source: Apple StoreKit 2 documentation
// https://developer.apple.com/documentation/storekit/product/subscriptioninfo/introductoryoffer

// In SubscriptionManager:
private(set) var trialEligible: Bool = false
private(set) var trialDurationDays: Int?

func checkTrialEligibility() async {
    for product in products {
        guard let subscription = product.subscription else { continue }
        if await subscription.isEligibleForIntroOffer,
           let introOffer = subscription.introductoryOffer,
           introOffer.paymentMode == .freeTrial {
            trialEligible = true
            // Extract trial duration from period
            let period = introOffer.period
            switch period.unit {
            case .day: trialDurationDays = period.value
            case .week: trialDurationDays = period.value * 7
            case .month: trialDurationDays = period.value * 30
            case .year: trialDurationDays = period.value * 365
            @unknown default: trialDurationDays = nil
            }
            break
        }
    }
}

// In PremiumView trialCallout:
@ViewBuilder
private var trialCallout: some View {
    if subscriptionManager.trialEligible, let days = subscriptionManager.trialDurationDays {
        // Show dynamic trial callout with actual duration
        HStack { ... Text("\(days)-day free trial") ... }
    }
    // Hide callout entirely when not eligible
}
```

### Anti-Patterns to Avoid

- **Full RBAC for a local-first app:** This is not a multi-tenant SaaS. A simple admin-key check is appropriate. Do not build user tables, JWT token generation, or session-based auth.
- **Hardcoded trial duration in UI:** Always read from `Product.SubscriptionInfo.introductoryOffer` so the UI reflects App Store Connect configuration changes without code updates.
- **Deleting data without transaction:** GDPR deletion must be atomic. If message deletion succeeds but session deletion fails, the database is in an inconsistent state. Always use `req.db.transaction`.
- **Calling count() then delete() outside transaction:** Between the count and delete, rows could change. Both operations must be inside the same transaction.
- **Suppressing `.payloadTooLarge` errors:** Vapor's default handling throws an Abort, which `ILSErrorMiddleware` already catches. Do not add a separate middleware that swallows the error -- just ensure the error code mapping is explicit.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Receipt verification | Custom JWS parser | StoreKit 2 `VerificationResult` | Apple handles JWS verification internally; custom parsers are error-prone and a security risk |
| Route authorization | Custom request pipeline | Vapor `grouped()` middleware | Vapor's middleware chaining is battle-tested and composes cleanly |
| Constant-time comparison | Naive `==` string comparison | Byte-by-byte XOR (already in `APIKeyMiddleware`) | Prevents timing attacks on secret comparison |
| Database transactions | Manual BEGIN/COMMIT SQL | Fluent `req.db.transaction {}` | Handles rollback automatically on throw |
| Trial period calculation | Parse App Store Connect config manually | `Product.SubscriptionInfo.introductoryOffer.period` | StoreKit 2 provides structured period data |

**Key insight:** StoreKit 2 and Vapor both provide high-level abstractions for these security/compliance concerns. The risk is in not using the built-in patterns (e.g., rolling custom receipt validation or manual SQL transactions).

## Common Pitfalls

### Pitfall 1: Foreign Key Ordering in Bulk Delete
**What goes wrong:** Deleting sessions before messages causes FK constraint violations because `messages.session_id` references `sessions.id`.
**Why it happens:** SQLite enforces FK constraints (enabled in `configure.swift`).
**How to avoid:** Delete in reverse FK order: messages first, then sessions. The `DataErasureController` must follow this ordering inside the transaction.
**Warning signs:** `FOREIGN KEY constraint failed` error on bulk deletion.

### Pitfall 2: StoreKit Configuration File Not Referenced in Scheme
**What goes wrong:** Creating `Products.storekit` but not selecting it in the Xcode scheme means sandbox testing uses no products.
**Why it happens:** Xcode requires explicit scheme configuration to use a `.storekit` file for testing.
**How to avoid:** After creating the file, edit the `ILSApp` scheme: Run > Options > StoreKit Configuration > select `Products.storekit`.
**Warning signs:** `products` array is empty after `Product.products(for:)` call in simulator.

### Pitfall 3: Admin Middleware Blocking Development
**What goes wrong:** Adding `AdminMiddleware` to config/system/fleet routes breaks development workflow because no admin key is set.
**Why it happens:** Forgetting the "open access when no key configured" pattern.
**How to avoid:** Mirror the `APIKeyMiddleware` pattern: `guard let adminKey = adminKey, !adminKey.isEmpty else { return try await next.respond(to: request) }`.
**Warning signs:** 403 errors on all admin routes during local development.

### Pitfall 4: Hardcoded Trial Text When Not Eligible
**What goes wrong:** Showing "7-day free trial" to users who already used their trial.
**Why it happens:** Hardcoded text in `PremiumView` instead of checking `isEligibleForIntroOffer`.
**How to avoid:** Always check `product.subscription?.isEligibleForIntroOffer` before showing trial callout. Hide the section entirely when not eligible.
**Warning signs:** Returning customers see "Start Free Trial" button but get charged immediately.

### Pitfall 5: Vapor `.payloadTooLarge` Not in Error Code Map
**What goes wrong:** Oversized requests return a generic error code instead of a specific `PAYLOAD_TOO_LARGE` code.
**Why it happens:** `ILSErrorMiddleware.httpStatusToCode()` has no explicit case for `.payloadTooLarge` -- it falls into the `400..<500` default returning `CLIENT_ERROR`.
**How to avoid:** Add `case .payloadTooLarge: return "PAYLOAD_TOO_LARGE"` to the switch statement.
**Warning signs:** iOS client can't distinguish between payload-too-large and other 4xx errors.

## Code Examples

Verified patterns from official sources:

### Vapor Route-Group Middleware (from Vapor docs)
```swift
// Source: https://docs.vapor.codes/security/authentication/
let protected = app.routes.grouped([
    app.sessions.middleware,
    UserSessionAuthenticator(),
    UserBearerAuthenticator(),
    User.guardMiddleware(),
])

protected.get("me") { req -> String in
    try req.auth.require(User.self).email
}
```

### Vapor Per-Route Body Size (from Vapor docs)
```swift
// Source: https://docs.vapor.codes/basics/routing/
app.on(.POST, "listings", body: .collect(maxSize: "1mb")) { req in
    // Handle request
}

// Global default:
app.routes.defaultMaxBodySize = "500kb"
```

### StoreKit 2 Intro Offer Check (from Apple docs)
```swift
// Source: https://developer.apple.com/documentation/storekit/product/subscriptioninfo/iseligibleforintrooffer
func eligibleForIntro(product: Product) async throws -> Bool {
    guard let renewableSubscription = product.subscription else {
        return false
    }
    if await renewableSubscription.isEligibleForIntroOffer {
        return true
    }
    return false
}
```

### StoreKit 2 Introductory Offer Access (from Apple docs)
```swift
// Source: https://developer.apple.com/documentation/storekit/product/subscriptioninfo/introductoryoffer
let introductoryOffer: Product.SubscriptionOffer? // nil if no offer configured
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| StoreKit 1 receipt validation (server-side) | StoreKit 2 JWS `VerificationResult` (local) | iOS 15 / WWDC 2021 | No server endpoint needed; Apple handles verification |
| `SKPaymentQueue` observer pattern | `Transaction.updates` async sequence | iOS 15 / WWDC 2021 | Cleaner async/await integration |
| Manual receipt parsing + App Store `/verifyReceipt` | `Transaction.currentEntitlements` | iOS 15 / WWDC 2021 | No need to call Apple's deprecated `/verifyReceipt` endpoint |
| HTTP Basic Auth | Bearer token + middleware groups | Vapor 4 | Composable middleware chain |

**Deprecated/outdated:**
- `SKPaymentQueue`, `SKProduct`, `SKPaymentTransaction`: Replaced by StoreKit 2 types (`Product`, `Transaction`). Still functional but not recommended.
- Apple's `/verifyReceipt` endpoint: Deprecated. StoreKit 2 uses local JWS verification.
- `ObservableObject` / `@Published`: App uses `@Observable` (Observation framework). SubscriptionManager already uses this correctly.

## Open Questions

1. **Which routes should be admin-only?**
   - What we know: Config (PUT), System, Fleet, Tunnel, and DataErasure are candidates. GET endpoints for config/system are arguably user-readable.
   - What's unclear: Should GET endpoints also require admin? Should chat/sessions have any admin distinction?
   - Recommendation: Protect only mutating routes (PUT/POST/DELETE) on config, system, fleet, tunnel, and data-erasure. Leave GET endpoints accessible to all authenticated users. This is the least disruptive change.

2. **iOS-side "Delete All Data" UI location**
   - What we know: The GDPR endpoint is backend-only. The iOS app needs a button to trigger it.
   - What's unclear: Where in Settings should "Delete All My Data" appear?
   - Recommendation: Add to Settings under a "Privacy" or "Data & Privacy" section, with a confirmation alert (destructive action). This is a standard iOS pattern.

3. **StoreKit configuration file format version**
   - What we know: Xcode 15+ uses version 3 format for `.storekit` files. Earlier versions used version 2.
   - What's unclear: Whether the project targets Xcode 15+ exclusively.
   - Recommendation: Use version 3 format. The project targets iOS 17+ (per project.md), which aligns with Xcode 15+.

## Sources

### Primary (HIGH confidence)
- Vapor official docs (Context7 `/websites/vapor_codes`) - Route groups, middleware, body size configuration
- Apple StoreKit docs (Context7 `/websites/developer_apple_storekit`) - `isEligibleForIntroOffer`, `introductoryOffer`, `VerificationResult`, StoreKit configuration testing

### Secondary (MEDIUM confidence)
- ILS codebase analysis - Direct file reads of all relevant middleware, controllers, models, and services
- ILS monetization docs (`docs/monetization/MONETIZATION_IMPLEMENTATION_GUIDE.md`) - Product IDs, pricing, StoreKit configuration template
- ILS Gap Analysis (`.planning/quick/6-comprehensive-ils-audit-and-remediation-/GAP-ANALYSIS.md`) - SEC-01 through SEC-05 gap identification

### Tertiary (LOW confidence)
- None. All findings verified against official documentation or direct codebase inspection.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Vapor 4 and StoreKit 2 are already in use; patterns verified against official docs via Context7
- Architecture: HIGH - All patterns follow existing codebase conventions (middleware pattern, controller pattern, DTO pattern)
- Pitfalls: HIGH - FK ordering verified against actual schema; StoreKit trial patterns verified against Apple docs

**Research date:** 2026-02-27
**Valid until:** 2026-03-27 (30 days - stable frameworks, no breaking changes expected)
