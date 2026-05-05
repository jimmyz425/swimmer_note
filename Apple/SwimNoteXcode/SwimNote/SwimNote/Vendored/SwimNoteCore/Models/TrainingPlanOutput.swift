import Foundation

// MARK: - Phase 1: Weekly Plan Outline (Rough Plan)

/// Rough weekly plan outline for user review before detailed session generation
public nonisolated struct WeeklyPlanOutline: Codable, Hashable, Identifiable, Sendable {
    public var id: Date { weekStartingDate ?? Date() }

    public var overview: PlanOverview
    public var schedule: [SessionOutline]  // Rough session focuses, no detailed sets
    public var techniqueProgressPlan: TechniqueProgressPlan?
    public var pastTrainingSummary: String?  // Analysis of recent training sessions
    public var planConnectionRationale: String?  // How this plan connects to past training
    public var notes: String

    public var weekStartingDate: Date?
    public var poolTypeRaw: String?

    public init(
        overview: PlanOverview,
        schedule: [SessionOutline],
        techniqueProgressPlan: TechniqueProgressPlan?,
        pastTrainingSummary: String? = nil,
        planConnectionRationale: String? = nil,
        notes: String,
        weekStartingDate: Date? = nil,
        poolTypeRaw: String? = nil
    ) {
        self.overview = overview
        self.schedule = schedule
        self.techniqueProgressPlan = techniqueProgressPlan
        self.pastTrainingSummary = pastTrainingSummary
        self.planConnectionRationale = planConnectionRationale
        self.notes = notes
        self.weekStartingDate = weekStartingDate
        self.poolTypeRaw = poolTypeRaw
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        overview = try container.decode(PlanOverview.self, forKey: .overview)
        schedule = try container.decode([SessionOutline].self, forKey: .schedule)
        techniqueProgressPlan = try container.decodeIfPresent(TechniqueProgressPlan.self, forKey: .techniqueProgressPlan)
        pastTrainingSummary = try container.decodeIfPresent(String.self, forKey: .pastTrainingSummary)
        planConnectionRationale = try container.decodeIfPresent(String.self, forKey: .planConnectionRationale)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        weekStartingDate = try container.decodeIfPresent(Date.self, forKey: .weekStartingDate)
        poolTypeRaw = try container.decodeIfPresent(String.self, forKey: .poolTypeRaw)
    }

    private enum CodingKeys: String, CodingKey {
        case overview, schedule, techniqueProgressPlan
        case pastTrainingSummary, planConnectionRationale, notes, weekStartingDate, poolTypeRaw
    }
}

/// Rough session outline - focus area without detailed sets
public nonisolated struct SessionOutline: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var sessionNumber: Int
    public var dayOfWeek: String?  // "Monday", "Tuesday", etc.
    public var poolSession: String  // Session name
    public var focus: String  // Main focus description
    public var sessionType: String?  // "sprint", "technique", "endurance", etc.
    public var techniqueFocus: String?  // Specific technique emphasis
    public var techniqueFileRef: String?  // Reference to technique file
    public var addressesGoal: String?  // Which goal this addresses
    public var estimatedDuration: String?  // "~60min"
    public var estimatedDistance: String?  // "~800m"
    public var isDetailsGenerated: Bool = false  // Whether detailed session was generated
    public var detailedSession: DetailedSession?  // Populated after Phase 2

    public init(
        id: String = UUID().uuidString,
        sessionNumber: Int,
        dayOfWeek: String?,
        poolSession: String,
        focus: String,
        sessionType: String?,
        techniqueFocus: String?,
        techniqueFileRef: String?,
        addressesGoal: String?,
        estimatedDuration: String?,
        estimatedDistance: String?,
        isDetailsGenerated: Bool = false,
        detailedSession: DetailedSession? = nil
    ) {
        self.id = id
        self.sessionNumber = sessionNumber
        self.dayOfWeek = dayOfWeek
        self.poolSession = poolSession
        self.focus = focus
        self.sessionType = sessionType
        self.techniqueFocus = techniqueFocus
        self.techniqueFileRef = techniqueFileRef
        self.addressesGoal = addressesGoal
        self.estimatedDuration = estimatedDuration
        self.estimatedDistance = estimatedDistance
        self.isDetailsGenerated = isDetailsGenerated
        self.detailedSession = detailedSession
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        sessionNumber = try container.decodeIfPresent(Int.self, forKey: .sessionNumber) ?? 1
        dayOfWeek = try container.decodeIfPresent(String.self, forKey: .dayOfWeek)
        poolSession = try container.decodeIfPresent(String.self, forKey: .poolSession) ?? ""
        focus = try container.decodeIfPresent(String.self, forKey: .focus) ?? ""
        sessionType = try container.decodeIfPresent(String.self, forKey: .sessionType)
        techniqueFocus = try container.decodeIfPresent(String.self, forKey: .techniqueFocus)
        techniqueFileRef = try container.decodeIfPresent(String.self, forKey: .techniqueFileRef)
        addressesGoal = try container.decodeIfPresent(String.self, forKey: .addressesGoal)
        estimatedDuration = try container.decodeIfPresent(String.self, forKey: .estimatedDuration)
        estimatedDistance = try container.decodeIfPresent(String.self, forKey: .estimatedDistance)
        isDetailsGenerated = try container.decodeIfPresent(Bool.self, forKey: .isDetailsGenerated) ?? false
        detailedSession = try container.decodeIfPresent(DetailedSession.self, forKey: .detailedSession)
    }

    private enum CodingKeys: String, CodingKey {
        case id, sessionNumber, dayOfWeek, poolSession, focus, sessionType
        case techniqueFocus, techniqueFileRef, addressesGoal
        case estimatedDuration, estimatedDistance, isDetailsGenerated, detailedSession
    }
}

