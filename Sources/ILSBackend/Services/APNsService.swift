import Foundation
import Vapor
#if canImport(CryptoKit)
import CryptoKit
#endif

/// Service for sending Apple Push Notification service (APNs) payloads to iOS Live Activities.
///
/// ## Overview
/// When the iOS app is backgrounded, the SSE connection for real-time streaming is
/// unavailable. This service sends Live Activity content-state updates via APNs so
/// the Dynamic Island and Lock Screen widget stay current.
///
/// ## Configuration
/// Set the following environment variables on the ILS backend server:
///
/// | Variable            | Description                                                |
/// |---------------------|------------------------------------------------------------|
/// | `APNS_TEAM_ID`      | Your 10-character Apple Developer Team ID                  |
/// | `APNS_KEY_ID`       | The 10-character Key ID of your APNs Authentication Key    |
/// | `APNS_P8_KEY`       | The full content of your .p8 key file (including headers)  |
/// | `APNS_ENVIRONMENT`  | `"production"` or `"sandbox"` (default: `"sandbox"`)       |
///
/// The .p8 key can be obtained from https://developer.apple.com/account/resources/authkeys/list
/// — create an APNs key if you do not have one. Store the contents as a multiline env var.
///
/// ## APNs Live Activity Push Format
/// The payload uses `apns-push-type: liveactivity` and the topic
/// `com.ils.app.push-type.liveactivity`.
///
/// Content-state keys must match `ChatStreamingAttributes.ContentState` exactly
/// as that is what ActivityKit decodes on the device.
struct APNsService: Sendable {

    static let shared = APNsService()

    /// Live Activity APNs topic: `<bundle_id>.push-type.liveactivity`
    private let topic = "com.ils.app.push-type.liveactivity"

    private let teamId: String?
    private let keyId: String?
    private let p8KeyPEM: String?
    private let useSandbox: Bool

    private init() {
        teamId = Environment.get("APNS_TEAM_ID")
        keyId = Environment.get("APNS_KEY_ID")
        p8KeyPEM = Environment.get("APNS_P8_KEY")
        useSandbox = Environment.get("APNS_ENVIRONMENT") != "production"
    }

    /// `true` when all required env vars are set and APNs pushes can be sent.
    var isConfigured: Bool {
        guard let t = teamId, !t.isEmpty,
              let k = keyId, !k.isEmpty,
              let p = p8KeyPEM, !p.isEmpty else { return false }
        return true
    }

    // MARK: - Public API

    /// Send a Live Activity content-state update to an iOS device.
    ///
    /// - Parameters:
    ///   - pushToken: Hex-encoded APNs device push token for the Live Activity
    ///   - contentState: Encoded content state to deliver
    ///   - event: `"update"` to change content, `"end"` to dismiss the activity
    ///   - logger: Vapor logger for diagnostics
    func sendUpdate(
        to pushToken: String,
        contentState: LiveActivityContentStatePayload,
        event: LiveActivityEvent = .update,
        logger: Logger
    ) async {
        guard isConfigured else {
            logger.debug("[APNs] Not configured — skipping Live Activity push (set APNS_TEAM_ID, APNS_KEY_ID, APNS_P8_KEY)")
            return
        }

        do {
            let jwt = try makeJWT()
            let payload = makePushPayload(contentState: contentState, event: event)
            try await sendAPNsRequest(pushToken: pushToken, jwt: jwt, payload: payload, logger: logger)
        } catch {
            logger.warning("[APNs] Failed to send Live Activity push: \(error)")
        }
    }

    // MARK: - Payload Types

    /// Live Activity APNs event type.
    enum LiveActivityEvent: String {
        /// Update content state (activity remains visible).
        case update
        /// End the activity with a final content state.
        case end
    }

    /// The `content-state` dictionary sent in the APNs payload.
    ///
    /// Keys must match `ChatStreamingAttributes.ContentState` (snake_case via CodingKeys).
    struct LiveActivityContentStatePayload: Encodable {
        let status: String
        let messagePreview: String
        let tokenCount: Int
        let cost: Double
        let elapsedSeconds: Int
    }

