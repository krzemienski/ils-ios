import Foundation
import ILSShared

/// Actor that collects team performance metrics: agent stats, task completion, efficiency, and workload distribution.
///
/// Analyzes team data from TeamsFileService to generate comprehensive metrics including:
/// - Agent statistics (active, idle, errored)
/// - Task completion rates and success metrics
/// - Performance tracking (completion time, throughput, efficiency)
/// - Workload distribution across team members
/// - Time-series data for trend analysis
actor TeamMetricsService {
    private let fileService: TeamsFileService

    init(fileService: TeamsFileService) {
        self.fileService = fileService
    }

    // MARK: - Public API

    /// Get comprehensive metrics for a specific team.
    /// - Parameter teamName: Name of the team to analyze
    /// - Returns: Complete team metrics snapshot, or nil if team not found
    func getTeamMetrics(teamName: String) async throws -> TeamMetricsResponse? {
        guard let team = try await fileService.getTeam(name: teamName) else {
            return nil
        }

        let tasks = try await fileService.listTasks(team: teamName)
        let agents = team.members

        let agentStats = calculateAgentStats(members: agents)
        let taskStats = calculateTaskStats(tasks: tasks)
        let performance = calculatePerformance(tasks: tasks)
        let workload = calculateWorkloadDistribution(members: agents, tasks: tasks)

        return TeamMetricsResponse(
            teamId: team.name,
            teamName: team.name,
            agents: agentStats,
            tasks: taskStats,
            performance: performance,
            workloadDistribution: workload,
            timestamp: Date()
        )
    }

    /// Get performance metrics for a specific agent in a team.
    /// - Parameters:
    ///   - teamName: Name of the team
    ///   - agentName: Name of the agent to analyze
    /// - Returns: Agent-specific performance metrics, or nil if not found
    func getAgentPerformance(teamName: String, agentName: String) async throws -> AgentPerformanceResponse? {
        guard let team = try await fileService.getTeam(name: teamName) else {
            return nil
        }

        guard let member = team.members.first(where: { $0.name == agentName }) else {
            return nil
        }

        let tasks = try await fileService.listTasks(team: teamName)
        let agentTasks = tasks.filter { $0.owner == agentName }

        let taskStats = calculateAgentTaskStats(tasks: agentTasks)
        let performance = calculateAgentPerformance(tasks: agentTasks)
        let activity = calculateAgentActivity(member: member, tasks: agentTasks)

        return AgentPerformanceResponse(
            agentId: member.agentId ?? member.name,
            agentName: member.name,
            role: member.agentType ?? "agent",
            status: member.status?.rawValue ?? "idle",
            taskStats: taskStats,
            performance: performance,
            activity: activity
        )
    }

    /// Get high-level performance summary for a team (dashboard view).
    /// - Parameter teamName: Name of the team
    /// - Returns: Team performance summary, or nil if team not found
    func getTeamSummary(teamName: String) async throws -> TeamPerformanceSummary? {
        guard let team = try await fileService.getTeam(name: teamName) else {
            return nil
        }

        let tasks = try await fileService.listTasks(team: teamName)
        let members = team.members

        let activeAgents = members.filter { $0.status == .active }.count
        let completedTasks = tasks.filter { $0.status == .completed }.count

        let completedTasksWithTime = tasks.filter { $0.status == .completed }
        let avgCompletionTime = calculateAverageCompletionTime(tasks: completedTasksWithTime)

        let healthScore = calculateHealthScore(
            members: members,
            tasks: tasks,
            completedTasks: completedTasks
        )

        let status = determineTeamStatus(members: members, tasks: tasks)

        return TeamPerformanceSummary(
            teamId: team.name,
            teamName: team.name,
            healthScore: healthScore,
            activeAgents: activeAgents,
            completedTasks: completedTasks,
            avgCompletionTime: avgCompletionTime,
            status: status,
            lastUpdated: Date()
        )
    }

    /// Get time-series metrics for trend analysis.
    /// - Parameters:
    ///   - teamName: Name of the team
    ///   - startDate: Start of time range
    ///   - endDate: End of time range
    ///   - granularity: Data point granularity (hourly, daily, weekly)
    /// - Returns: Time-series metrics, or nil if team not found
    func getTimeSeries(
        teamName: String,
        startDate: Date,
        endDate: Date,
        granularity: String
    ) async throws -> TeamMetricsTimeSeries? {
        guard try await fileService.getTeam(name: teamName) != nil else {
            return nil
        }

        let tasks = try await fileService.listTasks(team: teamName)
        let dataPoints = generateTimeSeriesDataPoints(
            tasks: tasks,
            startDate: startDate,
            endDate: endDate,
            granularity: granularity
        )

        let period = TeamMetricsTimeSeries.TimePeriod(
            startTime: startDate,
            endTime: endDate,
            granularity: granularity
        )

        return TeamMetricsTimeSeries(
            teamId: teamName,
            period: period,
            dataPoints: dataPoints
        )
    }

    // MARK: - Private Helpers - Agent Stats

    private func calculateAgentStats(members: [TeamMember]) -> TeamMetricsResponse.AgentStats {
        let total = members.count
        let active = members.filter { $0.status == .active }.count
        let idle = members.filter { $0.status == .idle }.count
        let errored = 0 // Future: track errored state when implemented

        return TeamMetricsResponse.AgentStats(
            total: total,
            active: active,
            idle: idle,
            errored: errored
        )
    }

    // MARK: - Private Helpers - Task Stats

    private func calculateTaskStats(tasks: [TeamTask]) -> TeamMetricsResponse.TaskStats {
        let total = tasks.count
        let completed = tasks.filter { $0.status == .completed }.count
        let inProgress = tasks.filter { $0.status == .inProgress }.count
        let pending = tasks.filter { $0.status == .pending }.count
        let failed = 0 // Future: track failed tasks when status is added

        let successRate = total > 0 ? (Double(completed) / Double(total)) * 100.0 : 0.0

        return TeamMetricsResponse.TaskStats(
            total: total,
            completed: completed,
            inProgress: inProgress,
            pending: pending,
            failed: failed,
            successRate: successRate.rounded()
        )
    }

    private func calculateAgentTaskStats(tasks: [TeamTask]) -> AgentPerformanceResponse.AgentTaskStats {
        let assigned = tasks.count
        let completed = tasks.filter { $0.status == .completed }.count
        let inProgress = tasks.filter { $0.status == .inProgress }.count
        let failed = 0 // Future: track failed tasks

        let successRate = assigned > 0 ? (Double(completed) / Double(assigned)) * 100.0 : 0.0

        return AgentPerformanceResponse.AgentTaskStats(
            assigned: assigned,
            completed: completed,
            inProgress: inProgress,
            failed: failed,
            successRate: successRate.rounded()
        )
    }

    // MARK: - Private Helpers - Performance

    private func calculatePerformance(tasks: [TeamTask]) -> TeamMetricsResponse.PerformanceMetrics {
        let completedTasks = tasks.filter { $0.status == .completed }

        // Average completion time (simulated based on task count)
        let avgCompletionTime = calculateAverageCompletionTime(tasks: completedTasks)

        // Average response time (simulated, future: track actual response times)
        let avgResponseTime = 250.0 // ms

        // Throughput: tasks per hour (based on completed tasks)
        let throughput = calculateThroughput(completedTasks: completedTasks)

        // Efficiency score (0-100) based on completion rate and throughput
        let efficiencyScore = calculateEfficiencyScore(
            tasks: tasks,
            completedTasks: completedTasks,
            throughput: throughput
        )

        // Collaboration score based on task dependencies and shared work
        let collaborationScore = calculateCollaborationScore(tasks: tasks)

        return TeamMetricsResponse.PerformanceMetrics(
            averageCompletionTime: avgCompletionTime,
            averageResponseTime: avgResponseTime,
            throughput: throughput,
            efficiencyScore: efficiencyScore,
            collaborationScore: collaborationScore
        )
    }

    private func calculateAgentPerformance(tasks: [TeamTask]) -> AgentPerformanceResponse.AgentPerformanceMetrics {
        let completedTasks = tasks.filter { $0.status == .completed }

        let avgTaskDuration = calculateAverageCompletionTime(tasks: completedTasks)
        let avgResponseLatency = 200.0 // ms (simulated)

        // Quality score based on completion rate
        let qualityScore = tasks.count > 0 ? (Double(completedTasks.count) / Double(tasks.count)) * 100.0 : 100.0

        // Reliability score (high if no failed tasks)
        let reliabilityScore = 95.0 // Future: track actual failures

        // Collaboration rating based on task dependencies
        let collaborationRating = calculateCollaborationScore(tasks: tasks)

        return AgentPerformanceResponse.AgentPerformanceMetrics(
            averageTaskDuration: avgTaskDuration,
            averageResponseLatency: avgResponseLatency,
            qualityScore: qualityScore.rounded(),
            reliabilityScore: reliabilityScore,
            collaborationRating: collaborationRating
        )
    }

    private func calculateAverageCompletionTime(tasks: [TeamTask]) -> Double {
        guard !tasks.isEmpty else { return 0.0 }

        // Simulated: 120 seconds per task on average
        // Future: track actual start/end times
        return 120.0
    }

    private func calculateThroughput(completedTasks: [TeamTask]) -> Double {
        guard !completedTasks.isEmpty else { return 0.0 }

        // Simulated: assume tasks completed in last hour
        // Future: calculate based on actual completion timestamps
        let tasksPerHour = Double(completedTasks.count)
        return tasksPerHour.rounded(toPlaces: 1)
    }

    private func calculateEfficiencyScore(
        tasks: [TeamTask],
        completedTasks: [TeamTask],
        throughput: Double
    ) -> Double {
        guard !tasks.isEmpty else { return 0.0 }

        let completionRate = Double(completedTasks.count) / Double(tasks.count)
        let throughputFactor = min(throughput / 10.0, 1.0) // Normalize to 0-1

        let score = (completionRate * 0.7 + throughputFactor * 0.3) * 100.0
        return score.rounded()
    }

    private func calculateCollaborationScore(tasks: [TeamTask]) -> Double {
        guard !tasks.isEmpty else { return 0.0 }

        let tasksWithDependencies = tasks.filter { ($0.blockedBy?.count ?? 0) > 0 }.count
        let collaborationRatio = Double(tasksWithDependencies) / Double(tasks.count)

        // Score based on dependency usage (more dependencies = more collaboration)
        let score = (collaborationRatio * 0.5 + 0.5) * 100.0 // Minimum 50, max 100
        return score.rounded()
    }

    // MARK: - Private Helpers - Workload Distribution

    private func calculateWorkloadDistribution(
        members: [TeamMember],
        tasks: [TeamTask]
    ) -> [TeamMetricsResponse.WorkloadDistribution] {
        return members.map { member in
            let assignedTasks = tasks.filter { $0.owner == member.name }
            let completedTasks = assignedTasks.filter { $0.status == .completed }

            let totalTasks = tasks.count
            let workloadPercentage = totalTasks > 0 ? (Double(assignedTasks.count) / Double(totalTasks)) * 100.0 : 0.0

            // Utilization based on active status and task load
            let utilization = member.status == .active ? min(workloadPercentage * 1.2, 100.0) : 0.0

            return TeamMetricsResponse.WorkloadDistribution(
                agentId: member.agentId ?? member.name,
                agentName: member.name,
                assignedTasks: assignedTasks.count,
                completedTasks: completedTasks.count,
                workloadPercentage: workloadPercentage.rounded(toPlaces: 1),
                utilization: utilization.rounded(toPlaces: 1)
            )
        }
    }

    // MARK: - Private Helpers - Activity

    private func calculateAgentActivity(
        member: TeamMember,
        tasks: [TeamTask]
    ) -> AgentPerformanceResponse.AgentActivity {
        let createdAt = Date().addingTimeInterval(-86400) // Default: 1 day ago

        // Find last assigned and completed tasks (simulated)
        let lastAssignedAt = tasks.isEmpty ? nil : Date().addingTimeInterval(-3600)
        let completedTasks = tasks.filter { $0.status == .completed }
        let lastCompletedAt = completedTasks.isEmpty ? nil : Date().addingTimeInterval(-1800)

        let lastActiveAt = member.status == .active ? Date() : (lastAssignedAt ?? createdAt)

        return AgentPerformanceResponse.AgentActivity(
            createdAt: createdAt,
            lastAssignedAt: lastAssignedAt,
            lastCompletedAt: lastCompletedAt,
            lastActiveAt: lastActiveAt
        )
    }

    // MARK: - Private Helpers - Summary

    private func calculateHealthScore(
        members: [TeamMember],
        tasks: [TeamTask],
        completedTasks: Int
    ) -> Double {
        let activeRatio = members.isEmpty ? 0.0 : Double(members.filter { $0.status == .active }.count) / Double(members.count)
        let completionRatio = tasks.isEmpty ? 0.0 : Double(completedTasks) / Double(tasks.count)

        // Health score: 50% active agents, 50% task completion
        let score = (activeRatio * 0.5 + completionRatio * 0.5) * 100.0
        return score.rounded()
    }

    private func determineTeamStatus(members: [TeamMember], tasks: [TeamTask]) -> String {
        let activeMembers = members.filter { $0.status == .active }.count
        let inProgressTasks = tasks.filter { $0.status == .inProgress }.count

        if activeMembers > 0 && inProgressTasks > 0 {
            return "active"
        } else if activeMembers > 0 {
            return "idle"
        } else {
            return "inactive"
        }
    }

    // MARK: - Private Helpers - Time Series

    private func generateTimeSeriesDataPoints(
        tasks: [TeamTask],
        startDate: Date,
        endDate: Date,
        granularity: String
    ) -> [TeamMetricsTimeSeries.MetricDataPoint] {
        // Simulated time series data
        // Future: generate actual data points based on task completion timestamps

        let interval: TimeInterval
        switch granularity.lowercased() {
        case "hourly":
            interval = 3600
        case "daily":
            interval = 86400
        case "weekly":
            interval = 604800
        default:
            interval = 86400
        }

        var dataPoints: [TeamMetricsTimeSeries.MetricDataPoint] = []
        var currentDate = startDate

        while currentDate <= endDate {
            let completedTasks = tasks.filter { $0.status == .completed }
            let tasksCompleted = min(completedTasks.count, 5) // Simulated

            let dataPoint = TeamMetricsTimeSeries.MetricDataPoint(
                timestamp: currentDate,
                tasksCompleted: tasksCompleted,
                avgCompletionTime: 120.0,
                activeAgents: 3, // Simulated
                throughput: Double(tasksCompleted),
                efficiencyScore: 85.0 // Simulated
            )

            dataPoints.append(dataPoint)
            currentDate = currentDate.addingTimeInterval(interval)
        }

        return dataPoints
    }
}

// MARK: - Helper Extensions

private extension Double {
    func rounded(toPlaces places: Int = 0) -> Double {
        let divisor = Foundation.pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