// MARK: - Structured Training Plan Output

public nonisolated struct WeeklyTrainingPlan: Codable, Hashable, Identifiable, Sendable {
    public var id: Date { weekStartingDate ?? Date() }

    public var overview: PlanOverview
    public var schedule: [DaySchedule]
    public var detailedSessions: [DetailedSession]
    public var dryLandProgram: [DryLandExercisePlan]?
    public var weeklyGoals: [WeeklyGoal]?
    public var techniqueProgressPlan: TechniqueProgressPlan?
    public var notes: String

    // Computed: Week starting date (usually Monday of the target week)
    public var weekStartingDate: Date?

    // Store pool type for proper distance display when loading saved plans
    public var poolTypeRaw: String?

    public init(
        overview: PlanOverview,
        schedule: [DaySchedule],
        detailedSessions: [DetailedSession],
        dryLandProgram: [DryLandExercisePlan]?,
        weeklyGoals: [WeeklyGoal]?,
        techniqueProgressPlan: TechniqueProgressPlan?,
        notes: String,
        weekStartingDate: Date? = nil,
        poolTypeRaw: String? = nil
    ) {
        self.overview = overview
        self.schedule = schedule
        self.detailedSessions = detailedSessions
        self.dryLandProgram = dryLandProgram
        self.weeklyGoals = weeklyGoals
        self.techniqueProgressPlan = techniqueProgressPlan
        self.notes = notes
        self.weekStartingDate = weekStartingDate
        self.poolTypeRaw = poolTypeRaw
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        overview = try container.decode(PlanOverview.self, forKey: .overview)
        schedule = try container.decode([DaySchedule].self, forKey: .schedule)
        detailedSessions = try container.decode([DetailedSession].self, forKey: .detailedSessions)
        dryLandProgram = try container.decodeIfPresent([DryLandExercisePlan].self, forKey: .dryLandProgram)
        weeklyGoals = try container.decodeIfPresent([WeeklyGoal].self, forKey: .weeklyGoals)
        // Backwards compatibility: read from goalProgressPlan JSON key
        techniqueProgressPlan = try container.decodeIfPresent(TechniqueProgressPlan.self, forKey: .techniqueProgressPlan)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        weekStartingDate = try container.decodeIfPresent(Date.self, forKey: .weekStartingDate)
        poolTypeRaw = try container.decodeIfPresent(String.self, forKey: .poolTypeRaw)
    }

    private enum CodingKeys: String, CodingKey {
        case overview, schedule, detailedSessions, dryLandProgram, weeklyGoals
        case techniqueProgressPlan = "goalProgressPlan"  // Backwards compatibility with existing JSON
        case notes, weekStartingDate, poolTypeRaw
    }
}