    // MARK: - Private Helpers

    private struct APNsPayload: Encodable {
        struct APS: Encodable {
            let timestamp: Int
            let event: String
            let contentState: LiveActivityContentStatePayload
            let dismissalDate: Int?

            private enum CodingKeys: String, CodingKey {
                case timestamp
                case event
                case contentState = "content-state"
                case dismissalDate = "dismissal-date"
            }
        }
        let aps: APS
    }

    private func makePushPayload(
        contentState: LiveActivityContentStatePayload,
        event: LiveActivityEvent
    ) -> APNsPayload {
        let now = Int(Date().timeIntervalSince1970)
        // For "end" events, set a dismissal date 30 seconds in the future
        // so the user can see the final state before it disappears.
        let dismissalDate = event == .end ? now + 30 : nil
        return APNsPayload(
            aps: .init(
                timestamp: now,
                event: event.rawValue,
                contentState: contentState,
                dismissalDate: dismissalDate
            )
        )
    }

    private func makeJWT() throws -> String {
        guard let teamId, let keyId, let p8KeyPEM else {
            throw APNsError.missingConfiguration
        }

        let now = Int(Date().timeIntervalSince1970)
        let headerJSON = #"{"alg":"ES256","kid":"\#(keyId)"}"#
        let payloadJSON = #"{"iss":"\#(teamId)","iat":\#(now)}"#

        let headerB64 = Data(headerJSON.utf8).base64URLEncoded()
        let payloadB64 = Data(payloadJSON.utf8).base64URLEncoded()
        let message = "\(headerB64).\(payloadB64)"

        #if canImport(CryptoKit)
        let privateKey = try P256.Signing.PrivateKey(pemRepresentation: p8KeyPEM)
        let signature = try privateKey.signature(for: Data(message.utf8))
        let signatureB64 = signature.rawRepresentation.base64URLEncoded()
        return "\(message).\(signatureB64)"
        #else
        throw APNsError.cryptoKitUnavailable
        #endif
    }

    private func sendAPNsRequest(
        pushToken: String,
        jwt: String,
        payload: APNsPayload,
        logger: Logger
    ) async throws {
        let host = useSandbox ? "api.sandbox.push.apple.com" : "api.push.apple.com"
        let urlString = "https://\(host)/3/device/\(pushToken)"
        guard let url = URL(string: urlString) else {
            throw APNsError.invalidURL(urlString)
        }

        let encoder = JSONEncoder()
        // Use camelCase for content-state keys (ActivityKit decodes camelCase Swift property names)
        encoder.keyEncodingStrategy = .useDefaultKeys
        let bodyData = try encoder.encode(payload)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("bearer \(jwt)", forHTTPHeaderField: "authorization")
        request.setValue("liveactivity", forHTTPHeaderField: "apns-push-type")
        request.setValue(topic, forHTTPHeaderField: "apns-topic")
        // Expire immediately if delivery is delayed (real-time updates lose value quickly)
        request.setValue("0", forHTTPHeaderField: "apns-expiration")

        let (_, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 200 {
                logger.debug("[APNs] Live Activity push sent successfully")
            } else {
                logger.warning("[APNs] Live Activity push returned HTTP \(httpResponse.statusCode)")
            }
        }
    }

    // MARK: - Errors

    enum APNsError: Error, LocalizedError {
        case missingConfiguration
        case cryptoKitUnavailable
        case invalidURL(String)

        var errorDescription: String? {
            switch self {
            case .missingConfiguration:
                return "APNs not configured — set APNS_TEAM_ID, APNS_KEY_ID, and APNS_P8_KEY"
            case .cryptoKitUnavailable:
                return "CryptoKit not available on this platform"
            case .invalidURL(let url):
                return "Invalid APNs URL: \(url)"
            }
        }
    }
}

// MARK: - Data+Base64URL

private extension Data {
    /// Base64URL encoding (RFC 4648 §5): substitutes `+`→`-`, `/`→`_`, strips `=` padding.
    func base64URLEncoded() -> String {
        return base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
