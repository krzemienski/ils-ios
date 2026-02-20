import Foundation

// MARK: - Team Metrics Response

/// Comprehensive team performance metrics including agents, tasks, and efficiency.
public struct TeamMetricsResponse: Codable, Sendable {
    /// Team identifier.
    public let teamId: String
    /// Team name.
    public let teamName: String
    /// Agent statistics.
    public let agents: AgentStats
    /// Task completion statistics.
    public let tasks: TaskStats
    /// Performance metrics.
    public let performance: PerformanceMetrics
    /// Workload distribution across agents.
    public let workloadDistribution: [WorkloadDistribution]
    /// Timestamp of metrics snapshot.
    public let timestamp: Date

    public init(
        teamId: String,
        teamName: String,
        agents: AgentStats,
        tasks: TaskStats,
        performance: PerformanceMetrics,
        workloadDistribution: [WorkloadDistribution],
        timestamp: Date
    ) {
        self.teamId = teamId
        self.teamName = teamName
        self.agents = agents
        self.tasks = tasks
        self.performance = performance
        self.workloadDistribution = workloadDistribution
        self.timestamp = timestamp
    }

    /// Agent count and status statistics.
    public struct AgentStats: Codable, Sendable {
        /// Total number of agents in team.
        public let total: Int
        /// Currently active agents.
        public let active: Int
        /// Idle agents.
        public let idle: Int
        /// Agents with errors.
        public let errored: Int

        public init(total: Int, active: Int, idle: Int, errored: Int) {
            self.total = total
            self.active = active
            self.idle = idle
            self.errored = errored
        }
    }

    /// Task completion statistics.
    public struct TaskStats: Codable, Sendable {
        /// Total tasks assigned to team.
        public let total: Int
        /// Completed tasks.
        public let completed: Int
        /// Tasks in progress.
        public let inProgress: Int
        /// Pending tasks.
        public let pending: Int
        /// Failed tasks.
        public let failed: Int
        /// Success rate (0-100).
        public let successRate: Double

        public init(
            total: Int,
            completed: Int,
            inProgress: Int,
            pending: Int,
            failed: Int,
            successRate: Double
        ) {
            self.total = total
            self.completed = completed
            self.inProgress = inProgress
            self.pending = pending
            self.failed = failed
            self.successRate = successRate
        }
    }

    /// Performance and efficiency metrics.
    public struct PerformanceMetrics: Codable, Sendable {
        /// Average task completion time in seconds.
        public let averageCompletionTime: Double
        /// Average response time in milliseconds.
        public let averageResponseTime: Double
        /// Task throughput (tasks per hour).
        public let throughput: Double
        /// Team efficiency score (0-100).
        public let efficiencyScore: Double
        /// Collaboration score (0-100).
        public let collaborationScore: Double

        public init(
            averageCompletionTime: Double,
            averageResponseTime: Double,
            throughput: Double,
            efficiencyScore: Double,
            collaborationScore: Double
        ) {
            self.averageCompletionTime = averageCompletionTime
            self.averageResponseTime = averageResponseTime
            self.throughput = throughput
            self.efficiencyScore = efficiencyScore
            self.collaborationScore = collaborationScore
        }
    }

    /// Workload distribution for a single agent.
    public struct WorkloadDistribution: Codable, Sendable {
        /// Agent identifier.
        public let agentId: String
        /// Agent display name.
        public let agentName: String
        /// Number of assigned tasks.
        public let assignedTasks: Int
        /// Number of completed tasks.
        public let completedTasks: Int
        /// Workload percentage (0-100).
        public let workloadPercentage: Double
        /// Current utilization (0-100).
        public let utilization: Double

        public init(
            agentId: String,
            agentName: String,
            assignedTasks: Int,
            completedTasks: Int,
            workloadPercentage: Double,
            utilization: Double
        ) {
            self.agentId = agentId
            self.agentName = agentName
            self.assignedTasks = assignedTasks
            self.completedTasks = completedTasks
            self.workloadPercentage = workloadPercentage
            self.utilization = utilization
        }
    }
}

// MARK: - Agent Performance Response

/// Individual agent performance metrics.
public struct AgentPerformanceResponse: Codable, Sendable {
    /// Agent identifier.
    public let agentId: String
    /// Agent display name.
    public let agentName: String
    /// Agent role or specialization.
    public let role: String
    /// Current agent status.
    public let status: String
    /// Task statistics for this agent.
    public let taskStats: AgentTaskStats
    /// Performance metrics for this agent.
    public let performance: AgentPerformanceMetrics
    /// Recent activity timestamps.
    public let activity: AgentActivity

    public init(
        agentId: String,
        agentName: String,
        role: String,
        status: String,
        taskStats: AgentTaskStats,
        performance: AgentPerformanceMetrics,
        activity: AgentActivity
    ) {
        self.agentId = agentId
        self.agentName = agentName
        self.role = role
        self.status = status
        self.taskStats = taskStats
        self.performance = performance
        self.activity = activity
    }