public nonisolated struct PlanOverview: Codable, Hashable, Sendable {
    public var weekFocus: String
    public var pastMonthAnalysis: String?
    public var technicalObjective: String?
    public var physicalObjective: String?
    public var strokeRotationPlan: String?
    public var fundamentalRevisitPlan: String?

    // Computed fields (not from LLM):
    public var swimmerSummary: String?  // Generated from UserProfile
    public var sessionCount: Int?  // From sessionsPerWeek setting
    public var poolType: String?  // From user selection
    public var totalDistance: String?  // Summed from detailedSessions

    // Additional fields for specific strategies:
    public var raceEvent: String?
    public var sprintTarget: String?
    public var technicalObjectiveDetail: String?

    public init(
        weekFocus: String,
        pastMonthAnalysis: String? = nil,
        technicalObjective: String? = nil,
        physicalObjective: String? = nil,
        strokeRotationPlan: String? = nil,
        fundamentalRevisitPlan: String? = nil,
        swimmerSummary: String? = nil,
        sessionCount: Int? = nil,
        poolType: String? = nil,
        totalDistance: String? = nil,
        raceEvent: String? = nil,
        sprintTarget: String? = nil,
        technicalObjectiveDetail: String? = nil
    ) {
        self.weekFocus = weekFocus
        self.pastMonthAnalysis = pastMonthAnalysis
        self.technicalObjective = technicalObjective
        self.physicalObjective = physicalObjective
        self.strokeRotationPlan = strokeRotationPlan
        self.fundamentalRevisitPlan = fundamentalRevisitPlan
        self.swimmerSummary = swimmerSummary
        self.sessionCount = sessionCount
        self.poolType = poolType
        self.totalDistance = totalDistance
        self.raceEvent = raceEvent
        self.sprintTarget = sprintTarget
        self.technicalObjectiveDetail = technicalObjectiveDetail
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        weekFocus = try container.decodeIfPresent(String.self, forKey: .weekFocus) ?? ""
        pastMonthAnalysis = try container.decodeIfPresent(String.self, forKey: .pastMonthAnalysis)
        technicalObjective = try container.decodeIfPresent(String.self, forKey: .technicalObjective)
        physicalObjective = try container.decodeIfPresent(String.self, forKey: .physicalObjective)
        strokeRotationPlan = try container.decodeIfPresent(String.self, forKey: .strokeRotationPlan)
        fundamentalRevisitPlan = try container.decodeIfPresent(String.self, forKey: .fundamentalRevisitPlan)
        swimmerSummary = try container.decodeIfPresent(String.self, forKey: .swimmerSummary)
        sessionCount = try container.decodeIfPresent(Int.self, forKey: .sessionCount)
        poolType = try container.decodeIfPresent(String.self, forKey: .poolType)
        totalDistance = try container.decodeIfPresent(String.self, forKey: .totalDistance)
        raceEvent = try container.decodeIfPresent(String.self, forKey: .raceEvent)
        sprintTarget = try container.decodeIfPresent(String.self, forKey: .sprintTarget)
        technicalObjectiveDetail = try container.decodeIfPresent(String.self, forKey: .technicalObjectiveDetail)
    }

    private enum CodingKeys: String, CodingKey {
        case weekFocus, pastMonthAnalysis, technicalObjective, physicalObjective
        case strokeRotationPlan, fundamentalRevisitPlan
        case swimmerSummary, sessionCount, poolType, totalDistance
        case raceEvent, sprintTarget, technicalObjectiveDetail
    }
}

public nonisolated struct DaySchedule: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var sessionNumber: Int
    public var poolSession: String
    public var duration: String?
    public var focus: String
    public var dryLand: String?
    public var sessionType: String?

    public init(
        id: String = UUID().uuidString,
        sessionNumber: Int,
        poolSession: String,
        duration: String?,
        focus: String,
        dryLand: String?,
        sessionType: String?
    ) {
        self.id = id
        self.sessionNumber = sessionNumber
        self.poolSession = poolSession
        self.duration = duration
        self.focus = focus
        self.dryLand = dryLand
        self.sessionType = sessionType
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        sessionNumber = try container.decode(Int.self, forKey: .sessionNumber)
        poolSession = try container.decode(String.self, forKey: .poolSession)
        duration = try container.decodeIfPresent(String.self, forKey: .duration)
        focus = try container.decode(String.self, forKey: .focus)
        dryLand = try container.decodeIfPresent(String.self, forKey: .dryLand)
        sessionType = try container.decodeIfPresent(String.self, forKey: .sessionType)
    }

    private enum CodingKeys: String, CodingKey {
        case id, sessionNumber, poolSession, duration, focus, dryLand, sessionType
    }
}

