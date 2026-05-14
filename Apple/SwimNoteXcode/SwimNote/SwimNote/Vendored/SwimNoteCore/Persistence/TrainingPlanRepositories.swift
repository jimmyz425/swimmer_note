import Foundation

// MARK: - Training Plan Repository Protocol (Legacy)

public protocol TrainingPlanRepository: Sendable {
    func listPlans(for userId: String) async -> [TrainingPlan]
    func plan(for userId: String, weekStarting: String) async -> TrainingPlan?
    func save(_ plan: TrainingPlan) async throws
    func delete(id: String, userId: String) async throws
}

// MARK: - Weekly Training Plan Repository Protocol

public protocol WeeklyPlanRepository: Sendable {
    func listPlans(for userId: String) async -> [WeeklyTrainingPlan]
    func plan(for userId: String, weekStarting: String) async -> WeeklyTrainingPlan?
    func sessionsForDate(for userId: String, date: String) async -> [DetailedSession]
    func save(_ plan: WeeklyTrainingPlan, for userId: String) async throws
    func delete(planId: String, userId: String) async throws
}

// MARK: - Outline Repository Protocol (for in-progress generation)

public protocol OutlineRepository: Sendable {
    func loadOutline(for userId: String) async -> WeeklyPlanOutline?
    func saveOutline(_ outline: WeeklyPlanOutline, for userId: String) async throws
    func deleteOutline(for userId: String) async throws
}

// MARK: - JSON File Implementation (Legacy TrainingPlan)

public actor JSONTrainingPlanRepository: TrainingPlanRepository {
    private let plansDirectory: URL

    public init(plansDirectory: URL) {
        self.plansDirectory = plansDirectory
        try? FileManager.default.createDirectory(at: plansDirectory, withIntermediateDirectories: true)
    }

    public func listPlans(for userId: String) async -> [TrainingPlan] {
        let userDir = plansDirectory.appendingPathComponent(userId)
        guard FileManager.default.fileExists(atPath: userDir.path) else { return [] }

        let files = (try? FileManager.default.contentsOfDirectory(atPath: userDir.path))?.filter { $0.hasSuffix(".json") } ?? []

        var plans: [TrainingPlan] = []

        for filename in files {
            let file = userDir.appendingPathComponent(filename)
            guard let data = FileManager.default.contents(atPath: file.path),
                  let plan = try? JSONDecoder().decode(TrainingPlan.self, from: data) else {
                continue
            }
            plans.append(plan)
        }

        // Sort by date descending
        return plans.sorted { $0.date > $1.date }
    }

    public func plan(for userId: String, weekStarting: String) async -> TrainingPlan? {
        let file = plansDirectory
            .appendingPathComponent(userId)
            .appendingPathComponent("\(weekStarting).json")

        guard let data = FileManager.default.contents(atPath: file.path) else { return nil }
        return try? JSONDecoder().decode(TrainingPlan.self, from: data)
    }

    public func save(_ plan: TrainingPlan) async throws {
        let userDir = plansDirectory.appendingPathComponent(plan.userId)
        try FileManager.default.createDirectory(at: userDir, withIntermediateDirectories: true)

        let file = userDir.appendingPathComponent("\(plan.date).json")
        let data = try JSONEncoder().encode(plan)
        try data.write(to: file)
    }

    public func delete(id: String, userId: String) async throws {
        // Find and delete the plan file
        let userDir = plansDirectory.appendingPathComponent(userId)
        let files = (try? FileManager.default.contentsOfDirectory(atPath: userDir.path))?.filter { $0.hasSuffix(".json") } ?? []

        for filename in files {
            let file = userDir.appendingPathComponent(filename)
            guard let data = FileManager.default.contents(atPath: file.path),
                  let plan = try? JSONDecoder().decode(TrainingPlan.self, from: data),
                  plan.id == id else {
                continue
            }
            try FileManager.default.removeItem(at: file)
            break
        }
    }
}

// MARK: - JSON Weekly Plan Repository