    /// Task statistics for an individual agent.
    public struct AgentTaskStats: Codable, Sendable {
        /// Total tasks assigned.
        public let assigned: Int
        /// Tasks completed.
        public let completed: Int
        /// Tasks in progress.
        public let inProgress: Int
        /// Tasks failed.
        public let failed: Int
        /// Success rate (0-100).
        public let successRate: Double

        public init(assigned: Int, completed: Int, inProgress: Int, failed: Int, successRate: Double) {
            self.assigned = assigned
            self.completed = completed
            self.inProgress = inProgress
            self.failed = failed
            self.successRate = successRate
        }
    }

    /// Performance metrics for an individual agent.
    public struct AgentPerformanceMetrics: Codable, Sendable {
        /// Average task duration in seconds.
        public let averageTaskDuration: Double
        /// Average response latency in milliseconds.
        public let averageResponseLatency: Double
        /// Quality score (0-100).
        public let qualityScore: Double
        /// Reliability score (0-100).
        public let reliabilityScore: Double
        /// Collaboration rating (0-100).
        public let collaborationRating: Double

        public init(
            averageTaskDuration: Double,
            averageResponseLatency: Double,
            qualityScore: Double,
            reliabilityScore: Double,
            collaborationRating: Double
        ) {
            self.averageTaskDuration = averageTaskDuration
            self.averageResponseLatency = averageResponseLatency
            self.qualityScore = qualityScore
            self.reliabilityScore = reliabilityScore
            self.collaborationRating = collaborationRating
        }
    }

    /// Agent activity timestamps.
    public struct AgentActivity: Codable, Sendable {
        /// When agent was created.
        public let createdAt: Date
        /// Last task assignment time.
        public let lastAssignedAt: Date?
        /// Last task completion time.
        public let lastCompletedAt: Date?
        /// Last activity time.
        public let lastActiveAt: Date

        public init(createdAt: Date, lastAssignedAt: Date?, lastCompletedAt: Date?, lastActiveAt: Date) {
            self.createdAt = createdAt
            self.lastAssignedAt = lastAssignedAt
            self.lastCompletedAt = lastCompletedAt
            self.lastActiveAt = lastActiveAt
        }
    }
}

// MARK: - Team Performance Summary

/// High-level team performance summary for dashboard display.
public struct TeamPerformanceSummary: Codable, Sendable {
    /// Team identifier.
    public let teamId: String
    /// Team name.
    public let teamName: String
    /// Overall team health score (0-100).
    public let healthScore: Double
    /// Active agents count.
    public let activeAgents: Int
    /// Completed tasks count.
    public let completedTasks: Int
    /// Average task completion time in seconds.
    public let avgCompletionTime: Double
    /// Current team status.
    public let status: String
    /// Last update timestamp.
    public let lastUpdated: Date

    public init(
        teamId: String,
        teamName: String,
        healthScore: Double,
        activeAgents: Int,
        completedTasks: Int,
        avgCompletionTime: Double,
        status: String,
        lastUpdated: Date
    ) {
        self.teamId = teamId
        self.teamName = teamName
        self.healthScore = healthScore
        self.activeAgents = activeAgents
        self.completedTasks = completedTasks
        self.avgCompletionTime = avgCompletionTime
        self.status = status
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Time Series Metrics

/// Team metrics over time for charting and trend analysis.
public struct TeamMetricsTimeSeries: Codable, Sendable {
    /// Team identifier.
    public let teamId: String
    /// Time period covered.
    public let period: TimePeriod
    /// Data points in chronological order.
    public let dataPoints: [MetricDataPoint]

    public init(teamId: String, period: TimePeriod, dataPoints: [MetricDataPoint]) {
        self.teamId = teamId
        self.period = period
        self.dataPoints = dataPoints
    }

    /// Time period definition.
    public struct TimePeriod: Codable, Sendable {
        /// Period start time.
        public let startTime: Date
        /// Period end time.
        public let endTime: Date
        /// Granularity (hourly, daily, weekly).
        public let granularity: String

        public init(startTime: Date, endTime: Date, granularity: String) {
            self.startTime = startTime
            self.endTime = endTime
            self.granularity = granularity
        }
    }

    /// Single metric data point in time series.
    public struct MetricDataPoint: Codable, Sendable {
        /// Timestamp of this data point.
        public let timestamp: Date
        /// Tasks completed in this period.
        public let tasksCompleted: Int
        /// Average completion time in seconds.
        public let avgCompletionTime: Double
        /// Active agents count.
        public let activeAgents: Int
        /// Throughput (tasks per hour).
        public let throughput: Double
        /// Efficiency score (0-100).
        public let efficiencyScore: Double

        public init(
            timestamp: Date,
            tasksCompleted: Int,
            avgCompletionTime: Double,
            activeAgents: Int,
            throughput: Double,
            efficiencyScore: Double
        ) {
            self.timestamp = timestamp
            self.tasksCompleted = tasksCompleted
            self.avgCompletionTime = avgCompletionTime
            self.activeAgents = activeAgents
            self.throughput = throughput
            self.efficiencyScore = efficiencyScore
        }
    }
}