public nonisolated struct DetailedSession: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var sessionNumber: Int
    public var focus: String
    public var warmUp: SessionSegment
    public var drillSet: SessionSegment
    public var mainSet: SessionSegment
    public var secondarySet: SessionSegment?
    public var coolDown: SessionSegment
    public var techniqueFocus: String
    public var techniqueFileRef: String?
    public var addressesGoal: String?
    public var sessionType: String?
    public var progressionRationale: String?
    public var sessionNotes: String?

    // Computed: Scheduled date for this session (not from LLM)
    public var scheduledDate: Date?

    // Runtime state: Whether this session has been completed
    public var isCompleted: Bool = false

    // Runtime state: Whether this session is assigned to a specific date
    // Unassigned sessions can't be completed - user must pick a date first
    public var isAssigned: Bool = false

    public init(
        id: String = UUID().uuidString,
        sessionNumber: Int,
        focus: String,
        warmUp: SessionSegment,
        drillSet: SessionSegment,
        mainSet: SessionSegment,
        secondarySet: SessionSegment? = nil,
        coolDown: SessionSegment,
        techniqueFocus: String,
        techniqueFileRef: String?,
        addressesGoal: String?,
        sessionType: String?,
        progressionRationale: String?,
        sessionNotes: String? = nil,
        scheduledDate: Date? = nil,
        isCompleted: Bool = false,
        isAssigned: Bool = false
    ) {
        self.id = id
        self.sessionNumber = sessionNumber
        self.focus = focus
        self.warmUp = warmUp
        self.drillSet = drillSet
        self.mainSet = mainSet
        self.secondarySet = secondarySet
        self.coolDown = coolDown
        self.techniqueFocus = techniqueFocus
        self.techniqueFileRef = techniqueFileRef
        self.addressesGoal = addressesGoal
        self.sessionType = sessionType
        self.progressionRationale = progressionRationale
        self.sessionNotes = sessionNotes
        self.scheduledDate = scheduledDate
        self.isCompleted = isCompleted
        self.isAssigned = isAssigned
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        sessionNumber = try container.decode(Int.self, forKey: .sessionNumber)
        focus = try container.decode(String.self, forKey: .focus)
        warmUp = try container.decode(SessionSegment.self, forKey: .warmUp)
        drillSet = try container.decode(SessionSegment.self, forKey: .drillSet)
        mainSet = try container.decode(SessionSegment.self, forKey: .mainSet)
        secondarySet = try container.decodeIfPresent(SessionSegment.self, forKey: .secondarySet)
        coolDown = try container.decode(SessionSegment.self, forKey: .coolDown)
        techniqueFocus = try container.decode(String.self, forKey: .techniqueFocus)
        techniqueFileRef = try container.decodeIfPresent(String.self, forKey: .techniqueFileRef)
        addressesGoal = try container.decodeIfPresent(String.self, forKey: .addressesGoal)
        sessionType = try container.decodeIfPresent(String.self, forKey: .sessionType)
        progressionRationale = try container.decodeIfPresent(String.self, forKey: .progressionRationale)
        sessionNotes = try container.decodeIfPresent(String.self, forKey: .sessionNotes)
        scheduledDate = try container.decodeIfPresent(Date.self, forKey: .scheduledDate)
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        isAssigned = try container.decodeIfPresent(Bool.self, forKey: .isAssigned) ?? (scheduledDate != nil)
    }

    private enum CodingKeys: String, CodingKey {
        case id, sessionNumber, focus, warmUp, drillSet, mainSet, secondarySet, coolDown
        case techniqueFocus, techniqueFileRef, addressesGoal, sessionType, progressionRationale
        case sessionNotes, scheduledDate, isCompleted, isAssigned
    }

    /// Convert this session to a TrainingPlan for display on Dashboard
    public func toTrainingPlan(date: String) -> TrainingPlan {
        // Build session details from segments
        let details = buildSessionDetails()

        let trainingSession = TrainingSession(
            sessionNumber: sessionNumber,
            focus: focus,
            details: details,
            goals: addressesGoal ?? techniqueFocus
        )

        return TrainingPlan(
            userId: "",
            date: date,
            overview: focus,
            sessions: [trainingSession],
            dryLandTraining: nil,
            remarks: sessionNotes ?? ""
        )
    }

    private func buildSessionDetails() -> String {
        var parts: [String] = []

        parts.append("Warm-up: \(warmUp.distance) - \(warmUp.description)")
        parts.append("Drills: \(drillSet.distance) - \(drillSet.description)")
        parts.append("Main: \(mainSet.distance) - \(mainSet.description)")

        if let secondary = secondarySet {
            parts.append("Secondary: \(secondary.distance) - \(secondary.description)")
        }

        parts.append("Cool-down: \(coolDown.distance) - \(coolDown.description)")

        return parts.joined(separator: "\n")
    }
}

