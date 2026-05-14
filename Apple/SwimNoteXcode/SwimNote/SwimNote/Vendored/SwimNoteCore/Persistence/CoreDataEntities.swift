@preconcurrency import Foundation
#if canImport(CoreData)
import CoreData

// MARK: - Data to String Helper

extension Data {
    var utf8String: String {
        String(data: self, encoding: .utf8) ?? ""
    }
}

// MARK: - SwimNoteJSONDecoder String Decode Helper

extension SwimNoteJSONDecoder {
    func decode<T: Decodable>(_ type: T.Type, from string: String) throws -> T {
        guard let data = string.data(using: .utf8) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Invalid UTF8 string"))
        }
        return try decode(type, from: data)
    }
}

// MARK: - Core Data Entity Classes
// These are NSManagedObject subclasses for the entities defined in SwimNote.xcdatamodeld
// Note: To-many relationships are NOT declared as typed properties to avoid KVC conflicts
// Use mutableSetValue(forKey:) to manage relationships

@objc(UserProfileEntity)
public class UserProfileEntity: NSManagedObject {
    @NSManaged public var id: String
    @NSManaged public var name: String
    @NSManaged public var birthday: String
    @NSManaged public var sexRaw: String
    @NSManaged public var skillLevelRaw: String
    @NSManaged public var weeklySessionTarget: Int32
    @NSManaged public var preferredStrokesRaw: String?
    @NSManaged public var mainStrokeRaw: String?
    @NSManaged public var distancePreferenceRaw: String
    @NSManaged public var preferredDistanceUnitRaw: String
    @NSManaged public var profileIconTypeRaw: String
    @NSManaged public var profileImageData: Data?
    @NSManaged public var profileIconName: String?
    @NSManaged public var personalBestsJSON: String?
    @NSManaged public var pbHistoryJSON: String?
    @NSManaged public var cssHistoryJSON: String?
    @NSManaged public var trainingGoalsJSON: String?
    @NSManaged public var limitationsJSON: String?
    @NSManaged public var createdAt: String
    @NSManaged public var updatedAt: String
}

@objc(TrainingNoteEntity)
public class TrainingNoteEntity: NSManagedObject {
    @NSManaged public var userId: String
    @NSManaged public var date: String
    @NSManaged public var strokeFocusRaw: String?
    @NSManaged public var techniqueFocusRaw: String?
    @NSManaged public var notes: String?
    @NSManaged public var llmInsights: String?
    @NSManaged public var createdAt: String
    @NSManaged public var updatedAt: String
    // goals relationship managed via mutableSetValue(forKey: "goals")
}

@objc(GoalEntity)
public class GoalEntity: NSManagedObject {
    @NSManaged public var id: String
    @NSManaged public var typeRaw: String
    @NSManaged public var target: String?
    @NSManaged public var strokeIdRaw: String?
    @NSManaged public var descriptionText: String  // Renamed to avoid NSObject.description conflict
    @NSManaged public var statusRaw: String
    @NSManaged public var revisit: Bool
    @NSManaged public var metricsJSON: String?
    @NSManaged public var techniqueNodeId: String?
    @NSManaged public var coachingTips: String?
    @NSManaged public var goalNotes: String?
    @NSManaged public var goalKindRaw: String?
    @NSManaged public var competitiveDrillSnapshotJSON: String?
    @NSManaged public var createdAt: String
    @NSManaged public var updatedAt: String
    @NSManaged public var trainingNote: TrainingNoteEntity?
}

@objc(WeeklyTrainingPlanEntity)
public class WeeklyTrainingPlanEntity: NSManagedObject {
    @NSManaged public var id: String
    @NSManaged public var userId: String
    @NSManaged public var weekStartingDate: Date?
    @NSManaged public var overviewJSON: String?
    @NSManaged public var scheduleJSON: String?
    @NSManaged public var weeklyGoalsJSON: String?
    @NSManaged public var techniqueProgressPlanJSON: String?
    @NSManaged public var notes: String?
    @NSManaged public var poolTypeRaw: String?
    // detailedSessions and dryLandProgram relationships managed via mutableSetValue
}

@objc(DetailedSessionEntity)
public class DetailedSessionEntity: NSManagedObject {
    @NSManaged public var id: String
    @NSManaged public var sessionNumber: Int32
    @NSManaged public var focus: String
    @NSManaged public var warmUpJSON: String?
    @NSManaged public var drillSetJSON: String?
    @NSManaged public var mainSetJSON: String?
    @NSManaged public var secondarySetJSON: String?
    @NSManaged public var coolDownJSON: String?
    @NSManaged public var techniqueFocus: String?
    @NSManaged public var techniqueFileRef: String?
    @NSManaged public var addressesGoal: String?
    @NSManaged public var sessionType: String?
    @NSManaged public var progressionRationale: String?
    @NSManaged public var sessionNotes: String?
    @NSManaged public var scheduledDate: Date?
    @NSManaged public var isCompleted: Bool
    @NSManaged public var isAssigned: Bool
    @NSManaged public var weeklyPlan: WeeklyTrainingPlanEntity?
}

