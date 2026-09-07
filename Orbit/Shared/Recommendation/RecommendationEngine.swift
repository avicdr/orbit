import Foundation

public struct RecommendationContext: Equatable, Sendable {
    public let now: Date
    public let availableMinutes: Int
    public let energyLevel: EnergyLevel?
    public let contextName: String?
    public let calendarIsAvailable: Bool

    public init(now: Date, availableMinutes: Int, energyLevel: EnergyLevel?, contextName: String? = nil, calendarIsAvailable: Bool = false) {
        self.now = now
        self.availableMinutes = max(0, availableMinutes)
        self.energyLevel = energyLevel
        self.contextName = contextName
        self.calendarIsAvailable = calendarIsAvailable
    }
}

public struct RecommendationTask: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let status: TaskStatus
    public let priority: TaskPriority
    public let dueDate: Date?
    public let estimatedMinutes: Int?
    public let energyRequirement: EnergyLevel?
    public let contextName: String?
    public let goalTitle: String?
    public let projectTitle: String?
    public let orbitTitle: String?
    public let orbitWeight: Double
    public let dependenciesComplete: Bool
    /// A normalized, locally computed optional signal from historical effort. Defaults to zero.
    public let historicalMomentum: Double

    public init(id: UUID = UUID(), title: String, status: TaskStatus = .planned, priority: TaskPriority = .normal, dueDate: Date? = nil, estimatedMinutes: Int? = nil, energyRequirement: EnergyLevel? = nil, contextName: String? = nil, goalTitle: String? = nil, projectTitle: String? = nil, orbitTitle: String? = nil, orbitWeight: Double = 1, dependenciesComplete: Bool = true, historicalMomentum: Double = 0) {
        self.id = id; self.title = title; self.status = status; self.priority = priority; self.dueDate = dueDate; self.estimatedMinutes = estimatedMinutes; self.energyRequirement = energyRequirement; self.contextName = contextName; self.goalTitle = goalTitle; self.projectTitle = projectTitle; self.orbitTitle = orbitTitle; self.orbitWeight = orbitWeight; self.dependenciesComplete = dependenciesComplete; self.historicalMomentum = min(max(historicalMomentum, 0), 1)
    }
}

public struct RecommendationScore: Equatable, Sendable {
    public let priority: Int
    public let urgency: Int
    public let goalWeight: Int
    public let contextMatch: Int
    public let energyMatch: Int
    public let timeFit: Int
    public let momentum: Int
    public let friction: Int
    public let normalized: Int
}

public struct RecommendedTask: Identifiable, Equatable, Sendable {
    public let task: RecommendationTask
    public let score: RecommendationScore
    public let explanation: [String]
    public var id: UUID { task.id }
}

public enum UnavailableTaskReason: String, Equatable, Sendable { case inbox, completed, cancelled, blocked }
public struct UnavailableTask: Equatable, Sendable { public let taskID: UUID; public let reason: UnavailableTaskReason }
public enum RecommendationEmptyReason: Equatable, Sendable { case noAvailableTime, noEligibleTasks }
public struct RecommendationResult: Equatable, Sendable {
    public let primary: RecommendedTask?
    public let alternatives: [RecommendedTask]
    public let unavailableTasks: [UnavailableTask]
    public let emptyReason: RecommendationEmptyReason?
}

/// Local scoring with fixed weights. The engine is deterministic, explainable, and UI-independent.
public struct RecommendationEngine: Sendable {
    public init() {}

    public func recommend(tasks: [RecommendationTask], context: RecommendationContext, maximumAlternatives: Int = 3) -> RecommendationResult {
        guard context.availableMinutes > 0 else {
            return RecommendationResult(primary: nil, alternatives: [], unavailableTasks: [], emptyReason: .noAvailableTime)
        }
        var unavailable: [UnavailableTask] = []
        let eligible = tasks.filter { task in
            switch task.status {
            case .inbox: unavailable.append(UnavailableTask(taskID: task.id, reason: .inbox)); return false
            case .completed: unavailable.append(UnavailableTask(taskID: task.id, reason: .completed)); return false
            case .cancelled: unavailable.append(UnavailableTask(taskID: task.id, reason: .cancelled)); return false
            case .planned, .inProgress:
                guard task.dependenciesComplete else { unavailable.append(UnavailableTask(taskID: task.id, reason: .blocked)); return false }
                return true
            }
        }
        let ranked = eligible.map { score($0, in: context) }.sorted(by: rankedBefore)
        return RecommendationResult(primary: ranked.first, alternatives: Array(ranked.dropFirst().prefix(max(0, maximumAlternatives))), unavailableTasks: unavailable, emptyReason: ranked.isEmpty ? .noEligibleTasks : nil)
    }

