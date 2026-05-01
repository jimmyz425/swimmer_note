@preconcurrency import Foundation

public struct SwimNoteJSONDecoder: Sendable {
    private let decoder: JSONDecoder

    public init() {
        self.decoder = JSONDecoder()
    }

    public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder.decode(type, from: data)
    }
}

public struct SwimNoteJSONEncoder: Sendable {
    private let encoder: JSONEncoder

    public init() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
    }

    public func encode<T: Encodable>(_ value: T) throws -> Data {
        try encoder.encode(value)
    }
}

public enum StrokeID: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case freestyle
    case backstroke
    case breaststroke
    case butterfly
    case im
    case master

    public var id: String { rawValue }
}

public enum TechniqueID: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case start
    case dolphinKicks = "dolphin_kicks"
    case flutterKick = "flutter_kick"
    case breaststrokeKick = "breaststroke_kick"
    case flipTurn = "flip_turn"
    case openTurn = "open_turn"
    case streamline
    case breathing
    case `catch` = "catch"
    case pull
    case recovery
    case bodyPosition = "body_position"
    case finish

    public var id: String { rawValue }
}

public enum GoalType: String, Codable, Hashable, Sendable {
    case general
    case stroke
    case technique
}

public enum GoalStatus: String, Codable, Hashable, Sendable {
    case planned
    case inProgress = "in_progress"
    case achieved
    case unableToAchieve = "unable_to_achieve"

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "pending":
            self = .planned
        default:
            guard let status = GoalStatus(rawValue: rawValue) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unknown goal status: \(rawValue)"
                )
            }
            self = status
        }
    }
}

public enum GoalKind: String, Codable, Hashable, Sendable {
    case keyPoint
    case mistake
    case competitiveMetric
}

public enum Sex: String, Codable, CaseIterable, Hashable, Sendable {
    case male
    case female
    case other
}

public enum DistanceUnit: String, Codable, CaseIterable, Hashable, Sendable {
    case meters
    case yards
}

public enum DistancePreference: String, Codable, CaseIterable, Hashable, Sendable {
    case short      // 50m-100m events
    case mid        // 200m-400m events
    case long       // 800m-1500m+ events
    case na         // Not specified / general

    public var displayName: String {
        switch self {
        case .short: "Short (50-100m)"
        case .mid: "Mid (200-400m)"
        case .long: "Long (800m+)"
        case .na: "General"
        }
    }

    public var description: String {
        switch self {
        case .short: "Sprint events, explosive power focus"
        case .mid: "Mid-distance, threshold training focus"
        case .long: "Distance events, aerobic endurance focus"
        case .na: "No specific distance preference"
        }
    }
}

public enum ProfileIconType: String, Codable, CaseIterable, Hashable, Sendable {
    case letter  // First letter of name
    case image   // Custom photo
    case icon    // SF Symbol
}

public enum SkillLevel: String, Codable, CaseIterable, Hashable, Sendable {
    case beginner
    case intermediate
    case advanced
    case competitive
    case elite
}

public struct PersonalBests: Codable, Hashable, Sendable {
    public var freestyle50m: TimeInterval?
    public var backstroke50m: TimeInterval?
    public var breaststroke50m: TimeInterval?
    public var butterfly50m: TimeInterval?
    public var freestyle50yd: TimeInterval?
    public var backstroke50yd: TimeInterval?
    public var breaststroke50yd: TimeInterval?
    public var butterfly50yd: TimeInterval?
    public var updatedAt: String?

    public init(
        freestyle50m: TimeInterval? = nil,
        backstroke50m: TimeInterval? = nil,
        breaststroke50m: TimeInterval? = nil,
        butterfly50m: TimeInterval? = nil,
        freestyle50yd: TimeInterval? = nil,
        backstroke50yd: TimeInterval? = nil,
        breaststroke50yd: TimeInterval? = nil,
        butterfly50yd: TimeInterval? = nil,
        updatedAt: String? = nil
    ) {
        self.freestyle50m = freestyle50m
        self.backstroke50m = backstroke50m
        self.breaststroke50m = breaststroke50m
        self.butterfly50m = butterfly50m
        self.freestyle50yd = freestyle50yd
        self.backstroke50yd = backstroke50yd
        self.breaststroke50yd = breaststroke50yd
        self.butterfly50yd = butterfly50yd
        self.updatedAt = updatedAt
    }

