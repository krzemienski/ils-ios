import Foundation
import ILSShared

/// Actor responsible for spawning and managing Claude CLI teammate processes
actor TeamsExecutorService {

    // MARK: - Properties

    /// Nested dictionary: teamName -> memberName -> Process
    private var activeProcesses: [String: [String: Process]] = [:]

    // MARK: - Spawn Teammate

    /// Spawns a new Claude CLI teammate process
    /// - Parameters:
    ///   - teamName: The team this member belongs to
    ///   - name: Unique name for this teammate
    ///   - agentType: Optional agent type (e.g., "oh-my-claudecode:executor")
    ///   - model: Optional model to use (e.g., "sonnet", "opus", "haiku")
    ///   - prompt: Optional prompt to execute
    /// - Returns: TeamMember with the spawned process details
    /// - Throws: If process creation fails
    func spawnTeammate(
        teamName: String,
        name: String,
        agentType: String?,
        model: String?,
        prompt: String?
    ) throws -> TeamMember {
        let process = Process()

        // Set up Claude CLI command
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")

        var args = ["claude"]

        // Add agent type if provided
        if let agentType = agentType {
            args.append(contentsOf: ["--agent", agentType])
        }

        // Add model if provided
        if let model = model {
            args.append(contentsOf: ["--model", model])
        }

        // Add prompt if provided
        if let prompt = prompt {
            args.append(contentsOf: ["-p", prompt])
        }

        process.arguments = args

        // Set up environment with team flag
        var environment = ProcessInfo.processInfo.environment
        environment["CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"] = "1"
        process.environment = environment

        // Pipe output to /dev/null (we don't need to capture it)
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        // Launch the process
        try process.run()

        // Track the process
        if activeProcesses[teamName] == nil {
            activeProcesses[teamName] = [:]
        }
        activeProcesses[teamName]?[name] = process

        // Create and return TeamMember
        let member = TeamMember(
            name: name,
            agentType: agentType ?? "general",
            status: .active,
            pid: Int(process.processIdentifier)
        )

        return member
    }

    // MARK: - Shutdown Teammate

    /// Gracefully shuts down a teammate process (SIGTERM, then SIGKILL after 5s)
    /// - Parameters:
    ///   - teamName: The team name
    ///   - memberName: The member name to shutdown
    func shutdownTeammate(teamName: String, memberName: String) {
        guard let process = activeProcesses[teamName]?[memberName] else {
            return
        }

        // Send SIGTERM
        process.terminate()

        let pid = process.processIdentifier

        // Spawn a detached task to send SIGKILL after 5 seconds if still running
        Task.detached {
            try? await Task.sleep(nanoseconds: 5_000_000_000)

            // Check if process is still running
            if process.isRunning {
                kill(pid, SIGKILL)
            }
        }

        // Remove from tracking
        activeProcesses[teamName]?.removeValue(forKey: memberName)

        // Clean up empty team entry
        if activeProcesses[teamName]?.isEmpty == true {
            activeProcesses.removeValue(forKey: teamName)
        }
    }

    // MARK: - Shutdown All

    /// Shuts down all teammates for a given team
    /// - Parameter teamName: The team to shutdown
    func shutdownAll(teamName: String) {
        guard let members = activeProcesses[teamName] else {
            return
        }

        // Shutdown each member
        for memberName in members.keys {
            shutdownTeammate(teamName: teamName, memberName: memberName)
        }

        // Remove team entry
        activeProcesses.removeValue(forKey: teamName)
    }

    // MARK: - Status Checks

    /// Gets the current status of a specific teammate
    /// - Parameters:
    ///   - teamName: The team name
    ///   - memberName: The member name
    /// - Returns: Current TeamMemberStatus
    func getMemberStatus(teamName: String, memberName: String) -> TeamMemberStatus {
        guard let process = activeProcesses[teamName]?[memberName] else {
            return .shutdown
        }

        // Check if process is still running
        if process.isRunning {
            return .active
        } else {
            // Clean up terminated process
            activeProcesses[teamName]?.removeValue(forKey: memberName)
            if activeProcesses[teamName]?.isEmpty == true {
                activeProcesses.removeValue(forKey: teamName)
            }
            return .shutdown
        }
    }

    /// Gets all active members for a team with their current status
    /// - Parameter teamName: The team name
    /// - Returns: Array of TeamMember objects with current status
    func getActiveMembers(teamName: String) -> [TeamMember] {
        guard let members = activeProcesses[teamName] else {
            return []
        }

        var activeMembers: [TeamMember] = []
        var toRemove: [String] = []

        for (memberName, process) in members {
            let status: TeamMemberStatus = process.isRunning ? .active : .shutdown

            if status == .shutdown {
                toRemove.append(memberName)
            }

            let member = TeamMember(
                name: memberName,
                agentType: "unknown", // We don't store agentType, could enhance if needed
                status: status,
                pid: Int(process.processIdentifier)
            )

            activeMembers.append(member)
        }

        // Clean up terminated processes
        for memberName in toRemove {
            activeProcesses[teamName]?.removeValue(forKey: memberName)
        }

        if activeProcesses[teamName]?.isEmpty == true {
            activeProcesses.removeValue(forKey: teamName)
        }

        return activeMembers
    }
}