    private func score(_ task: RecommendationTask, in context: RecommendationContext) -> RecommendedTask {
        let priority = task.priority.rawValue * 8
        let urgency = urgencyPoints(task.dueDate, now: context.now)
        let goalWeight = Int(((min(max(task.orbitWeight, 0.5), 2) - 0.5) / 1.5 * 12).rounded())
        let contextResult = contextPoints(task.contextName, active: context.contextName)
        let energyResult = energyPoints(task.energyRequirement, active: context.energyLevel)
        let timeResult = timePoints(task.estimatedMinutes, available: context.availableMinutes)
        let momentum = Int((task.historicalMomentum * 5).rounded())
        let friction = (contextResult.isMismatch ? 6 : 0) + (energyResult.isMismatch ? 8 : 0) + (timeResult.isTooLong ? 6 : 0)
        let raw = priority + urgency + goalWeight + contextResult.points + energyResult.points + timeResult.points + momentum - friction
        let normalized = min(100, max(0, Int((Double(raw) / 107 * 100).rounded())))
        let score = RecommendationScore(priority: priority, urgency: urgency, goalWeight: goalWeight, contextMatch: contextResult.points, energyMatch: energyResult.points, timeFit: timeResult.points, momentum: momentum, friction: friction, normalized: normalized)
        return RecommendedTask(task: task, score: score, explanation: explanation(task, context: context, score: score, timeTooLong: timeResult.isTooLong))
    }

    private func urgencyPoints(_ dueDate: Date?, now: Date) -> Int {
        guard let dueDate else { return 0 }
        let hours = dueDate.timeIntervalSince(now) / 3600
        return switch hours { case ..<0: 24; case ...24: 21; case ...72: 14; case ...168: 7; default: 2 }
    }
    private func contextPoints(_ requirement: String?, active: String?) -> (points: Int, isMismatch: Bool) {
        guard let requirement, !requirement.isEmpty, requirement.lowercased() != "anywhere" else { return (6, false) }
        guard let active, !active.isEmpty else { return (3, false) }
        return requirement.localizedCaseInsensitiveCompare(active) == .orderedSame ? (12, false) : (0, true)
    }
    private func energyPoints(_ requirement: EnergyLevel?, active: EnergyLevel?) -> (points: Int, isMismatch: Bool) {
        guard let requirement else { return (6, false) }
        guard let active else { return (3, false) }
        return active >= requirement ? (12, false) : (0, true)
    }
    private func timePoints(_ estimate: Int?, available: Int) -> (points: Int, isTooLong: Bool) {
        guard let estimate, estimate > 0 else { return (4, false) }
        if estimate <= available { return (10, false) }
        if estimate <= Int(Double(available) * 1.25) { return (2, false) }
        return (0, true)
    }
    private func explanation(_ task: RecommendationTask, context: RecommendationContext, score: RecommendationScore, timeTooLong: Bool) -> [String] {
        var reasons: [String] = []
        if let estimate = task.estimatedMinutes, estimate <= context.availableMinutes { reasons.append("Fits your \(context.availableMinutes)-minute window") }
        if let requirement = task.energyRequirement, let energy = context.energyLevel, energy >= requirement { reasons.append("Matches your current energy") }
        if let goal = task.goalTitle { reasons.append("Supports your \(goal) goal") } else if let orbit = task.orbitTitle { reasons.append("Supports your \(orbit) orbit") }
        if let dueDate = task.dueDate, dueDate.timeIntervalSince(context.now) <= 24 * 60 * 60 { reasons.append(dueDate < context.now ? "Overdue" : "Due within a day") }
        if score.priority >= 24 { reasons.append("High priority") }
        if reasons.isEmpty { reasons.append(timeTooLong ? "Important, but longer than your current window" : "Available and ready to move forward") }
        return reasons
    }
    private func rankedBefore(_ lhs: RecommendedTask, _ rhs: RecommendedTask) -> Bool {
        if lhs.score.normalized != rhs.score.normalized { return lhs.score.normalized > rhs.score.normalized }
        if lhs.task.dueDate != rhs.task.dueDate { return (lhs.task.dueDate ?? .distantFuture) < (rhs.task.dueDate ?? .distantFuture) }
        if lhs.task.priority != rhs.task.priority { return lhs.task.priority > rhs.task.priority }
        return lhs.task.title.localizedCaseInsensitiveCompare(rhs.task.title) == .orderedAscending
    }
}

public enum RecommendationInputBuilder {
    public static func make(from task: OrbitTask, historicalMomentum: Double = 0) -> RecommendationTask {
        RecommendationTask(
            id: task.id, title: task.title, status: task.status, priority: task.priority, dueDate: task.dueDate,
            estimatedMinutes: task.estimatedDuration.map { Int($0 / 60) }, energyRequirement: task.energyRequirement,
            contextName: task.context?.name ?? task.locationRequirement, goalTitle: task.goal?.title, projectTitle: task.project?.title,
            orbitTitle: task.orbit?.name, orbitWeight: task.orbit?.weight ?? 1,
            dependenciesComplete: task.dependencies.allSatisfy { $0.status == .completed }, historicalMomentum: historicalMomentum
        )
    }
}