public actor JSONWeeklyPlanRepository: WeeklyPlanRepository {
    private let plansDirectory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(plansDirectory: URL) {
        self.plansDirectory = plansDirectory
        self.encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
        try? FileManager.default.createDirectory(at: plansDirectory, withIntermediateDirectories: true)
    }

    public func listPlans(for userId: String) async -> [WeeklyTrainingPlan] {
        let userDir = plansDirectory.appendingPathComponent(userId)
        guard FileManager.default.fileExists(atPath: userDir.path) else { return [] }

        let files = (try? FileManager.default.contentsOfDirectory(atPath: userDir.path))?.filter { $0.hasSuffix(".json") } ?? []

        var plans: [WeeklyTrainingPlan] = []

        for filename in files {
            let file = userDir.appendingPathComponent(filename)
            guard let data = FileManager.default.contents(atPath: file.path),
                  let plan = try? decoder.decode(WeeklyTrainingPlan.self, from: data) else {
                continue
            }
            plans.append(plan)
        }

        // Sort by week starting date descending
        return plans.sorted { ($0.weekStartingDate ?? Date.distantPast) > ($1.weekStartingDate ?? Date.distantPast) }
    }

    public func plan(for userId: String, weekStarting: String) async -> WeeklyTrainingPlan? {
        let file = plansDirectory
            .appendingPathComponent(userId)
            .appendingPathComponent("\(weekStarting).json")

        guard let data = FileManager.default.contents(atPath: file.path) else { return nil }
        return try? decoder.decode(WeeklyTrainingPlan.self, from: data)
    }

    /// Find all sessions scheduled for a specific date
    public func sessionsForDate(for userId: String, date: String) async -> [DetailedSession] {
        // Parse the date string
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard formatter.date(from: date) != nil else { return [] }

        // Find all plans for this user and search for sessions on this date
        let plans = await listPlans(for: userId)

        var matchingSessions: [DetailedSession] = []

        for plan in plans {
            for session in plan.detailedSessions {
                if let sessionDate = session.scheduledDate {
                    let sessionDateStr = formatter.string(from: sessionDate)
                    if sessionDateStr == date {
                        matchingSessions.append(session)
                    }
                }
            }
        }

        // Sort by time of day (morning → afternoon → evening)
        return matchingSessions.sorted { first, second in
            let firstOrder = first.timeOfDay?.rawValue ?? "morning"
            let secondOrder = second.timeOfDay?.rawValue ?? "morning"
            return firstOrder < secondOrder
        }
    }

    public func save(_ plan: WeeklyTrainingPlan, for userId: String) async throws {
        // Use weekStartingDate for filename
        let weekStarting: String
        if let date = plan.weekStartingDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            weekStarting = formatter.string(from: date)
        } else {
            weekStarting = "unknown-week"
        }

        let userDir = plansDirectory.appendingPathComponent(userId)
        try FileManager.default.createDirectory(at: userDir, withIntermediateDirectories: true)

        let file = userDir.appendingPathComponent("\(weekStarting).json")
        let data = try encoder.encode(plan)
        try data.write(to: file)
    }

    public func delete(planId: String, userId: String) async throws {
        let userDir = plansDirectory.appendingPathComponent(userId)
        let files = (try? FileManager.default.contentsOfDirectory(atPath: userDir.path))?.filter { $0.hasSuffix(".json") } ?? []

        for filename in files {
            let file = userDir.appendingPathComponent(filename)
            guard let data = FileManager.default.contents(atPath: file.path),
                  let plan = try? decoder.decode(WeeklyTrainingPlan.self, from: data),
                  plan.detailedSessions.contains(where: { $0.id == planId }) else {
                continue
            }
            try FileManager.default.removeItem(at: file)
            break
        }
    }
}

// MARK: - Weekly Plan to Training Plan Conversion

extension WeeklyTrainingPlan {
    public func toTrainingPlan(userId: String, weekStarting: String) -> TrainingPlan {
        // Convert sessions
        let sessions: [TrainingSession] = detailedSessions.map { session in
            TrainingSession(
                sessionNumber: session.sessionNumber,
                focus: session.focus,
                details: """
                Warm-up: \(session.warmUp.distance) - \(session.warmUp.description)
                Drills: \(session.drillSet.distance) - \(session.drillSet.description)
                Main: \(session.mainSet.distance) - \(session.mainSet.description)
                Cool-down: \(session.coolDown.distance) - \(session.coolDown.description)
                Technique Focus: \(session.techniqueFocus)
                """,
                goals: session.addressesGoal ?? ""
            )
        }

        // Convert dry land exercises
        let dryLand: [DryLandExercise]? = dryLandProgram?.map { exercise in
            DryLandExercise(
                name: exercise.exercise,
                duration: exercise.setsReps,
                purpose: "\(exercise.focus ?? "") - \(exercise.techniqueSupport ?? "")"
            )
        }

        // Create overview summary
        let overviewText = """
        \(overview.swimmerSummary ?? "no summary")

        Week Focus: \(overview.weekFocus)
        Technical: \(overview.technicalObjective ?? "")
        Physical: \(overview.physicalObjective ?? "")
        Total Distance: \(overview.totalDistance ?? "")
        Pool: \(overview.poolType ?? "Pool")

        Past Month: \(overview.pastMonthAnalysis ?? "No previous data")

        Goals:
        \(weeklyGoals?.map { "- \($0.metric): \($0.target)" }.joined(separator: "\n") ?? "No goals specified")
        """

        return TrainingPlan(
            userId: userId,
            date: weekStarting,
            overview: overviewText,
            sessions: sessions,
            dryLandTraining: dryLand,
            remarks: notes
        )
    }
}

// MARK: - JSON Outline Repository (for in-progress generation)

public actor JSONOutlineRepository: OutlineRepository {
    private let outlinesDirectory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(outlinesDirectory: URL) {
        self.outlinesDirectory = outlinesDirectory
        self.encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
        try? FileManager.default.createDirectory(at: outlinesDirectory, withIntermediateDirectories: true)
    }

    public func loadOutline(for userId: String) async -> WeeklyPlanOutline? {
        let file = outlinesDirectory
            .appendingPathComponent(userId)
            .appendingPathComponent("in_progress.json")

        guard let data = FileManager.default.contents(atPath: file.path) else { return nil }
        return try? decoder.decode(WeeklyPlanOutline.self, from: data)
    }

    public func saveOutline(_ outline: WeeklyPlanOutline, for userId: String) async throws {
        let userDir = outlinesDirectory.appendingPathComponent(userId)
        try FileManager.default.createDirectory(at: userDir, withIntermediateDirectories: true)

        let file = userDir.appendingPathComponent("in_progress.json")
        let data = try encoder.encode(outline)
        try data.write(to: file)
    }

    public func deleteOutline(for userId: String) async throws {
        let file = outlinesDirectory
            .appendingPathComponent(userId)
            .appendingPathComponent("in_progress.json")

        if FileManager.default.fileExists(atPath: file.path) {
            try FileManager.default.removeItem(at: file)
        }
    }
}
