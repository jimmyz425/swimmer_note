import Foundation

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
    public var createdAt: String
    public var updatedAt: String

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
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public static func fromTechniqueNode(_ node: TechniqueTreeNode, strokeId: StrokeID, date: Date = Date()) -> Goal {
        let timestamp = SwimNoteDateFormatting.string(from: date)
        let metricValues = node.metrics.map { definitions in
            Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, MetricValue(unit: $0.unit)) })
        }

        return Goal(
            id: "goal_\(Int(date.timeIntervalSince1970 * 1000))_\(UUID().uuidString.prefix(8))",
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
}

public struct TrainingNote: Codable, Hashable, Sendable {
    public var date: String
    public var strokeFocus: [StrokeID]
    public var techniqueFocus: [TechniqueID]
    public var goals: [Goal]
    public var notes: String
    public var llmInsights: String?
    public var createdAt: String
    public var updatedAt: String

    public init(
        date: String,
        strokeFocus: [StrokeID],
        techniqueFocus: [TechniqueID],
        goals: [Goal],
        notes: String,
        llmInsights: String? = nil,
        createdAt: String,
        updatedAt: String
    ) {
        self.date = date
        self.strokeFocus = strokeFocus
        self.techniqueFocus = techniqueFocus
        self.goals = goals
        self.notes = notes
        self.llmInsights = llmInsights
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public static func empty(date: String, now: Date = Date()) -> TrainingNote {
        let timestamp = SwimNoteDateFormatting.string(from: now)
        return TrainingNote(
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

public struct CompetitiveDrill: Codable, Hashable, Sendable {
    public var name: String
    public var selfCheck: String
    public var tieredTargets: [String: String]
    public var videoChecks: [String]
    public var competitiveImpact: String
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
    public var prevFile: String?
    public var nextFile: String?
    public var rawContent: String
}

private enum SwimNoteDateFormatting {
    static func string(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