    public static func empty() -> PersonalBests {
        PersonalBests()
    }

    public func estimatedSkillLevel(birthday: String, sex: Sex) -> SkillLevel {
        let times: [TimeInterval?] = [
            freestyle50m, backstroke50m, breaststroke50m, butterfly50m,
            freestyle50yd, backstroke50yd, breaststroke50yd, butterfly50yd
        ]
        let hasAnyPB = times.contains { $0 != nil }
        if !hasAnyPB { return .beginner }

        let fastest = times.compactMap { $0 }.min() ?? 999
        if fastest < 25 { return .elite }
        if fastest < 30 { return .competitive }
        if fastest < 35 { return .advanced }
        if fastest < 45 { return .intermediate }
        return .beginner
    }

    public func estimatedSkillLevel(age: Int, sex: Sex) -> SkillLevel {
        estimatedSkillLevel(birthday: "", sex: sex)
    }

    public var isEmpty: Bool {
        freestyle50m == nil && backstroke50m == nil && breaststroke50m == nil && butterfly50m == nil &&
        freestyle50yd == nil && backstroke50yd == nil && breaststroke50yd == nil && butterfly50yd == nil
    }
}

public struct UserProfile: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var birthday: String  // ISO format: YYYY-MM-DD
    public var sex: Sex
    public var skillLevel: SkillLevel
    public var weeklySessionTarget: Int
    public var preferredStrokes: [StrokeID]
    public var mainStroke: StrokeID?  // Primary stroke focus, nil = not set
    public var distancePreference: DistancePreference  // Preferred race distance
    public var preferredDistanceUnit: DistanceUnit
    public var profileIconType: ProfileIconType
    public var profileImageData: Data?  // Base64 encoded image
    public var profileIconName: String? // SF Symbol name
    public var personalBests: PersonalBests
    public var cssHistory: CSSHistory?
    public var trainingGoals: [String]
    public var limitations: [String]?
    public var createdAt: String
    public var updatedAt: String

    public var age: Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let birthDate = formatter.date(from: birthday) else { return 0 }
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year], from: birthDate, to: now)
        return components.year ?? 0
    }

    public var initials: String {
        String(name.prefix(1).uppercased())
    }

    // MARK: - Codable with backward compatibility

    private enum CodingKeys: String, CodingKey {
        case id, name, birthday, sex, skillLevel, weeklySessionTarget
        case preferredStrokes, mainStroke, distancePreference, preferredDistanceUnit
        case profileIconType, profileImageData, profileIconName
        case personalBests, cssHistory, trainingGoals, limitations
        case createdAt, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        birthday = try container.decode(String.self, forKey: .birthday)
        sex = try container.decode(Sex.self, forKey: .sex)
        skillLevel = try container.decode(SkillLevel.self, forKey: .skillLevel)
        weeklySessionTarget = try container.decode(Int.self, forKey: .weeklySessionTarget)
        preferredStrokes = try container.decode([StrokeID].self, forKey: .preferredStrokes)
        mainStroke = try container.decodeIfPresent(StrokeID.self, forKey: .mainStroke)
        distancePreference = try container.decodeIfPresent(DistancePreference.self, forKey: .distancePreference) ?? .na
        preferredDistanceUnit = try container.decode(DistanceUnit.self, forKey: .preferredDistanceUnit)
        profileIconType = try container.decode(ProfileIconType.self, forKey: .profileIconType)
        profileImageData = try container.decodeIfPresent(Data.self, forKey: .profileImageData)
        profileIconName = try container.decodeIfPresent(String.self, forKey: .profileIconName)
        personalBests = try container.decode(PersonalBests.self, forKey: .personalBests)
        cssHistory = try container.decodeIfPresent(CSSHistory.self, forKey: .cssHistory)
        trainingGoals = try container.decode([String].self, forKey: .trainingGoals)
        limitations = try container.decodeIfPresent([String].self, forKey: .limitations)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(birthday, forKey: .birthday)
        try container.encode(sex, forKey: .sex)
        try container.encode(skillLevel, forKey: .skillLevel)
        try container.encode(weeklySessionTarget, forKey: .weeklySessionTarget)
        try container.encode(preferredStrokes, forKey: .preferredStrokes)
        try container.encodeIfPresent(mainStroke, forKey: .mainStroke)
        try container.encode(distancePreference, forKey: .distancePreference)
        try container.encode(preferredDistanceUnit, forKey: .preferredDistanceUnit)
        try container.encode(profileIconType, forKey: .profileIconType)
        try container.encodeIfPresent(profileImageData, forKey: .profileImageData)
        try container.encodeIfPresent(profileIconName, forKey: .profileIconName)
        try container.encode(personalBests, forKey: .personalBests)
        try container.encodeIfPresent(cssHistory, forKey: .cssHistory)
        try container.encode(trainingGoals, forKey: .trainingGoals)
        try container.encodeIfPresent(limitations, forKey: .limitations)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    public init(
        id: String,
        name: String,
        birthday: String,
        sex: Sex,
        skillLevel: SkillLevel,
        weeklySessionTarget: Int,
        preferredStrokes: [StrokeID],
        mainStroke: StrokeID? = nil,
        distancePreference: DistancePreference = .na,
        preferredDistanceUnit: DistanceUnit = .meters,
        profileIconType: ProfileIconType = .letter,
        profileImageData: Data? = nil,
        profileIconName: String? = nil,
        personalBests: PersonalBests,
        cssHistory: CSSHistory? = nil,
        trainingGoals: [String],
        limitations: [String]? = nil,
        createdAt: String,
        updatedAt: String
    ) {
        self.id = id
        self.name = name
        self.birthday = birthday
        self.sex = sex
        self.skillLevel = skillLevel
        self.weeklySessionTarget = weeklySessionTarget
        self.preferredStrokes = preferredStrokes
        self.mainStroke = mainStroke
        self.distancePreference = distancePreference
        self.preferredDistanceUnit = preferredDistanceUnit
        self.profileIconType = profileIconType
        self.profileImageData = profileImageData
        self.profileIconName = profileIconName
        self.personalBests = personalBests
        self.cssHistory = cssHistory
        self.trainingGoals = trainingGoals
        self.limitations = limitations
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct Stroke: Codable, Hashable, Identifiable, Sendable {
    public var id: StrokeID
    public var name: String
    public var aliases: [String]

    public init(id: StrokeID, name: String, aliases: [String]) {
        self.id = id
        self.name = name
        self.aliases = aliases
    }
}

public struct Technique: Codable, Hashable, Identifiable, Sendable {
    public var id: TechniqueID
    public var name: String
    public var category: String
    public var description: String

    public init(id: TechniqueID, name: String, category: String, description: String) {
        self.id = id
        self.name = name
        self.category = category
        self.description = description
    }
}

public struct MetricValue: Codable, Hashable, Sendable {
    public var target: Double?
    public var actual: Double?
    public var previousBest: Double?
    public var unit: String

    public init(target: Double? = nil, actual: Double? = nil, previousBest: Double? = nil, unit: String = "") {
        self.target = target
        self.actual = actual
        self.previousBest = previousBest
        self.unit = unit
    }
}

public struct MetricDefinition: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var unit: String
    public var description: String

    public init(id: String, name: String, unit: String, description: String) {
        self.id = id
        self.name = name
        self.unit = unit
        self.description = description
    }
}

public struct Goal: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var type: GoalType
    public var target: String?
    public var strokeId: StrokeID?
    public var description: String
    public var status: GoalStatus
    public var revisit: Bool?
    public var metrics: [String: MetricValue]?
    public var techniqueNodeId: String?
    public var coachingTips: String?
    public var notes: String?
    public var goalKind: GoalKind?
    public var competitiveDrillSnapshot: CompetitiveDrillSnapshot?
    public var createdAt: String
    public var updatedAt: String

    private static func generateID(from date: Date) -> String {
        "goal_\(Int(date.timeIntervalSince1970 * 1000))_\(UUID().uuidString.prefix(8))"
    }

    public init(
        id: String,
        type: GoalType,
        target: String? = nil,
        strokeId: StrokeID? = nil,
        description: String,
        status: GoalStatus,
        revisit: Bool? = nil,
        metrics: [String: MetricValue]? = nil,
        techniqueNodeId: String? = nil,
        coachingTips: String? = nil,
        notes: String? = nil,
        goalKind: GoalKind? = nil,
        competitiveDrillSnapshot: CompetitiveDrillSnapshot? = nil,
        createdAt: String,
        updatedAt: String
    ) {
        self.id = id
        self.type = type
        self.target = target
        self.strokeId = strokeId
        self.description = description
        self.status = status
        self.revisit = revisit
        self.metrics = metrics
        self.techniqueNodeId = techniqueNodeId
        self.coachingTips = coachingTips
        self.notes = notes
        self.goalKind = goalKind
        self.competitiveDrillSnapshot = competitiveDrillSnapshot
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public static func fromTechniqueNode(_ node: TechniqueTreeNode, strokeId: StrokeID, date: Date = Date()) -> Goal {
        let timestamp = SwimNoteDateFormatting.string(from: date)
        let metricValues = node.metrics.map { definitions in
            Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, MetricValue(unit: $0.unit)) })
        }

        return Goal(
            id: Self.generateID(from: date),
            type: .technique,
            target: node.techniqueId,
            strokeId: strokeId,
            description: node.name,
            status: .planned,
            revisit: node.revisit,
            metrics: metricValues,
            techniqueNodeId: node.id,
            notes: "",
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }

    public static func fromKeyPoint(
        keyPoint: String,
        techniqueNodeId: String,
        strokeId: StrokeID,
        date: Date = Date()
    ) -> Goal {
        let timestamp = SwimNoteDateFormatting.string(from: date)
        return Goal(
            id: Self.generateID(from: date),
            type: .technique,
            strokeId: strokeId,
            description: keyPoint,
            status: .planned,
            techniqueNodeId: techniqueNodeId,
            goalKind: .keyPoint,
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }

    public static func fromMistake(
        mistake: String,
        techniqueNodeId: String,
        strokeId: StrokeID,
        date: Date = Date()
    ) -> Goal {
        let timestamp = SwimNoteDateFormatting.string(from: date)
        return Goal(
            id: Self.generateID(from: date),
            type: .technique,
            strokeId: strokeId,
            description: "Avoid: \(mistake)",
            status: .planned,
            techniqueNodeId: techniqueNodeId,
            goalKind: .mistake,
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }

    public static func fromCompetitiveDrill(
        drill: CompetitiveDrill,
        selectedTier: String,
        techniqueNodeId: String,
        strokeId: StrokeID,
        date: Date = Date()
    ) -> Goal {
        let timestamp = SwimNoteDateFormatting.string(from: date)
        let snapshot = CompetitiveDrillSnapshot.from(drill: drill, selectedTier: selectedTier)
        return Goal(
            id: Self.generateID(from: date),
            type: .technique,
            strokeId: strokeId,
            description: drill.name,
            status: .planned,
            techniqueNodeId: techniqueNodeId,
            goalKind: .competitiveMetric,
            competitiveDrillSnapshot: snapshot,
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }
}

public struct TrainingNote: Codable, Hashable, Sendable {
    public var userId: String
    public var date: String
    public var strokeFocus: [StrokeID]
    public var techniqueFocus: [TechniqueID]
    public var goals: [Goal]
    public var notes: String
    public var llmInsights: String?
    public var createdAt: String
    public var updatedAt: String

    public init(
        userId: String,
        date: String,
        strokeFocus: [StrokeID],
        techniqueFocus: [TechniqueID],
        goals: [Goal],
        notes: String,
        llmInsights: String? = nil,
        createdAt: String,
        updatedAt: String
    ) {
        self.userId = userId
        self.date = date
        self.strokeFocus = strokeFocus
        self.techniqueFocus = techniqueFocus
        self.goals = goals
        self.notes = notes
        self.llmInsights = llmInsights
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public static func empty(userId: String, date: String, now: Date = Date()) -> TrainingNote {
        let timestamp = SwimNoteDateFormatting.string(from: now)
        return TrainingNote(
            userId: userId,
            date: date,
            strokeFocus: [],
            techniqueFocus: [],
            goals: [],
            notes: "",
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }
}

public struct ActiveGoals: Codable, Hashable, Sendable {
    public var activeGoals: [Goal]
    public var lastUpdated: String?
}

public struct TechniqueTreeNode: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var techniqueId: String
    public var level: Int
    public var name: String
    public var description: String
    public var revisit: Bool
    public var metrics: [MetricDefinition]?
    public var prerequisites: [String]
    public var children: [String]
    public var sourceFile: String?

    public init(
        id: String,
        techniqueId: String,
        level: Int,
        name: String,
        description: String,
        revisit: Bool,
        metrics: [MetricDefinition]?,
        prerequisites: [String],
        children: [String],
        sourceFile: String?
    ) {
        self.id = id
        self.techniqueId = techniqueId
        self.level = level
        self.name = name
        self.description = description
        self.revisit = revisit
        self.metrics = metrics
        self.prerequisites = prerequisites
        self.children = children
        self.sourceFile = sourceFile
    }
}

public struct TechniqueTree: Codable, Hashable, Sendable {
    public var strokeId: StrokeID
    public var name: String
    public var generatedAt: String
    public var customized: Bool
    public var nodes: [TechniqueTreeNode]
    public var rootNodes: [String]
}

public struct NodeNavigationValue: Hashable, Sendable {
    public let strokeId: StrokeID
    public let nodeId: String

    public init(strokeId: StrokeID, nodeId: String) {
        self.strokeId = strokeId
        self.nodeId = nodeId
    }
}

public struct StrokeNavigationValue: Hashable, Sendable {
    public let strokeId: StrokeID

    public init(strokeId: StrokeID) {
        self.strokeId = strokeId
    }
}

public struct CompetitiveDrill: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var selfCheck: String
    public var tieredTargetsTitle: String
    public var tieredTargets: [String: String]
    public var videoChecks: [String]
    public var competitiveImpact: String

    public init(id: String = UUID().uuidString, name: String, selfCheck: String, tieredTargetsTitle: String = "", tieredTargets: [String: String], videoChecks: [String], competitiveImpact: String) {
        self.id = id
        self.name = name
        self.selfCheck = selfCheck
        self.tieredTargetsTitle = tieredTargetsTitle
        self.tieredTargets = tieredTargets
        self.videoChecks = videoChecks
        self.competitiveImpact = competitiveImpact
    }
}

/// Snapshot of a competitive drill stored in a Goal for collapsible display
public struct CompetitiveDrillSnapshot: Codable, Hashable, Sendable {
    public var drillId: String
    public var name: String
    public var selfCheck: String
    public var tieredTargetsTitle: String
    public var tieredTargets: [String: String]
    public var videoChecks: [String]
    public var competitiveImpact: String
    public var selectedTier: String
    public var selectedTarget: String

    public init(
        drillId: String,
        name: String,
        selfCheck: String,
        tieredTargetsTitle: String,
        tieredTargets: [String: String],
        videoChecks: [String],
        competitiveImpact: String,
        selectedTier: String,
        selectedTarget: String
    ) {
        self.drillId = drillId
        self.name = name
        self.selfCheck = selfCheck
        self.tieredTargetsTitle = tieredTargetsTitle
        self.tieredTargets = tieredTargets
        self.videoChecks = videoChecks
        self.competitiveImpact = competitiveImpact
        self.selectedTier = selectedTier
        self.selectedTarget = selectedTarget
    }

    /// Create snapshot from a CompetitiveDrill
    public static func from(drill: CompetitiveDrill, selectedTier: String) -> CompetitiveDrillSnapshot {
        let targetValue = drill.tieredTargets[selectedTier] ?? ""
        return CompetitiveDrillSnapshot(
            drillId: drill.id,
            name: drill.name,
            selfCheck: drill.selfCheck,
            tieredTargetsTitle: drill.tieredTargetsTitle,
            tieredTargets: drill.tieredTargets,
            videoChecks: drill.videoChecks,
            competitiveImpact: drill.competitiveImpact,
            selectedTier: selectedTier,
            selectedTarget: targetValue
        )
    }
}

public struct SpecificDrill: Codable, Hashable, Sendable {
    public var name: String
    public var description: String
}

public struct ParsedTechniqueContent: Codable, Hashable, Sendable {
    public var filename: String
    public var title: String
    public var overview: String
    public var difficulty: String
    public var keyPoints: [String]
    public var commonMistakes: [String]
    public var specificDrills: [SpecificDrill]
    public var competitiveDrills: [CompetitiveDrill]
    public var relatedTechniques: [String]
    public var techniqueTable: [TechniqueTableEntry]  // From main stroke files: difficulty-ranked techniques
    public var prevFile: String?
    public var nextFile: String?
    public var rawContent: String
}

/// Entry from the technique table in main stroke files (numbered 1-9 with difficulty)
public struct TechniqueTableEntry: Codable, Hashable, Sendable {
    public var number: Int         // 1-9 = difficulty ranking
    public var name: String        // Technique name
    public var difficulty: String  // Easiest, Easy-Moderate, Moderate, etc.
    public var keyFocus: String    // Brief focus description
    public var filename: String    // Link to sub-technique file
}

// MARK: - CSS (Critical Swim Speed) Models

public enum CSSTestType: String, Codable, CaseIterable, Sendable {
    case twoTrial = "200m_400m"
    case threeMinute = "3min_all_out"

    public var displayName: String {
        switch self {
        case .twoTrial: "200m + 400m Time Trials"
        case .threeMinute: "3-Minute All-Out Test"
        }
    }

    public var description: String {
        switch self {
        case .twoTrial: "Standard method using 200m and 400m time trials"
        case .threeMinute: "Maximal effort, average speed of final 30 seconds approximates CSS"
        }
    }
}

public struct CSSTestResult: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var date: String  // ISO format
    public var testType: CSSTestType
    public var strokeId: StrokeID
    public var time200m: TimeInterval?  // For two-trial method (seconds)
    public var time400m: TimeInterval?  // For two-trial method (seconds)
    public var threeMinuteDistance: Double?  // For 3-min test (meters)
    public var cssMetersPerSecond: Double
    public var cssPaceSecondsPer100m: TimeInterval
    public var notes: String?
    public var createdAt: String
    public var updatedAt: String

    public init(
        id: String = UUID().uuidString,
        date: String,
        testType: CSSTestType,
        strokeId: StrokeID = .freestyle,
        time200m: TimeInterval? = nil,
        time400m: TimeInterval? = nil,
        threeMinuteDistance: Double? = nil,
        cssMetersPerSecond: Double,
        cssPaceSecondsPer100m: TimeInterval,
        notes: String? = nil,
        createdAt: String = SwimNoteDateFormatting.string(from: Date()),
        updatedAt: String = SwimNoteDateFormatting.string(from: Date())
    ) {
        self.id = id
        self.date = date
        self.testType = testType
        self.strokeId = strokeId
        self.time200m = time200m
        self.time400m = time400m
        self.threeMinuteDistance = threeMinuteDistance
        self.cssMetersPerSecond = cssMetersPerSecond
        self.cssPaceSecondsPer100m = cssPaceSecondsPer100m
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Calculate CSS from 200m and 400m time trials
    /// CSS = (D2 - D1) / (T2 - T1) where D1=200m, D2=400m
    public static func calculateFromTwoTrial(
        time200m: TimeInterval,
        time400m: TimeInterval,
        date: String = SwimNoteDateFormatting.todayShort(),
        strokeId: StrokeID = .freestyle,
        notes: String? = nil
    ) -> CSSTestResult? {
        guard time400m > time200m else { return nil }

        let css = (400.0 - 200.0) / (time400m - time200m)  // meters per second
        let pace100m = 100.0 / css  // seconds per 100m

        return CSSTestResult(
            date: date,
            testType: .twoTrial,
            strokeId: strokeId,
            time200m: time200m,
            time400m: time400m,
            cssMetersPerSecond: css,
            cssPaceSecondsPer100m: pace100m,
            notes: notes
        )
    }

    /// Calculate CSS from 3-minute all-out test
    /// CSS ≈ average speed over final 30 seconds
    public static func calculateFromThreeMinute(
        totalDistance: Double,
        final30sDistance: Double,
        date: String = SwimNoteDateFormatting.todayShort(),
        strokeId: StrokeID = .freestyle,
        notes: String? = nil
    ) -> CSSTestResult? {
        guard final30sDistance > 0 else { return nil }

        // CSS is the average speed over final 30 seconds
        let css = final30sDistance / 30.0  // meters per second
        let pace100m = 100.0 / css  // seconds per 100m

        return CSSTestResult(
            date: date,
            testType: .threeMinute,
            strokeId: strokeId,
            threeMinuteDistance: totalDistance,
            cssMetersPerSecond: css,
            cssPaceSecondsPer100m: pace100m,
            notes: notes
        )
    }

    /// Format pace as MM:SS per 100m
    public var formattedPace: String {
        let minutes = Int(cssPaceSecondsPer100m) / 60
        let seconds = Int(cssPaceSecondsPer100m) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Get training pace for a zone
    /// Zone adjustments from research document
    public func trainingPace(zone: TrainingZone) -> TimeInterval {
        cssPaceSecondsPer100m + zone.offsetSeconds
    }
}

public enum TrainingZone: Int, Codable, CaseIterable, Sendable {
    case recovery = 0
    case aerobicBase = 1
    case aerobicEndurance = 2
    case tempo = 3
    case lactateThreshold = 4
    case vo2max = 5
    case sprint = 6

    public var name: String {
        switch self {
        case .recovery: "Recovery"
        case .aerobicBase: "Aerobic Base"
        case .aerobicEndurance: "Aerobic Endurance"
        case .tempo: "Tempo"
        case .lactateThreshold: "Lactate Threshold"
        case .vo2max: "VO2max"
        case .sprint: "Sprint"
        }
    }

    /// Offset from CSS pace per 100m (in seconds)
    /// Positive = slower than CSS, negative = faster than CSS
    public var offsetSeconds: TimeInterval {
        switch self {
        case .recovery: 25  // +20-30s/100m, using midpoint
        case .aerobicBase: 12  // +10-15s/100m
        case .aerobicEndurance: 7  // +5-10s/100m
        case .tempo: 2  // +0-5s/100m
        case .lactateThreshold: -1  // CSS to -2s/100m
        case .vo2max: -4  // -3-6s/100m
        case .sprint: 0  // Race pace, not CSS-based
        }
    }

    public var description: String {
        switch self {
        case .recovery: "Zone 0 - Very easy, active recovery"
        case .aerobicBase: "Zone 1 - Conversational, technique focus"
        case .aerobicEndurance: "Zone 2 - Sustainable aerobic work"
        case .tempo: "Zone 3 - Comfortably hard"
        case .lactateThreshold: "Zone 4 - Hard, threshold pace"
        case .vo2max: "Zone 5 - Very hard, max aerobic"
        case .sprint: "Zone 6 - Race pace, neuromuscular"
        }
    }

    public var heartRateRange: String {
        switch self {
        case .recovery: "<60% HRmax"
        case .aerobicBase: "60-75% HRmax"
        case .aerobicEndurance: "75-82% HRmax"
        case .tempo: "82-88% HRmax"
        case .lactateThreshold: "88-92% HRmax"
        case .vo2max: "92-98% HRmax"
        case .sprint: "98-100% HRmax"
        }
    }
}

public struct CSSHistory: Codable, Hashable, Sendable {
    public var tests: [CSSTestResult]
    public var updatedAt: String?

    public init(tests: [CSSTestResult] = [], updatedAt: String? = nil) {
        self.tests = tests.sorted { $0.date > $1.date }  // Most recent first
        self.updatedAt = updatedAt
    }

    public var isEmpty: Bool { tests.isEmpty }

    public var latestTest: CSSTestResult? { tests.first }

    /// Get CSS trend: comparing latest to previous
    public var trend: CSSPaceTrend? {
        guard tests.count >= 2 else { return nil }
        let latest = tests[0].cssPaceSecondsPer100m
        let previous = tests[1].cssPaceSecondsPer100m
        let change = previous - latest  // Positive = improved (faster)

        if change > 2 { return .improving }
        if change < -2 { return .declining }
        return .stable
    }
}

public enum CSSPaceTrend: String, Codable, Sendable {
    case improving
    case stable
    case declining

    public var symbol: String {
        switch self {
        case .improving: "arrow.down"
        case .stable: "arrow.right"
        case .declining: "arrow.up"
        }
    }

    public var color: String {
        switch self {
        case .improving: "green"  // Faster is better
        case .stable: "blue"
        case .declining: "orange"
        }
    }
}

// MARK: - Training Plan Models

/// A single day's training plan
public nonisolated struct TrainingPlan: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var userId: String
    public var date: String  // The date this plan is for
    public var overview: String
    public var sessions: [TrainingSession]
    public var dryLandTraining: [DryLandExercise]?
    public var remarks: String
    public var createdAt: String
    public var updatedAt: String

    public init(
        id: String = UUID().uuidString,
        userId: String,
        date: String,
        overview: String,
        sessions: [TrainingSession],
        dryLandTraining: [DryLandExercise]? = nil,
        remarks: String,
        createdAt: String = SwimNoteDateFormatting.string(from: Date()),
        updatedAt: String = SwimNoteDateFormatting.string(from: Date())
    ) {
        self.id = id
        self.userId = userId
        self.date = date
        self.overview = overview
        self.sessions = sessions
        self.dryLandTraining = dryLandTraining
        self.remarks = remarks
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // Explicit Codable to avoid main actor isolation synthesis
    private enum CodingKeys: String, CodingKey {
        case id, userId, date, overview, sessions, dryLandTraining, remarks, createdAt, updatedAt
    }

    public nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        date = try container.decode(String.self, forKey: .date)
        overview = try container.decode(String.self, forKey: .overview)
        sessions = try container.decode([TrainingSession].self, forKey: .sessions)
        dryLandTraining = try container.decodeIfPresent([DryLandExercise].self, forKey: .dryLandTraining)
        remarks = try container.decodeIfPresent(String.self, forKey: .remarks) ?? ""
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? SwimNoteDateFormatting.string(from: Date())
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt) ?? SwimNoteDateFormatting.string(from: Date())
    }

    public nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(date, forKey: .date)
        try container.encode(overview, forKey: .overview)
        try container.encode(sessions, forKey: .sessions)
        try container.encodeIfPresent(dryLandTraining, forKey: .dryLandTraining)
        try container.encode(remarks, forKey: .remarks)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

public nonisolated struct TrainingSession: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var sessionNumber: Int
    public var focus: String
    public var details: String
    public var goals: String

    public init(
        id: String = UUID().uuidString,
        sessionNumber: Int,
        focus: String,
        details: String,
        goals: String
    ) {
        self.id = id
        self.sessionNumber = sessionNumber
        self.focus = focus
        self.details = details
        self.goals = goals
    }

    // Explicit Codable to avoid main actor isolation synthesis
    private enum CodingKeys: String, CodingKey {
        case id, sessionNumber, focus, details, goals
    }

    public nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        sessionNumber = try container.decode(Int.self, forKey: .sessionNumber)
        focus = try container.decode(String.self, forKey: .focus)
        details = try container.decodeIfPresent(String.self, forKey: .details) ?? ""
        goals = try container.decodeIfPresent(String.self, forKey: .goals) ?? ""
    }

    public nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(sessionNumber, forKey: .sessionNumber)
        try container.encode(focus, forKey: .focus)
        try container.encode(details, forKey: .details)
        try container.encode(goals, forKey: .goals)
    }
}

public nonisolated struct DryLandExercise: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var duration: String
    public var purpose: String

    public init(
        id: String = UUID().uuidString,
        name: String,
        duration: String,
        purpose: String
    ) {
        self.id = id
        self.name = name
        self.duration = duration
        self.purpose = purpose
    }

    // Explicit Codable to avoid main actor isolation synthesis
    private enum CodingKeys: String, CodingKey {
        case id, name, duration, purpose
    }

    public nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try container.decode(String.self, forKey: .name)
        duration = try container.decode(String.self, forKey: .duration)
        purpose = try container.decodeIfPresent(String.self, forKey: .purpose) ?? ""
    }

    public nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(duration, forKey: .duration)
        try container.encode(purpose, forKey: .purpose)
    }
}

public nonisolated enum SwimNoteDateFormatting {
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    public static func string(from date: Date) -> String {
        iso8601Formatter.string(from: date)
    }

    public static func shortDateString(from date: Date) -> String {
        shortDateFormatter.string(from: date)
    }

    public static func todayShort() -> String {
        shortDateFormatter.string(from: Date())
    }
}