// MARK: - Structured Set Item (for reliable distance calculation)

/// Represents a single set within a training segment
/// Format allows programmatic distance calculation without relying on LLM math
public nonisolated struct SetItem: Codable, Hashable, Identifiable, Sendable {
    public var id: String = UUID().uuidString
    public var repeatCount: Int        // Number of repetitions (e.g., 6 for "6x50m")
    public var distancePerRep: Int?    // Distance in meters per repetition (nil for timed/non-distance items)
    public var swimSeconds: Int?       // Swim time per rep in seconds (calculated from zone+CSS or explicit)
    public var restSeconds: Int?       // Rest time in seconds between repetitions (from interval research)
    public var item: String            // Description of what to do (e.g., "breaststroke swim", "streamline push-off")
    public var notes: String?          // Additional notes (e.g., "with fins", "build")
    public var zone: Int?              // Training zone (0-6 based on CSS zones)

    /// Calculate total distance for this set
    public var totalDistance: Int {
        if let dist = distancePerRep {
            return repeatCount * dist
        }
        return 0  // Timed items have no distance
    }

    /// Format timing as Sxxxs Rxxxs display
    public var formattedTiming: String {
        if let swim = swimSeconds {
            if let rest = restSeconds {
                return "S\(swim)s R\(rest)s"
            }
            return "S\(swim)s"
        }
        return ""
    }

    /// Format as readable string for display
    public var formatted: String {
        var base: String
        if let dist = distancePerRep {
            base = "\(repeatCount)x\(dist)m"
        } else if let swim = swimSeconds {
            base = "\(repeatCount)x S\(swim)s"
        } else {
            base = "\(repeatCount)x \(item)"
        }

        // Add timing if specified
        var extras: [String] = []
        if let rest = restSeconds, swimSeconds != nil {
            extras.append("R\(rest)s")
        } else if let rest = restSeconds {
            extras.append("rest \(rest)s")
        }
        if let notes = notes {
            extras.append(notes)
        }

        let itemStr = extras.isEmpty ? "" : " (\(extras.joined(separator: ", ")))"
        return "\(base) \(item)\(itemStr)"
    }

    public init(
        repeatCount: Int,
        distancePerRep: Int? = nil,
        swimSeconds: Int? = nil,
        restSeconds: Int? = nil,
        item: String,
        notes: String? = nil,
        zone: Int? = nil
    ) {
        self.repeatCount = repeatCount
        self.distancePerRep = distancePerRep
        self.swimSeconds = swimSeconds
        self.restSeconds = restSeconds
        self.item = item
        self.notes = notes
        self.zone = zone
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        repeatCount = try container.decodeIfPresent(Int.self, forKey: .repeatCount) ?? 1
        distancePerRep = try container.decodeIfPresent(Int.self, forKey: .distancePerRep)
        swimSeconds = try container.decodeIfPresent(Int.self, forKey: .swimSeconds)
        restSeconds = try container.decodeIfPresent(Int.self, forKey: .restSeconds)
        item = try container.decodeIfPresent(String.self, forKey: .item) ?? ""
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        zone = try container.decodeIfPresent(Int.self, forKey: .zone)
    }

    private enum CodingKeys: String, CodingKey {
        case id, repeatCount, distancePerRep, swimSeconds, restSeconds, item, notes, zone
    }
}

public nonisolated struct SessionSegment: Codable, Hashable, Sendable {
    // Legacy fields (computed from sets for display)
    public var distance: String
    public var description: String
    public var drills: [String]?

    // New structured field - LLM outputs this directly
    public var sets: [SetItem]?

    // Training zone for this segment (0-6 based on CSS zones)
    public var zone: Int?

    /// Calculate total distance from sets array
    public var calculatedDistance: Int {
        guard let sets = sets, !sets.isEmpty else { return 0 }
        return sets.reduce(0) { $0 + $1.totalDistance }
    }

    public init(distance: String, description: String, drills: [String]? = nil, sets: [SetItem]? = nil, zone: Int? = nil) {
        self.distance = distance
        self.description = description
        self.drills = drills
        self.sets = sets
        self.zone = zone
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        distance = try container.decodeIfPresent(String.self, forKey: .distance) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        drills = try container.decodeIfPresent([String].self, forKey: .drills)
        sets = try container.decodeIfPresent([SetItem].self, forKey: .sets)
        zone = try container.decodeIfPresent(Int.self, forKey: .zone)
    }

    private enum CodingKeys: String, CodingKey {
        case distance, description, drills, sets, zone
    }
}

