---
type: external-spec
source-type: mcp-server
source-id: xclaude-plugin
fetched: 2026-02-05T21:48:00Z
---

# xclaude-plugin MCP Server (Xcode & Simulator Tools)

## Summary
MCP server providing comprehensive Xcode build, test, and iOS Simulator automation tools. Enables building projects, running tests, managing simulators, capturing screenshots, interacting with UI elements via accessibility tree, and performing gestures programmatically.

## Available Tools

### Xcode Build & Test
| Tool | Description |
|------|-------------|
| xcode_build | Build Xcode project. Params: scheme (required), configuration, destination, project_path |
| xcode_clean | Clean Xcode build artifacts. Params: scheme, project_path |
| xcode_test | Run Xcode test suite. Params: scheme (required), destination, only_testing, test_plan |
| xcode_list | List Xcode schemes and targets |
| xcode_version | Get Xcode version information |

### Simulator Management
| Tool | Description |
|------|-------------|
| simulator_list | List available iOS simulators with filters (availability, device_type, runtime) |
| simulator_boot | Boot a simulator device by UDID or name |
| simulator_shutdown | Shutdown a running simulator |
| simulator_create | Create a new simulator device (name, type, runtime) |
| simulator_delete | Delete a simulator device by UDID |
| simulator_health_check | Validate iOS development environment |

### App Management
| Tool | Description |
|------|-------------|
| simulator_install_app | Install .app bundle on simulator |
| simulator_launch_app | Launch app by bundle identifier |
| simulator_terminate_app | Terminate a running app |
| simulator_get_app_container | Get app container filesystem path (data, bundle, group) |
| simulator_openurl | Open URL or deep link in simulator |

### UI Automation (idb)
| Tool | Description |
|------|-------------|
| simulator_screenshot | Capture simulator screenshot to file |
| idb_describe | Query UI accessibility tree (all elements or specific point) |
| idb_tap | Tap at UI coordinates with optional duration |
| idb_input | Type text or press keys in simulator |
| idb_gesture | Perform swipe gestures or hardware button presses |
| idb_find_element | Search UI elements by label or identifier (semantic search) |
| idb_check_quality | Check accessibility data quality before deciding on screenshot |

## Usage Patterns
- **Build & Run**: xcode_build -> simulator_boot -> simulator_install_app -> simulator_launch_app
- **Screenshot capture**: simulator_screenshot (saves to file, read with Read tool)
- **UI interaction**: idb_find_element -> idb_tap or idb_describe -> idb_tap at coordinates
- **Testing**: xcode_test with scheme and destination
- **Deep linking**: simulator_openurl with custom URL scheme

## Project-Specific Notes
- Dedicated simulator UDID: 50523130-57AA-48B0-ABD0-4D59CE455F14
- Bundle ID: com.ils.app
- URL scheme: ils://
- Scheme name: ILSApp

## Keywords
xcode simulator ios build test screenshot ui-automation accessibility idb tap gesture deep-link app-management

## Related Components
- helper-ilsappapp.md (app entry point, URL scheme handling)
- helper-configure.md (backend configuration)
- service-apiclient.md (API connectivity)
- service-sseclient.md (SSE streaming)
- All helper-*view.md files (UI components for screenshot validation)
