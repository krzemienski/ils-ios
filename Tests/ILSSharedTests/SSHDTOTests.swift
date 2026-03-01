import Testing
import Foundation
@testable import ILSShared

// MARK: - SSHConnectRequest Tests

@Suite("SSHConnectRequest")
struct SSHConnectRequestTests {

    @Test("Default values: port=22, agentForwarding=false, jumpHost=nil")
    func defaultValues() {
        let req = SSHConnectRequest(
            host: "example.com",
            username: "alice",
            authMethod: "password",
            credential: "secret"
        )
        #expect(req.host == "example.com")
        #expect(req.port == 22)
        #expect(req.username == "alice")
        #expect(req.authMethod == "password")
        #expect(req.credential == "secret")
        #expect(req.agentForwarding == false)
        #expect(req.jumpHost == nil)
    }

    @Test("agentForwarding=true is stored correctly")
    func agentForwardingTrue() {
        let req = SSHConnectRequest(
            host: "example.com",
            port: 2222,
            username: "bob",
            authMethod: "privateKey",
            credential: "key-data",
            agentForwarding: true
        )
        #expect(req.agentForwarding == true)
        #expect(req.port == 2222)
    }

    @Test("SSHConnectRequest with jumpHost set")
    func withJumpHost() {
        let jump = SSHJumpHost(
            host: "bastion.example.com",
            port: 22,
            username: "jumpuser",
            authMethod: "password",
            credential: "jumppass"
        )
        let req = SSHConnectRequest(
            host: "internal.example.com",
            username: "alice",
            authMethod: "password",
            credential: "secret",
            jumpHost: jump
        )
        #expect(req.jumpHost != nil)
        #expect(req.jumpHost?.host == "bastion.example.com")
        #expect(req.jumpHost?.port == 22)
        #expect(req.jumpHost?.username == "jumpuser")
    }

    @Test("SSHConnectRequest Codable round-trip")
    func codableRoundTrip() throws {
        let jump = SSHJumpHost(
            host: "bastion.example.com",
            port: 2022,
            username: "jumpuser",
            authMethod: "privateKey",
            credential: "jump-key"
        )
        let original = SSHConnectRequest(
            host: "target.example.com",
            port: 2222,
            username: "alice",
            authMethod: "privateKey",
            credential: "target-key",
            agentForwarding: true,
            jumpHost: jump
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SSHConnectRequest.self, from: data)

        #expect(decoded.host == original.host)
        #expect(decoded.port == original.port)
        #expect(decoded.username == original.username)
        #expect(decoded.authMethod == original.authMethod)
        #expect(decoded.credential == original.credential)
        #expect(decoded.agentForwarding == original.agentForwarding)
        #expect(decoded.jumpHost?.host == jump.host)
        #expect(decoded.jumpHost?.port == jump.port)
        #expect(decoded.jumpHost?.username == jump.username)
    }
}

// MARK: - SSHPortForwardRequest Tests

@Suite("SSHPortForwardRequest")
struct SSHPortForwardRequestTests {

    @Test("SSHPortForwardRequest Codable round-trip")
    func codableRoundTrip() throws {
        let original = SSHPortForwardRequest(
            localPort: 9999,
            remoteHost: "localhost",
            remotePort: 8080
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SSHPortForwardRequest.self, from: data)

        #expect(decoded.localPort == original.localPort)
        #expect(decoded.remoteHost == original.remoteHost)
        #expect(decoded.remotePort == original.remotePort)
    }

    @Test("SSHStopPortForwardRequest Codable round-trip")
    func stopRequestRoundTrip() throws {
        let original = SSHStopPortForwardRequest(localPort: 9999)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SSHStopPortForwardRequest.self, from: data)
        #expect(decoded.localPort == original.localPort)
    }

    @Test("SSHPortForwardInfo stores all fields")
    func portForwardInfo() throws {
        let info = SSHPortForwardInfo(
            localPort: 9999,
            remoteHost: "internal.host",
            remotePort: 8080,
            serverUrl: "http://localhost:9999"
        )
        #expect(info.localPort == 9999)
        #expect(info.remoteHost == "internal.host")
        #expect(info.remotePort == 8080)
        #expect(info.serverUrl == "http://localhost:9999")
    }

    @Test("SSHPortForwardStatusResponse Codable round-trip")
    func statusResponseRoundTrip() throws {
        let original = SSHPortForwardStatusResponse(forwardings: [
            SSHPortForwardInfo(localPort: 9000, remoteHost: "localhost", remotePort: 9000, serverUrl: "http://localhost:9000"),
            SSHPortForwardInfo(localPort: 9001, remoteHost: "internal", remotePort: 8080, serverUrl: "http://localhost:9001"),
        ])

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SSHPortForwardStatusResponse.self, from: data)

        #expect(decoded.forwardings.count == 2)
        #expect(decoded.forwardings[0].localPort == 9000)
        #expect(decoded.forwardings[1].localPort == 9001)
        #expect(decoded.forwardings[1].remoteHost == "internal")
    }
}