@objc(DryLandExercisePlanEntity)
public class DryLandExercisePlanEntity: NSManagedObject {
    @NSManaged public var id: String
    @NSManaged public var exercise: String
    @NSManaged public var setsReps: String
    @NSManaged public var focus: String?
    @NSManaged public var techniqueSupport: String?
    @NSManaged public var scheduledDate: Date?
    @NSManaged public var isAssigned: Bool
    @NSManaged public var isCompleted: Bool
    @NSManaged public var weeklyPlan: WeeklyTrainingPlanEntity?
}

@objc(TechniqueMeasurementEntity)
public class TechniqueMeasurementEntity: NSManagedObject {
    @NSManaged public var id: String
    @NSManaged public var userId: String
    @NSManaged public var date: String
    @NSManaged public var timestamp: String
    @NSManaged public var strokeIdRaw: String
    @NSManaged public var poolLength: Int32
    @NSManaged public var distanceUnitRaw: String
    @NSManaged public var strokeCount: Int32
    @NSManaged public var lapTime: Double
    @NSManaged public var glideTime: NSNumber?  // Use NSNumber for optional scalars
    @NSManaged public var handPositionRaw: String?
    @NSManaged public var kickPerStroke: NSNumber?  // Use NSNumber for optional scalars
    @NSManaged public var effortZone: Int32
    @NSManaged public var drillContext: String?
    @NSManaged public var notes: String?
    @NSManaged public var createdAt: String
    @NSManaged public var updatedAt: String
}

// MARK: - Entity to Domain Model Conversion

