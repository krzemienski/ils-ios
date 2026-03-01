# iPhone 5.5" Screenshots — Not Required

## Status: SKIPPED (Not Required)

As of **September 2024**, Apple App Store Connect no longer requires iPhone 5.5" (1242×2208) screenshots.

### Current Requirements

| Display Size | Status |
|---|---|
| **6.7" / 6.9"** (iPhone 15/16 Pro Max) | ✅ **Required** — see `../iphone_67/` |
| **6.1"** (iPhone 14 / 15) | Optional — see `../iphone_61/` |
| **5.5"** (iPhone 8 Plus) | ❌ **Not required** — auto-scaled from 6.7" |
| **13" iPad** | ✅ **Required** (if iPad supported) — see `../ipad_13/` |

### Why No Screenshots Here

- The 5.5" display (iPhone 6 Plus / 7 Plus / 8 Plus) is no longer supported by iOS 17+
- Apple auto-scales from the mandatory 6.7" screenshots to populate all smaller device listings
- App Store Connect marks this size as **Optional** and no longer blocks submission without it
- Our `../iphone_67/` directory contains the required 1320×2868px screenshots

### References

- [Apple Screenshot Specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- Verified: 2024-09-01 (policy change effective with Xcode 16 / iOS 18 launch)
