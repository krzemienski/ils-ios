#!/usr/bin/env swift
//
// Port Forwarding Verification Script
// Subtask 7-4: Verify port forwarding with real HTTP request through tunnel
//
// Usage:
//   swift test-port-forwarding.swift
//
// Prerequisites:
//   - Remote server with SSH access
//   - Service running on remote port 9999 (e.g., ILS backend, Python http.server)
//   - Update HOST, USERNAME, PASSWORD below with your test server details
//

import Foundation

// MARK: - Configuration

// TODO: Update these with your test server details
let SSH_HOST = "your-remote-host.com"
let SSH_PORT = 22
let SSH_USERNAME = "your-username"
let SSH_PASSWORD = "your-password"
let SSH_AUTH_METHOD = "password" // or "ssh-key"

let LOCAL_PORT = 8080
let REMOTE_HOST = "localhost"
let REMOTE_PORT = 9999

// MARK: - Test Script

print("=== Port Forwarding Verification Test ===\n")

print("Configuration:")
print("  SSH Target: \(SSH_USERNAME)@\(SSH_HOST):\(SSH_PORT)")
print("  Port Forward: localhost:\(LOCAL_PORT) -> \(REMOTE_HOST):\(REMOTE_PORT)")
print("")

print("⚠️  IMPORTANT: This is a template script.")
print("⚠️  The actual test requires:")
print("   1. Running iOS app with CitadelSSHService")
print("   2. Establishing SSH connection")
print("   3. Calling startPortForwarding()")
print("   4. Making HTTP request to localhost:\(LOCAL_PORT)")
print("")

// MARK: - Manual Verification Steps

print("Manual Verification Steps:")
print("")
print("Step 1: Establish SSH Connection")
print("-------------------------------------")
print("""
// In your iOS app or test harness:
let service = CitadelSSHService()

let connected = try await service.connect(
    host: "\(SSH_HOST)",
    port: \(SSH_PORT),
    username: "\(SSH_USERNAME)",
    authMethod: "\(SSH_AUTH_METHOD)",
    credential: "\(SSH_PASSWORD)"
)

guard connected else {
    print("Failed to connect")
    return
}
print("✅ SSH connection established")
""")
print("")

print("Step 2: Start Port Forwarding")
print("-------------------------------------")
print("""
let localURL = try await service.startPortForwarding(
    localPort: \(LOCAL_PORT),
    remoteHost: "\(REMOTE_HOST)",
    remotePort: \(REMOTE_PORT)
)
print("✅ Port forwarding started: \\(localURL)")
""")
print("")

print("Step 3: Test HTTP Request Through Tunnel")
print("-------------------------------------")
print("""
// In Terminal on your Mac:
curl http://localhost:\(LOCAL_PORT)/health

Expected Response:
  {"status": "ok", ...}  (from remote service)

If you get connection refused:
  - Verify remote service is running on port \(REMOTE_PORT)
  - Check: ssh \(SSH_USERNAME)@\(SSH_HOST) "lsof -i :\(REMOTE_PORT)"
""")
print("")

print("Step 4: Test Multiple Requests")
print("-------------------------------------")
print("""
# Test health endpoint
curl http://localhost:\(LOCAL_PORT)/health

# Test API endpoints (if ILS backend)
curl http://localhost:\(LOCAL_PORT)/api/v1/sessions

# Test POST request
curl -X POST http://localhost:\(LOCAL_PORT)/api/v1/projects \\
  -H "Content-Type: application/json" \\
  -d '{}'
""")
print("")

print("Step 5: Stop Port Forwarding")
print("-------------------------------------")
print("""
// In your iOS app:
try await service.stopPortForwarding(localPort: \(LOCAL_PORT))
print("✅ Port forwarding stopped")

// Verify port released:
// curl http://localhost:\(LOCAL_PORT)/health
// Expected: Connection refused (port no longer forwarded)
""")
print("")

print("Step 6: Verify Cleanup")
print("-------------------------------------")
print("""
// In Terminal:
lsof -i :\(LOCAL_PORT)
# Expected: No output (port released)

// In your iOS app:
let forwardings = await service.getActivePortForwardings()
print("Active forwardings: \\(forwardings)")
# Expected: Empty dictionary
""")
print("")

// MARK: - Alternative Test with Python HTTP Server

print("\n=== Alternative: Test with Python HTTP Server ===\n")
print("If you don't have ILS backend running on the remote server:")
print("")
print("On Remote Server:")
print("  ssh \(SSH_USERNAME)@\(SSH_HOST)")
print("  python3 -m http.server \(REMOTE_PORT)")
print("")
print("After Port Forwarding Setup:")
print("  curl http://localhost:\(LOCAL_PORT)/")
print("  # Expected: HTML directory listing from remote server")
print("")

// MARK: - Success Criteria

print("=== Success Criteria ===\n")
let criteria = [
    "✅ SSH connection establishes without errors",
    "✅ startPortForwarding() returns local URL",
    "✅ curl http://localhost:\(LOCAL_PORT)/... receives response from remote service",
    "✅ Multiple HTTP requests work through the tunnel",
    "✅ POST requests with body data work",
    "✅ stopPortForwarding() releases the port",
    "✅ After stop, curl fails with connection refused",
    "✅ getActivePortForwardings() shows correct state"
]

for criterion in criteria {
    print(criterion)
}
print("")

// MARK: - Code Example Integration

print("=== Full Integration Example ===\n")
print("""
import Foundation

@MainActor
func testPortForwarding() async {
    let service = CitadelSSHService()

    do {
        // 1. Connect via SSH
        print("Connecting to SSH...")
        let connected = try await service.connect(
            host: "\(SSH_HOST)",
            port: \(SSH_PORT),
            username: "\(SSH_USERNAME)",
            authMethod: "\(SSH_AUTH_METHOD)",
            credential: "\(SSH_PASSWORD)"
        )

        guard connected else {
            print("❌ Failed to connect")
            return
        }
        print("✅ SSH connected")

        // 2. Start port forwarding
        print("Starting port forwarding...")
        let localURL = try await service.startPortForwarding(
            localPort: \(LOCAL_PORT),
            remoteHost: "\(REMOTE_HOST)",
            remotePort: \(REMOTE_PORT)
        )
        print("✅ Port forwarding active: \\(localURL)")
        print("   Test with: curl \\(localURL)/health")

        // 3. Wait for manual testing
        print("\\n⏸  Press Enter after testing with curl...")
        _ = readLine()

        // 4. Stop port forwarding
        print("Stopping port forwarding...")
        try await service.stopPortForwarding(localPort: \(LOCAL_PORT))
        print("✅ Port forwarding stopped")

        // 5. Verify cleanup
        let active = await service.getActivePortForwardings()
        print("Active forwardings: \\(active.count)")

        // 6. Disconnect
        await service.disconnect()
        print("✅ Disconnected")

    } catch {
        print("❌ Error: \\(error)")
    }
}

// Run the test
Task {
    await testPortForwarding()
    exit(0)
}
RunLoop.main.run()
""")
print("")

print("=== Verification Complete ===")
print("")
print("To mark this subtask complete:")
print("1. Follow the manual verification steps above")
print("2. Verify all success criteria are met")
print("3. Document any issues in build-progress.txt")
print("4. Commit with: git commit -m 'auto-claude: subtask-7-4 - Verify port forwarding'")
print("5. Update implementation_plan.json status to 'completed'")
print("")
