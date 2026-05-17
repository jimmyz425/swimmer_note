import Foundation

// MARK: - Plan Type Enum

public enum PlanType: String, CaseIterable, Identifiable, Codable {
    case mixed = "Mixed Training"
    case recovery = "Recovery Week"
    case endurance = "Endurance Focus"
    case technique = "Technique Focus"
    case dryLandOnly = "Dry Land Only"
    case racePrep = "Race Prep"
    case speed = "Speed & Sprint"
    // Macrocycle phases (Silver+ only)
    case generalPrep = "General Preparation"
    case specificPrep = "Specific Preparation"
    case preCompetition = "Pre-Competition"
    case competition = "Competition Phase"
    case taper = "Taper"

    public var id: String { rawValue }

    /// Whether this plan type requires advanced tier (Silver+)
    public var requiresAdvancedTier: Bool {
        switch self {
        case .generalPrep, .specificPrep, .preCompetition, .competition, .taper:
            return true
        default:
            return false
        }
    }

    public var description: String {
        switch self {
        case .mixed: "Balanced club training"
        case .recovery: "Active recovery, light technique"
        case .endurance: "Distance and stamina building"
        case .technique: "Low intensity, high quality"
        case .dryLandOnly: "No pool sessions"
        case .racePrep: "Competition readiness"
        case .speed: "Sprint and pace work"
        case .generalPrep: "Base building (Zone 1-2 focus)"
        case .specificPrep: "Threshold development phase"
        case .preCompetition: "Sharpening, race-pace specificity"
        case .competition: "Meet season, high quality"
        case .taper: "10-21 days before major meet"
        }
    }

    public var icon: String {
        switch self {
        case .mixed: "figure.pool.swim"
        case .recovery: "moon"
        case .endurance: "heart"
        case .technique: "figure.pool.swim"
        case .dryLandOnly: "figure.strengthtraining.traditional"
        case .racePrep: "flag"
        case .speed: "bolt"
        case .generalPrep: "chart.line.uptrend.xyaxis"
        case .specificPrep: "flame"
        case .preCompetition: "trophy"
        case .competition: "medal"
        case .taper: "sparkles"
        }
    }
}

// MARK: - Plan Context

public struct PlanContext: Sendable {
    public let profile: UserProfile?
    public let notes: [TrainingNote]
    public let pastSessions: [String]  // Individual session summaries from past plans within 2-week window
    public let pastTechniqueSections: [String]  // Key focus and common mistakes from technique files used in past sessions
    public let targetWeek: Date?  // Week starting date for the new plan
    public let poolType: PoolType
    public let sessionsPerWeek: Int  // Usually profile `weeklySessionTarget` from buildPlanContext; 0 falls back in prompts via `effectiveWeeklySessionCount`
    public let strokeBalance: [StrokeBalanceInfo]
    public let goalProgress: GoalProgressInfo
    /// Coaching style option ids from swimming-coach-role-reference.md (user multi-select in planner).
    public let selectedCoachingStyleIDs: Set<String>

    public init(
        profile: UserProfile?,
        notes: [TrainingNote],
        pastSessions: [String] = [],
        pastTechniqueSections: [String] = [],
        targetWeek: Date? = nil,
        poolType: PoolType,
        sessionsPerWeek: Int = 0,  // Prefer profile weeklySessionTarget when building PlanContext
        strokeBalance: [StrokeBalanceInfo],
        goalProgress: GoalProgressInfo,
        selectedCoachingStyleIDs: Set<String> = []
    ) {
        self.profile = profile
        self.notes = notes
        self.pastSessions = pastSessions
        self.pastTechniqueSections = pastTechniqueSections
        self.targetWeek = targetWeek
        self.poolType = poolType
        self.sessionsPerWeek = sessionsPerWeek
        self.strokeBalance = strokeBalance
        self.goalProgress = goalProgress
        self.selectedCoachingStyleIDs = selectedCoachingStyleIDs
    }
}

public struct StrokeBalanceInfo: Sendable {
    public let stroke: String
    public let sessions: Int
    public let percentage: Int

    public init(stroke: String, sessions: Int, percentage: Int) {
        self.stroke = stroke
        self.sessions = sessions
        self.percentage = percentage
    }
}

public struct GoalProgressInfo: Sendable {
    public let achieved: [GoalSummary]
    public let struggling: [GoalSummary]
    public let inProgress: [GoalSummary]

    public init(achieved: [GoalSummary], struggling: [GoalSummary], inProgress: [GoalSummary]) {
        self.achieved = achieved
        self.struggling = struggling
        self.inProgress = inProgress
    }
}

public struct GoalSummary: Sendable {
    public let stroke: String?
    public let description: String

    public init(stroke: String?, description: String) {
        self.stroke = stroke
        self.description = description
    }
}

// MARK: - Strategy Protocol

public protocol PlanGenerationStrategy: Sendable {
    var planType: PlanType { get }

    func buildSystemRole() -> String
    func buildUserPrompt(context: PlanContext) -> String
    func buildOutlinePrompt(context: PlanContext) -> String  // Phase 1: Rough outline
    func buildDetailPrompt(sessionOutline: SessionOutline, weeklyOutline: WeeklyPlanOutline, context: PlanContext) -> String  // Phase 2: Detailed session
    func buildDryLandPrompt(outline: WeeklyPlanOutline, context: PlanContext) -> String  // Phase 3: Weekly dryland
    func guidanceFiles() -> [String]
    func coachingRules() -> String
}

// MARK: - Default Two-Phase Implementations

extension PlanGenerationStrategy {
    /// Default Phase 1 prompt - rough weekly outline
    public func buildOutlinePrompt(context: PlanContext) -> String {
        return buildDefaultOutlinePrompt(context, planType: planType)
    }

    /// Default Phase 2 prompt - detailed session for one outline (no dryland)
    public func buildDetailPrompt(sessionOutline: SessionOutline, weeklyOutline: WeeklyPlanOutline, context: PlanContext) -> String {
        return buildDefaultDetailPrompt(sessionOutline, weeklyOutline: weeklyOutline, context: context)
    }

    /// Default Phase 3 prompt - weekly dryland based on full plan
    public func buildDryLandPrompt(outline: WeeklyPlanOutline, context: PlanContext) -> String {
        return buildDefaultDryLandPrompt(outline, context: context)
    }
}