public nonisolated struct DryLandExercisePlan: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var exercise: String
    public var setsReps: String
    public var focus: String?
    public var techniqueSupport: String?

    // Computed: Scheduled date for this exercise (not from LLM)
    public var scheduledDate: Date?

    // Runtime state: Whether this exercise is assigned to a specific date
    public var isAssigned: Bool = false

    // Runtime state: Whether this exercise has been completed
    public var isCompleted: Bool = false

    public init(
        id: String = UUID().uuidString,
        exercise: String,
        setsReps: String,
        focus: String?,
        techniqueSupport: String?,
        scheduledDate: Date? = nil,
        isAssigned: Bool = false,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.exercise = exercise
        self.setsReps = setsReps
        self.focus = focus
        self.techniqueSupport = techniqueSupport
        self.scheduledDate = scheduledDate
        self.isAssigned = isAssigned
        self.isCompleted = isCompleted
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        exercise = try container.decode(String.self, forKey: .exercise)
        setsReps = try container.decode(String.self, forKey: .setsReps)
        focus = try container.decodeIfPresent(String.self, forKey: .focus)
        techniqueSupport = try container.decodeIfPresent(String.self, forKey: .techniqueSupport)
        scheduledDate = try container.decodeIfPresent(Date.self, forKey: .scheduledDate)
        isAssigned = try container.decodeIfPresent(Bool.self, forKey: .isAssigned) ?? (scheduledDate != nil)
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case id, exercise, setsReps, focus, techniqueSupport, scheduledDate, isAssigned, isCompleted
    }
}

public nonisolated struct WeeklyGoal: Codable, Hashable, Sendable {
    public var metric: String
    public var target: String
    public var measurementMethod: String?
    public var relatedToPastGoal: String?
    public var relatedToGoal: String?

    public init(metric: String, target: String, measurementMethod: String?, relatedToPastGoal: String?, relatedToGoal: String?) {
        self.metric = metric
        self.target = target
        self.measurementMethod = measurementMethod
        self.relatedToPastGoal = relatedToPastGoal
        self.relatedToGoal = relatedToGoal
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        metric = try container.decode(String.self, forKey: .metric)
        target = try container.decode(String.self, forKey: .target)
        measurementMethod = try container.decodeIfPresent(String.self, forKey: .measurementMethod)
        relatedToPastGoal = try container.decodeIfPresent(String.self, forKey: .relatedToPastGoal)
        relatedToGoal = try container.decodeIfPresent(String.self, forKey: .relatedToGoal)
    }

    private enum CodingKeys: String, CodingKey {
        case metric, target, measurementMethod, relatedToPastGoal, relatedToGoal
    }
}

public nonisolated struct TechniqueProgressPlan: Codable, Hashable, Sendable {
    public var continueGoals: [String]
    public var achievedGoalsNextLevel: [String]
    public var revisitGoals: [String]
    public var newGoals: [String]
    public var fundamentalRevisitGoals: [String]?

    public init(
        continueGoals: [String] = [],
        achievedGoalsNextLevel: [String] = [],
        revisitGoals: [String] = [],
        newGoals: [String] = [],
        fundamentalRevisitGoals: [String]? = nil
    ) {
        self.continueGoals = continueGoals
        self.achievedGoalsNextLevel = achievedGoalsNextLevel
        self.revisitGoals = revisitGoals
        self.newGoals = newGoals
        self.fundamentalRevisitGoals = fundamentalRevisitGoals
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        continueGoals = try container.decodeIfPresent([String].self, forKey: .continueGoals) ?? []
        achievedGoalsNextLevel = try container.decodeIfPresent([String].self, forKey: .achievedGoalsNextLevel) ?? []
        revisitGoals = try container.decodeIfPresent([String].self, forKey: .revisitGoals) ?? []
        newGoals = try container.decodeIfPresent([String].self, forKey: .newGoals) ?? []
        fundamentalRevisitGoals = try container.decodeIfPresent([String].self, forKey: .fundamentalRevisitGoals)
    }

    private enum CodingKeys: String, CodingKey {
        case continueGoals, achievedGoalsNextLevel, revisitGoals, newGoals, fundamentalRevisitGoals
    }
}