extension UserProfileEntity {
    func toUserProfile() throws -> UserProfile {
        let decoder = SwimNoteJSONDecoder()

        let personalBests: PersonalBests
        if let json = personalBestsJSON, let data = json.data(using: .utf8) {
            personalBests = try decoder.decode(PersonalBests.self, from: data)
        } else {
            personalBests = .empty()
        }

        let cssHistory: CSSHistory?
        if let json = cssHistoryJSON, let data = json.data(using: .utf8) {
            cssHistory = try decoder.decode(CSSHistory.self, from: data)
        } else {
            cssHistory = nil
        }

        let pbHistory: PBHistory?
        if let json = pbHistoryJSON, let data = json.data(using: .utf8) {
            pbHistory = try decoder.decode(PBHistory.self, from: data)
        } else {
            pbHistory = nil
        }

        let trainingGoals: [String]
        if let json = trainingGoalsJSON, let data = json.data(using: .utf8) {
            trainingGoals = try decoder.decode([String].self, from: data)
        } else {
            trainingGoals = []
        }

        let limitations: [String]?
        if let json = limitationsJSON, let data = json.data(using: .utf8) {
            limitations = try decoder.decode([String].self, from: data)
        } else {
            limitations = nil
        }

        let preferredStrokes: [StrokeID]
        if let json = preferredStrokesRaw, let data = json.data(using: .utf8) {
            preferredStrokes = try decoder.decode([StrokeID].self, from: data)
        } else {
            preferredStrokes = []
        }

        return UserProfile(
            id: id,
            name: name,
            birthday: birthday,
            sex: Sex(rawValue: sexRaw) ?? .other,
            skillLevel: SkillLevel(rawValue: skillLevelRaw) ?? .beginner,
            weeklySessionTarget: Int(weeklySessionTarget),
            preferredStrokes: preferredStrokes,
            mainStroke: mainStrokeRaw != nil ? StrokeID(rawValue: mainStrokeRaw!) : nil,
            distancePreference: DistancePreference(rawValue: distancePreferenceRaw) ?? .na,
            preferredDistanceUnit: DistanceUnit(rawValue: preferredDistanceUnitRaw) ?? .meters,
            profileIconType: ProfileIconType(rawValue: profileIconTypeRaw) ?? .letter,
            profileImageData: profileImageData,
            profileIconName: profileIconName,
            personalBests: personalBests,
            pbHistory: pbHistory,
            cssHistory: cssHistory,
            trainingGoals: trainingGoals,
            limitations: limitations,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

extension TrainingNoteEntity {
    func toTrainingNote() throws -> TrainingNote {
        let decoder = SwimNoteJSONDecoder()

        let strokeFocus: [StrokeID]
        if let json = strokeFocusRaw, let data = json.data(using: .utf8) {
            strokeFocus = try decoder.decode([StrokeID].self, from: data)
        } else {
            strokeFocus = []
        }

        let techniqueFocus: [TechniqueID]
        if let json = techniqueFocusRaw, let data = json.data(using: .utf8) {
            techniqueFocus = try decoder.decode([TechniqueID].self, from: data)
        } else {
            techniqueFocus = []
        }

        // Get goals via KVC
        let goalsSet = self.value(forKey: "goals") as? Set<NSManagedObject> ?? []
        let goalsArray = goalsSet.compactMap { entity -> Goal? in
            guard let goalEntity = entity as? GoalEntity else { return nil }
            return try? goalEntity.toGoal()
        }

        return TrainingNote(
            userId: userId,
            date: date,
            strokeFocus: strokeFocus,
            techniqueFocus: techniqueFocus,
            goals: goalsArray,
            notes: notes ?? "",
            llmInsights: llmInsights,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

extension GoalEntity {
    func toGoal() throws -> Goal {
        let decoder = SwimNoteJSONDecoder()

        let metrics: [String: MetricValue]?
        if let json = metricsJSON, let data = json.data(using: .utf8) {
            metrics = try decoder.decode([String: MetricValue].self, from: data)
        } else {
            metrics = nil
        }

        let competitiveMetricSnapshot: CompetitiveMetricSnapshot?
        if let json = competitiveDrillSnapshotJSON, let data = json.data(using: .utf8) {
            competitiveMetricSnapshot = try decoder.decode(CompetitiveMetricSnapshot.self, from: data)
        } else {
            competitiveMetricSnapshot = nil
        }

        return Goal(
            id: id,
            type: GoalType(rawValue: typeRaw) ?? .general,
            target: target,
            strokeId: strokeIdRaw != nil ? StrokeID(rawValue: strokeIdRaw!) : nil,
            description: descriptionText,
            status: GoalStatus(rawValue: statusRaw) ?? .planned,
            revisit: revisit,
            metrics: metrics,
            techniqueNodeId: techniqueNodeId,
            coachingTips: coachingTips,
            notes: goalNotes,
            goalKind: goalKindRaw != nil ? GoalKind(rawValue: goalKindRaw!) : nil,
            competitiveMetricSnapshot: competitiveMetricSnapshot,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

extension WeeklyTrainingPlanEntity {
    func toWeeklyTrainingPlan() throws -> WeeklyTrainingPlan {
        let decoder = SwimNoteJSONDecoder()

        let overview: PlanOverview
        if let json = overviewJSON {
            overview = try decoder.decode(PlanOverview.self, from: json)
        } else {
            // Fallback: create minimal overview from notes
            overview = PlanOverview(weekFocus: notes ?? "Training Week")
        }

        let schedule: [DaySchedule]
        if let json = scheduleJSON {
            schedule = try decoder.decode([DaySchedule].self, from: json)
        } else {
            schedule = []
        }

        let weeklyGoals: [WeeklyGoal]?
        if let json = weeklyGoalsJSON {
            weeklyGoals = try decoder.decode([WeeklyGoal].self, from: json)
        } else {
            weeklyGoals = nil
        }

        let techniqueProgressPlan: TechniqueProgressPlan?
        if let json = techniqueProgressPlanJSON {
            techniqueProgressPlan = try decoder.decode(TechniqueProgressPlan.self, from: json)
        } else {
            techniqueProgressPlan = nil
        }

        // Get sessions via KVC
        let sessionsSet = self.value(forKey: "detailedSessions") as? Set<NSManagedObject> ?? []
        let sessionsArray = sessionsSet.compactMap { entity -> DetailedSession? in
            guard let sessionEntity = entity as? DetailedSessionEntity else { return nil }
            return try? sessionEntity.toDetailedSession()
        }

        // Get dry land via KVC
        let dryLandSet = self.value(forKey: "dryLandProgram") as? Set<NSManagedObject> ?? []
        let dryLandArray = dryLandSet.compactMap { entity -> DryLandExercisePlan? in
            guard let dryLandEntity = entity as? DryLandExercisePlanEntity else { return nil }
            return try? dryLandEntity.toDryLandExercisePlan()
        }

        return WeeklyTrainingPlan(
            overview: overview,
            schedule: schedule,
            detailedSessions: sessionsArray,
            dryLandProgram: dryLandArray.isEmpty ? nil : dryLandArray,
            weeklyGoals: weeklyGoals,
            techniqueProgressPlan: techniqueProgressPlan,
            notes: notes ?? "",
            weekStartingDate: weekStartingDate,
            poolTypeRaw: poolTypeRaw
        )
    }
}

extension DetailedSessionEntity {
    func toDetailedSession() throws -> DetailedSession {
        let decoder = SwimNoteJSONDecoder()

        // Required segments - decode from JSON string directly
        let warmUp: SessionSegment
        if let json = warmUpJSON {
            warmUp = try decoder.decode(SessionSegment.self, from: json)
        } else {
            warmUp = SessionSegment(distance: "", description: "")
        }

        let drillSet: SessionSegment
        if let json = drillSetJSON {
            drillSet = try decoder.decode(SessionSegment.self, from: json)
        } else {
            drillSet = SessionSegment(distance: "", description: "")
        }

        let mainSet: SessionSegment
        if let json = mainSetJSON {
            mainSet = try decoder.decode(SessionSegment.self, from: json)
        } else {
            mainSet = SessionSegment(distance: "", description: "")
        }

        let secondarySet: SessionSegment?
        if let json = secondarySetJSON {
            secondarySet = try decoder.decode(SessionSegment.self, from: json)
        } else {
            secondarySet = nil
        }

        let coolDown: SessionSegment
        if let json = coolDownJSON {
            coolDown = try decoder.decode(SessionSegment.self, from: json)
        } else {
            coolDown = SessionSegment(distance: "", description: "")
        }

        return DetailedSession(
            id: id,
            sessionNumber: Int(sessionNumber),
            focus: focus,
            warmUp: warmUp,
            drillSet: drillSet,
            mainSet: mainSet,
            secondarySet: secondarySet,
            coolDown: coolDown,
            techniqueFocus: techniqueFocus ?? "",
            techniqueFileRef: techniqueFileRef,
            addressesGoal: addressesGoal,
            sessionType: sessionType,
            progressionRationale: progressionRationale,
            sessionNotes: sessionNotes,
            scheduledDate: scheduledDate,
            isCompleted: isCompleted,
            // Auto-set isAssigned if scheduledDate exists but isAssigned was stored as false
            isAssigned: isAssigned || (scheduledDate != nil)
        )
    }
}

extension DryLandExercisePlanEntity {
    func toDryLandExercisePlan() throws -> DryLandExercisePlan {
        return DryLandExercisePlan(
            id: id,
            exercise: exercise,
            setsReps: setsReps,
            focus: focus,
            techniqueSupport: techniqueSupport,
            scheduledDate: scheduledDate,
            // Auto-set isAssigned if scheduledDate exists but isAssigned was stored as false
            isAssigned: isAssigned || (scheduledDate != nil),
            isCompleted: isCompleted
        )
    }
}

extension TechniqueMeasurementEntity {
    func toTechniqueMeasurement() -> TechniqueMeasurement {
        let handPosition: HandPosition?
        if let raw = handPositionRaw {
            handPosition = HandPosition(rawValue: raw)
        } else {
            handPosition = nil
        }

        // Convert NSNumber? to Swift optional types
        let glideTimeValue: TimeInterval? = glideTime?.doubleValue
        let kickPerStrokeValue: Int? = kickPerStroke != nil ? Int(kickPerStroke!.int32Value) : nil

        return TechniqueMeasurement(
            id: id,
            userId: userId,
            date: date,
            timestamp: timestamp,
            strokeId: StrokeID(rawValue: strokeIdRaw) ?? .freestyle,
            poolLength: Int(poolLength),
            distanceUnit: DistanceUnit(rawValue: distanceUnitRaw) ?? .meters,
            strokeCount: Int(strokeCount),
            lapTime: lapTime,
            glideTime: glideTimeValue,
            handPosition: handPosition,
            kickPerStroke: kickPerStrokeValue,
            effortZone: Int(effortZone),
            drillContext: drillContext,
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - Timer Session Entity

@objc(TimerSessionEntity)
public class TimerSessionEntity: NSManagedObject {
    @NSManaged public var id: String
    @NSManaged public var userId: String
    @NSManaged public var date: String
    @NSManaged public var strokeIdRaw: String
    @NSManaged public var poolLength: Int32
    @NSManaged public var distanceUnitRaw: String
    @NSManaged public var totalDistance: Int32
    @NSManaged public var splitsJSON: String
    @NSManaged public var totalTime: Double
    @NSManaged public var notes: String?
    @NSManaged public var createdAt: String
    @NSManaged public var updatedAt: String
}

extension TimerSessionEntity {
    func toTimerSession() throws -> TimerSession {
        let decoder = SwimNoteJSONDecoder()

        let splits: [TimerSplit]
        if let data = splitsJSON.data(using: .utf8) {
            splits = try decoder.decode([TimerSplit].self, from: data)
        } else {
            splits = []
        }

        return TimerSession(
            id: id,
            userId: userId,
            date: date,
            strokeId: StrokeID(rawValue: strokeIdRaw) ?? .freestyle,
            poolLength: Int(poolLength),
            distanceUnit: DistanceUnit(rawValue: distanceUnitRaw) ?? .meters,
            totalDistance: Int(totalDistance),
            splits: splits,
            totalTime: totalTime,
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

#endif