// MARK: - SSHStatusResponse Tests

@Suite("SSHStatusResponse")
struct SSHStatusResponseTests {

    @Test("SSHStatusResponse Codable round-trip (disconnected)")
    func disconnectedRoundTrip() throws {
        let original = SSHStatusResponse(connected: false)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SSHStatusResponse.self, from: data)

        #expect(decoded.connected == false)
        #expect(decoded.host == nil)
        #expect(decoded.username == nil)
        #expect(decoded.platform == nil)
        #expect(decoded.connectedAt == nil)
        #expect(decoded.uptime == nil)
    }

    @Test("SSHStatusResponse Codable round-trip (connected)")
    func connectedRoundTrip() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let original = SSHStatusResponse(
            connected: true,
            host: "prod.example.com",
            username: "deploy",
            platform: "Linux",
            connectedAt: now,
            uptime: 3600.0
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SSHStatusResponse.self, from: data)

        #expect(decoded.connected == true)
        #expect(decoded.host == "prod.example.com")
        #expect(decoded.username == "deploy")
        #expect(decoded.platform == "Linux")
        #expect(decoded.uptime == 3600.0)
    }
}

// MARK: - SSHJumpHost Tests

@Suite("SSHJumpHost")
struct SSHJumpHostTests {

    @Test("SSHJumpHost default port is 22")
    func defaultPort() {
        let jump = SSHJumpHost(
            host: "bastion.example.com",
            username: "admin",
            authMethod: "password",
            credential: "pass"
        )
        #expect(jump.port == 22)
    }

    @Test("SSHJumpHost Codable round-trip")
    func codableRoundTrip() throws {
        let original = SSHJumpHost(
            host: "bastion.example.com",
            port: 2222,
            username: "admin",
            authMethod: "privateKey",
            credential: "ssh-key-data"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SSHJumpHost.self, from: data)

        #expect(decoded.host == original.host)
        #expect(decoded.port == original.port)
        #expect(decoded.username == original.username)
        #expect(decoded.authMethod == original.authMethod)
        #expect(decoded.credential == original.credential)
    }
}

// MARK: - ServerConnection Tests

@Suite("ServerConnection")
struct ServerConnectionTests {

    @Test("ServerConnection default agentForwarding is false")
    func defaultAgentForwarding() {
        let conn = ServerConnection(
            host: "example.com",
            username: "alice",
            authMethod: .password
        )
        #expect(conn.agentForwarding == false)
        #expect(conn.jumpHost == nil)
    }

    @Test("ServerConnection with agentForwarding=true")
    func agentForwardingEnabled() {
        let conn = ServerConnection(
            host: "example.com",
            username: "alice",
            authMethod: .sshKey,
            agentForwarding: true
        )
        #expect(conn.agentForwarding == true)
    }

    @Test("ServerConnection with jumpHost set")
    func withJumpHost() {
        let jumpConn = ServerConnection(
            host: "bastion.example.com",
            username: "jumpuser",
            authMethod: .password
        )
        let conn = ServerConnection(
            host: "internal.example.com",
            username: "alice",
            authMethod: .sshKey,
            jumpHost: ServerConnectionBox(jumpConn)
        )
        #expect(conn.jumpHost != nil)
        #expect(conn.jumpHost?.connection.host == "bastion.example.com")
        #expect(conn.jumpHost?.connection.username == "jumpuser")
    }

    @Test("ServerConnection Codable round-trip with agentForwarding and jumpHost")
    func codableRoundTrip() throws {
        let jumpConn = ServerConnection(
            host: "bastion.example.com",
            port: 22,
            username: "jumpuser",
            authMethod: .password
        )
        let original = ServerConnection(
            host: "internal.example.com",
            port: 2222,
            username: "alice",
            authMethod: .sshKey,
            label: "My Server",
            agentForwarding: true,
            jumpHost: ServerConnectionBox(jumpConn)
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ServerConnection.self, from: data)

        #expect(decoded.host == original.host)
        #expect(decoded.port == original.port)
        #expect(decoded.username == original.username)
        #expect(decoded.authMethod == original.authMethod)
        #expect(decoded.label == original.label)
        #expect(decoded.agentForwarding == true)
        #expect(decoded.jumpHost?.connection.host == "bastion.example.com")
    }
}
