#!/usr/bin/env swift

import Foundation

// Simple E2E verification script that tests backend integration
// This runs without Xcode to verify core functionality

// Configuration
let baseURL = "http://localhost:9999"
let timeout: TimeInterval = 10.0

struct VerificationResult {
    let name: String
    let passed: Bool
    let message: String
}

var results: [VerificationResult] = []

// MARK: - Test Functions

func testBackendHealth() async -> VerificationResult {
    print("1. Testing backend health endpoint...")

    guard let url = URL(string: "\(baseURL)/health") else {
        return VerificationResult(name: "Backend Health", passed: false, message: "Invalid URL")
    }

    do {
        let (_, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            return VerificationResult(name: "Backend Health", passed: false, message: "Invalid response")
        }

        if httpResponse.statusCode == 200 {
            return VerificationResult(name: "Backend Health", passed: true, message: "Backend is running on port 9999")
        } else {
            return VerificationResult(name: "Backend Health", passed: false, message: "Status code: \(httpResponse.statusCode)")
        }
    } catch {
        return VerificationResult(name: "Backend Health", passed: false, message: "Error: \(error.localizedDescription)")
    }
}

func testSessionsList() async -> VerificationResult {
    print("2. Testing sessions list endpoint...")

    guard let url = URL(string: "\(baseURL)/api/v1/sessions") else {
        return VerificationResult(name: "Sessions List", passed: false, message: "Invalid URL")
    }

    do {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            return VerificationResult(name: "Sessions List", passed: false, message: "Invalid response")
        }

        if httpResponse.statusCode == 200 {
            if let _ = try? JSONSerialization.jsonObject(with: data) {
                return VerificationResult(name: "Sessions List", passed: true, message: "Sessions endpoint working")
            } else {
                return VerificationResult(name: "Sessions List", passed: false, message: "Invalid JSON response")
            }
        } else {
            return VerificationResult(name: "Sessions List", passed: false, message: "Status code: \(httpResponse.statusCode)")
        }
    } catch {
        return VerificationResult(name: "Sessions List", passed: false, message: "Error: \(error.localizedDescription)")
    }
}

func testProjectsList() async -> VerificationResult {
    print("3. Testing projects list endpoint...")

    guard let url = URL(string: "\(baseURL)/api/v1/projects") else {
        return VerificationResult(name: "Projects List", passed: false, message: "Invalid URL")
    }

    do {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            return VerificationResult(name: "Projects List", passed: false, message: "Invalid response")
        }

        if httpResponse.statusCode == 200 {
            if let _ = try? JSONSerialization.jsonObject(with: data) {
                return VerificationResult(name: "Projects List", passed: true, message: "Projects endpoint working")
            } else {
                return VerificationResult(name: "Projects List", passed: false, message: "Invalid JSON response")
            }
        } else {
            return VerificationResult(name: "Projects List", passed: false, message: "Status code: \(httpResponse.statusCode)")
        }
    } catch {
        return VerificationResult(name: "Projects List", passed: false, message: "Error: \(error.localizedDescription)")
    }
}

func testSkillsList() async -> VerificationResult {
    print("4. Testing skills list endpoint...")

    guard let url = URL(string: "\(baseURL)/api/v1/skills") else {
        return VerificationResult(name: "Skills List", passed: false, message: "Invalid URL")
    }

    do {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            return VerificationResult(name: "Skills List", passed: false, message: "Invalid response")
        }

        if httpResponse.statusCode == 200 {
            if let _ = try? JSONSerialization.jsonObject(with: data) {
                return VerificationResult(name: "Skills List", passed: true, message: "Skills endpoint working")
            } else {
                return VerificationResult(name: "Skills List", passed: false, message: "Invalid JSON response")
            }
        } else {
            return VerificationResult(name: "Skills List", passed: false, message: "Status code: \(httpResponse.statusCode)")
        }
    } catch {
        return VerificationResult(name: "Skills List", passed: false, message: "Error: \(error.localizedDescription)")
    }
}

