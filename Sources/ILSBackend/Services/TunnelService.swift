import Foundation
import Dispatch

/// Actor managing Cloudflare tunnel processes.
///
/// Supports two modes:
/// - **Quick tunnel**: `cloudflared tunnel --url` — random trycloudflare.com URL
/// - **Named tunnel**: `cloudflared tunnel run --token <TOKEN>` — custom domain
actor TunnelService {
    // MARK: - State

    private var process: Process?
    private var tunnelURL: String?
    private var startTime: Date?
    private var outputPipe: Pipe?
    private var tunnelMode: TunnelMode = .quick

    /// Whether cloudflared binary is available on this machine.
    private(set) var cloudflaredInstalled: Bool = false

    // MARK: - Data Structures

    enum TunnelMode: Sendable {
        case quick
        case named(domain: String)
    }

    struct TunnelStatus: Sendable {
        let running: Bool
        let url: String?
        let uptime: Int?
        let mode: String
    }

    // MARK: - Lifecycle

    init() {
        self.cloudflaredInstalled = Self.checkCloudflaredInstalled()
    }

    // MARK: - Public API

    /// Start a quick Cloudflare tunnel forwarding to the given local port.
    /// Returns the public tunnel URL once parsed from cloudflared output.
    func start(port: Int = 9999) async throws -> String {
        // Already running?
        if let url = tunnelURL, process?.isRunning == true {
            return url
        }

        // Stop any zombie process
        stop()

        guard cloudflaredInstalled else {
            throw TunnelError.cloudflaredNotInstalled
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = ["cloudflared", "tunnel", "--url", "http://localhost:\(port)"]

        let pipe = Pipe()
        // cloudflared writes URL info to stderr, not stdout
        proc.standardError = pipe
        proc.standardOutput = Pipe() // discard stdout

        self.outputPipe = pipe
        self.process = proc

        // Handle unexpected termination
        proc.terminationHandler = { [weak self] _ in
            Task { [weak self] in
                await self?.handleTermination()
            }
        }

        try proc.run()
        self.startTime = Date()

        // Parse URL from output with 15-second timeout
        let url = try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try await self.parseURLFromOutput(pipe: pipe)
            }

            group.addTask {
                try await Task.sleep(nanoseconds: 15_000_000_000)
                throw TunnelError.timeout
            }

            guard let result = try await group.next() else {
                throw TunnelError.timeout
            }
            group.cancelAll()
            return result
        }

        self.tunnelURL = url
        return url
    }

    /// Start a named Cloudflare tunnel with a pre-configured token and custom domain.
    /// The domain is known upfront — no URL parsing needed.
    /// Requires the tunnel to be configured in Cloudflare dashboard with ingress rules.
    func startNamed(token: String, tunnelName: String, domain: String, port: Int = 9999) async throws -> String {
        // Already running?
        if let url = tunnelURL, process?.isRunning == true {
            return url
        }

        // Stop any zombie process
        stop()

        guard cloudflaredInstalled else {
            throw TunnelError.cloudflaredNotInstalled
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = ["cloudflared", "tunnel", "run", "--token", token]

        let pipe = Pipe()
        proc.standardError = pipe
        proc.standardOutput = Pipe()

        self.outputPipe = pipe
        self.process = proc
        self.tunnelMode = .named(domain: domain)

        proc.terminationHandler = { [weak self] _ in
            Task { [weak self] in
                await self?.handleTermination()
            }
        }

        try proc.run()
        self.startTime = Date()

        // For named tunnels the URL is the custom domain — no output parsing needed.
        // Wait briefly to verify cloudflared didn't crash immediately.
        let tunnelURL = domain.hasPrefix("https://") ? domain : "https://\(domain)"
        try await Task.sleep(nanoseconds: 3_000_000_000)

        guard process?.isRunning == true else {
            throw TunnelError.namedTunnelFailed
        }

        self.tunnelURL = tunnelURL
        return tunnelURL
    }

    /// Stop the running tunnel process.
    func stop() {
        if let proc = process, proc.isRunning {
            proc.terminate()
            proc.waitUntilExit()
        }
        clearState()
    }

    /// Current tunnel status.
    func status() -> TunnelStatus {
        let running = process?.isRunning == true
        let uptime: Int? = if running, let start = startTime {
            Int(Date().timeIntervalSince(start))
        } else {
            nil
        }
        let modeString: String = switch tunnelMode {
        case .quick: "quick"
        case .named: "named"
        }
        return TunnelStatus(
            running: running,
            url: running ? tunnelURL : nil,
            uptime: uptime,
            mode: modeString
        )
    }

    // MARK: - Private Helpers

    private static func checkCloudflaredInstalled() -> Bool {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = ["which", "cloudflared"]
        proc.standardOutput = Pipe()
        proc.standardError = Pipe()

        do {
            try proc.run()
            proc.waitUntilExit()
            return proc.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func parseURLFromOutput(pipe: Pipe) async throws -> String {
        let fileHandle = pipe.fileHandleForReading

        // Read in a background thread to avoid blocking
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var accumulated = ""

                while true {
                    let data = fileHandle.availableData
                    guard !data.isEmpty else { break }

                    guard let text = String(data: data, encoding: .utf8) else { continue }
                    accumulated += text

                    // cloudflared outputs a line like:
                    // | https://xxx-yyy-zzz.trycloudflare.com |
                    // or: INF +---...---+
                    // or: INF | https://....trycloudflare.com |
                    if let url = Self.extractTunnelURL(from: accumulated) {
                        continuation.resume(returning: url)
                        return
                    }
                }

                continuation.resume(throwing: TunnelError.urlNotFound)
            }
        }
    }

    /// Extract a trycloudflare.com URL from cloudflared output text.
    static func extractTunnelURL(from text: String) -> String? {
        // Match https://something.trycloudflare.com
        let pattern = #"(https://[a-zA-Z0-9\-]+\.trycloudflare\.com)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                  in: text,
                  range: NSRange(text.startIndex..., in: text)
              ),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range])
    }

    private func handleTermination() {
        // Process died unexpectedly — clear state
        clearState()
    }

    private func clearState() {
        process = nil
        tunnelURL = nil
        startTime = nil
        outputPipe = nil
        tunnelMode = .quick
    }

    // MARK: - Errors

    enum TunnelError: Error, CustomStringConvertible {
        case cloudflaredNotInstalled
        case timeout
        case urlNotFound
        case alreadyRunning
        case namedTunnelFailed

        var description: String {
            switch self {
            case .cloudflaredNotInstalled:
                return "cloudflared binary not found. Install from https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/"
            case .timeout:
                return "Timed out waiting for tunnel URL (15s)"
            case .urlNotFound:
                return "Could not parse tunnel URL from cloudflared output"
            case .alreadyRunning:
                return "Tunnel is already running"
            case .namedTunnelFailed:
                return "Named tunnel process exited unexpectedly. Check your token and tunnel configuration."
            }
        }
    }
}
