# Testing Quick Start Guide

## 🚀 Run Tests in 30 Seconds

### Option 1: Quick Smoke Tests (Recommended for Development)
```bash
cd /Users/nick/Desktop/ils-ios/ILSApp
./scripts/run-ui-tests.sh --quick
```
**Runs**: 5 essential tests in ~2-3 minutes

### Option 2: Full Test Suite
```bash
./scripts/run-ui-tests.sh --full
```
**Runs**: All 26 tests with retry on failure (~15-20 minutes)

### Option 3: Default Configuration
```bash
./scripts/run-ui-tests.sh
```
**Runs**: All 26 tests, single pass (~8-12 minutes)

## 📱 Test Different Devices

```bash
# iPhone
./scripts/run-ui-tests.sh --quick --device "iPhone 15 Pro"

# iPad
./scripts/run-ui-tests.sh --quick --device "iPad Pro (12.9-inch) (6th generation)"

# iPhone with smaller screen
./scripts/run-ui-tests.sh --quick --device "iPhone SE (3rd generation)"
```

## 🌍 Test Localization

```bash
# German
./scripts/run-ui-tests.sh --config "Localization Testing - German"

# Japanese
./scripts/run-ui-tests.sh --config "Localization Testing - Japanese"

# Arabic (RTL)
./scripts/run-ui-tests.sh --config "Localization Testing - Arabic (RTL)"
```

## ⚡ Parallel Execution (Faster)

```bash
./scripts/run-ui-tests.sh --parallel --full
```

## 🔍 View Results

Results are saved to `test-results/` directory.

**Open result bundle in Xcode:**
```bash
open test-results/TestResults_*.xcresult
```

**View JSON summary:**
```bash
cat test-results/summary_*.json | python3 -m json.tool
```

**View screenshots:**
```bash
open test-results/screenshots_*/
```

## 📊 Test Configurations

| Config | Tests | Duration | When to Use |
|--------|-------|----------|-------------|
| **Quick Smoke Tests** | 5 | 2-3 min | Pre-commit, fast validation |
| **Default Configuration** | 26 | 8-12 min | CI/CD, standard testing |
| **Full Regression** | 26 | 15-20 min | Pre-release, major changes |
| **Localization** | 26 | 10-15 min | i18n validation |

## 🧪 Test Coverage

### Quick Smoke Tests Include:
1. ✓ Sessions list loads
2. ✓ Projects list loads
3. ✓ Skills list loads
4. ✓ Settings view loads
5. ✓ Plugins list loads

### Full Suite Includes:
- **8 tests**: Core chat flow (sessions, messages, streaming)
- **17 tests**: Feature views (projects, skills, MCP, settings, plugins)
- **1 test**: Basic navigation

## 🛠️ Script Options

```
-q, --quick       Quick smoke tests (5 tests)
-f, --full        Full regression with retries
-d, --device      Specify device name
-o, --output      Custom output directory
-p, --parallel    Enable parallel execution
-v, --verbose     Detailed output
-h, --help        Show all options
```

## 🔧 Troubleshooting

**Tests can't find elements?**
- Ensure backend server is running
- Check iOS simulator version compatibility
- Increase timeouts in test code if needed

**Script won't execute?**
```bash
chmod +x ./scripts/run-ui-tests.sh
```

**Want to see what's happening?**
```bash
./scripts/run-ui-tests.sh --quick --verbose
```

## 📝 CI/CD Integration

**GitHub Actions:**
```yaml
- name: UI Tests
  run: |
    cd ILSApp
    ./scripts/run-ui-tests.sh --quick
```

**Pre-commit Hook:**
```bash
#!/bin/bash
cd ILSApp && ./scripts/run-ui-tests.sh --quick || exit 1
```

## 📚 More Information

- **Full Documentation**: See `ILSAppUITests/README.md`
- **Test Plan Details**: See `TEST_PLAN_SUMMARY.md`
- **Test Classes**: See `ILSAppUITests/*.swift`

## ✅ Validation Checklist

Before committing:
- [ ] Run quick smoke tests
- [ ] All 5 essential tests pass
- [ ] No new test failures introduced

Before releasing:
- [ ] Run full regression suite
- [ ] All 26 tests pass
- [ ] Test on multiple devices/screen sizes
- [ ] Run localization tests if UI changed