func testMCPServersList() async -> VerificationResult {
    print("5. Testing MCP servers list endpoint...")

    guard let url = URL(string: "\(baseURL)/api/v1/mcp") else {
        return VerificationResult(name: "MCP Servers List", passed: false, message: "Invalid URL")
    }

    do {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            return VerificationResult(name: "MCP Servers List", passed: false, message: "Invalid response")
        }

        if httpResponse.statusCode == 200 {
            if let _ = try? JSONSerialization.jsonObject(with: data) {
                return VerificationResult(name: "MCP Servers List", passed: true, message: "MCP endpoint working")
            } else {
                return VerificationResult(name: "MCP Servers List", passed: false, message: "Invalid JSON response")
            }
        } else {
            return VerificationResult(name: "MCP Servers List", passed: false, message: "Status code: \(httpResponse.statusCode)")
        }
    } catch {
        return VerificationResult(name: "MCP Servers List", passed: false, message: "Error: \(error.localizedDescription)")
    }
}

func verifyMacOSSourceFiles() -> VerificationResult {
    print("6. Verifying macOS source files exist...")

    let basePath = "/Users/nick/Desktop/ils-ios/ILSApp/ILSMacApp"
    let requiredFiles = [
        "\(basePath)/ILSMacApp.swift",
        "\(basePath)/AppDelegate.swift",
        "\(basePath)/Views/MacContentView.swift",
        "\(basePath)/Views/MacChatView.swift",
        "\(basePath)/Views/MacSessionsListView.swift",
        "\(basePath)/Managers/WindowManager.swift",
        "\(basePath)/Managers/NotificationManager.swift",
        "\(basePath)/TouchBar/ChatTouchBarProvider.swift",
    ]

    var missingFiles: [String] = []

    for filePath in requiredFiles {
        if !FileManager.default.fileExists(atPath: filePath) {
            missingFiles.append(filePath.replacingOccurrences(of: basePath + "/", with: ""))
        }
    }

    if missingFiles.isEmpty {
        return VerificationResult(name: "macOS Source Files", passed: true, message: "All \(requiredFiles.count) source files present")
    } else {
        return VerificationResult(name: "macOS Source Files", passed: false, message: "Missing: \(missingFiles.joined(separator: ", "))")
    }
}

// MARK: - Main Execution

print("=== ILS Backend Integration Verification ===\n")
print("Starting verification...\n")

// Run all tests using Task
let semaphore = DispatchSemaphore(value: 0)

Task {
    results.append(await testBackendHealth())
    results.append(await testSessionsList())
    results.append(await testProjectsList())
    results.append(await testSkillsList())
    results.append(await testMCPServersList())
    results.append(verifyMacOSSourceFiles())

    // Print summary
    print("\n=== Verification Results ===\n")

    let passed = results.filter { $0.passed }.count
    let total = results.count

    for result in results {
        let status = result.passed ? "✅ PASS" : "❌ FAIL"
        print("\(status) - \(result.name)")
        print("   \(result.message)")
    }

    print("\n=== Summary ===")
    print("Passed: \(passed)/\(total)")
    print("Success Rate: \(Int(Double(passed)/Double(total) * 100))%")

    if passed == total {
        print("\n🎉 All verification checks passed!")
        print("\nNext Steps:")
        print("1. The backend is fully operational")
        print("2. All macOS source files have been created")
        print("3. Manual Xcode integration needed to build the macOS app")
        print("4. See MACOS_TARGET_SETUP.md for integration instructions")
    } else {
        print("\n⚠️  Some checks failed. Please review the results above.")

        if results[0].passed == false {
            print("\nNote: If backend health check failed, start the backend:")
            print("  cd /Users/nick/Desktop/ils-ios && PORT=9999 swift run ILSBackend")
        }
    }

    semaphore.signal()
}

semaphore.wait()
