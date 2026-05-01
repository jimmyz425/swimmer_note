import Foundation
import SwiftUI

@Observable
@MainActor
public final class SwimNoteAppModel {
    public var strokes: [Stroke] = []
    public var techniques: [Technique] = []
    public var notes: [TrainingNote] = []
    public var profiles: [UserProfile] = []
    public var activeProfile: UserProfile?
    public var needsSetup: Bool = true
    public var showingUserSetup: Bool = false
    public var selectedTab: AppTab = .dashboard
    public var llmConfiguration: LLMConfiguration?
    public var videoRecords: [VideoAnalysisRecord] = []
    public var trainingPlans: [TrainingPlan] = []
    public var weeklyPlans: [WeeklyTrainingPlan] = []

    // Cached session lookup for O(1) date-based queries
    private var sessionsByDate: [String: DetailedSession] = [:]
    private var dryLandByDate: [String: [DryLandExercisePlan]] = [:]

    private let noteRepository: any TrainingNoteRepository
    private let profileRepository: any UserProfileRepository
    private let planRepository: any TrainingPlanRepository
    private let weeklyPlanRepository: any WeeklyPlanRepository
    private let contentLoader: BundleContentLoader
    private let llmConfigurationStore = LLMConfigurationStore()
    private var parsedContentCache: [String: ParsedTechniqueContent] = [:]
    private var treeCache: [StrokeID: TechniqueTree] = [:]

    public init(
        noteRepository: any TrainingNoteRepository,
        profileRepository: any UserProfileRepository,
        planRepository: any TrainingPlanRepository,
        weeklyPlanRepository: any WeeklyPlanRepository,
        contentLoader: BundleContentLoader
    ) {
        self.noteRepository = noteRepository
        self.profileRepository = profileRepository
        self.planRepository = planRepository
        self.weeklyPlanRepository = weeklyPlanRepository
        self.contentLoader = contentLoader
    }

    public static func bootstrap() -> SwimNoteAppModel {
        let loader = BundleContentLoader.bundled()
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("SwimNote", isDirectory: true)
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("SwimNote", isDirectory: true)

        // Note: Core Data support requires proper model configuration in Xcode
        // For now, JSON repositories remain the default (efficient with date-based caching)

        let model = SwimNoteAppModel(
            noteRepository: JSONTrainingNoteRepository(notesDirectory: appSupport.appendingPathComponent("notes")),
            profileRepository: JSONUserProfileRepository(configDirectory: appSupport.appendingPathComponent("config")),
            planRepository: JSONTrainingPlanRepository(plansDirectory: appSupport.appendingPathComponent("plans")),
            weeklyPlanRepository: JSONWeeklyPlanRepository(plansDirectory: appSupport.appendingPathComponent("weekly-plans")),
            contentLoader: loader
        )
        model.loadBundledContent()
        model.llmConfiguration = model.llmConfigurationStore.load()
        return model
    }

    public func loadProfiles() async {
        profiles = await profileRepository.listProfiles()
        if let activeId = await profileRepository.activeProfileId() {
            activeProfile = profiles.first { $0.id == activeId }
        }
        needsSetup = profiles.isEmpty
        if let profile = activeProfile {
            await reloadNotes(userId: profile.id)

            // Add demo CSS history if profile has none (for demonstration)
            if profile.cssHistory == nil || profile.cssHistory?.isEmpty == true {
                addDemoCSSHistory(to: profile)
            }
        }
    }

    private func addDemoCSSHistory(to profile: UserProfile) {
        var updated = profile
        updated.cssHistory = CSSHistory(
            tests: [
                CSSTestResult(
                    date: "2026-04-15",
                    testType: .twoTrial,
                    strokeId: .freestyle,
                    time200m: 135,
                    time400m: 285,
                    cssMetersPerSecond: 1.33,
                    cssPaceSecondsPer100m: 75.2
                ),
                CSSTestResult(
                    date: "2026-03-01",
                    testType: .twoTrial,
                    strokeId: .freestyle,
                    time200m: 140,
                    time400m: 295,
                    cssMetersPerSecond: 1.29,
                    cssPaceSecondsPer100m: 77.5
                ),
                CSSTestResult(
                    date: "2026-02-01",
                    testType: .twoTrial,
                    strokeId: .freestyle,
                    time200m: 145,
                    time400m: 305,
                    cssMetersPerSecond: 1.23,
                    cssPaceSecondsPer100m: 81.3
                ),
                CSSTestResult(
                    date: "2026-01-15",
                    testType: .twoTrial,
                    strokeId: .freestyle,
                    time200m: 148,
                    time400m: 312,
                    cssMetersPerSecond: 1.19,
                    cssPaceSecondsPer100m: 84.0
                ),
                CSSTestResult(
                    date: "2025-12-01",
                    testType: .twoTrial,
                    strokeId: .freestyle,
                    time200m: 152,
                    time400m: 320,
                    cssMetersPerSecond: 1.15,
                    cssPaceSecondsPer100m: 87.0
                )
            ]
        )

        // Update in-memory (don't save to disk for demo data)
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = updated
        }
        activeProfile = updated
    }

    public func switchProfile(to profile: UserProfile) async throws {
        activeProfile = profile
        try await profileRepository.setActiveProfile(id: profile.id)
        await reloadNotes(userId: profile.id)
    }

    public func createProfile(
        name: String,
        birthday: String,
        sex: Sex,
        mainStroke: StrokeID? = nil,
        distancePreference: DistancePreference = .na,
        preferredDistanceUnit: DistanceUnit = .meters,
        personalBests: PersonalBests,
        weeklySessionTarget: Int = 3,
        profileIconType: ProfileIconType = .letter,
        profileImageData: Data? = nil,
        profileIconName: String? = nil
    ) async throws -> UserProfile {
        let now = Date()
        let timestamp = SwimNoteDateFormatting.string(from: now)
        let profile = UserProfile(
            id: UUID().uuidString,
            name: name,
            birthday: birthday,
            sex: sex,
            skillLevel: personalBests.estimatedSkillLevel(birthday: birthday, sex: sex),
            weeklySessionTarget: weeklySessionTarget,
            preferredStrokes: [],
            mainStroke: mainStroke,
            distancePreference: distancePreference,
            preferredDistanceUnit: preferredDistanceUnit,
            profileIconType: profileIconType,
            profileImageData: profileImageData,
            profileIconName: profileIconName,
            personalBests: personalBests,
            trainingGoals: [],
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try await profileRepository.save(profile)
        profiles.append(profile)
        if profiles.count == 1 {
            try await switchProfile(to: profile)
        }
        return profile
    }

    public func updateProfile(_ profile: UserProfile) async throws {
        var updated = profile
        updated.updatedAt = SwimNoteDateFormatting.string(from: Date())
        updated.skillLevel = profile.personalBests.estimatedSkillLevel(birthday: profile.birthday, sex: profile.sex)
        try await profileRepository.save(updated)
        if let index = profiles.firstIndex(where: { $0.id == updated.id }) {
            profiles[index] = updated
        }
        if activeProfile?.id == updated.id {
            activeProfile = updated
        }
    }

    public func deleteProfile(id: String) async throws {
        try await profileRepository.delete(id: id)
        profiles.removeAll { $0.id == id }
        if activeProfile?.id == id {
            activeProfile = profiles.first
            if let newActive = activeProfile {
                try await profileRepository.setActiveProfile(id: newActive.id)
                await reloadNotes(userId: newActive.id)
            } else {
                needsSetup = true
            }
        }
    }

    public func loadBundledContent() {
        parsedContentCache = [:]
        treeCache = [:]
        strokes = (try? contentLoader.loadStrokes()) ?? StrokeID.allCases
            .filter { $0 != .master && $0 != .im }
            .map { Stroke(id: $0, name: $0.rawValue.capitalized, aliases: []) }
        techniques = (try? contentLoader.loadTechniques()) ?? []
    }

    public func reloadNotes(userId: String) async {
        notes = await noteRepository.listNotes(for: userId)
        trainingPlans = await planRepository.listPlans(for: userId)
        weeklyPlans = await weeklyPlanRepository.listPlans(for: userId)

        // Build date-based caches for O(1) lookup
        rebuildDateCaches()
    }

    private func rebuildDateCaches() {
        sessionsByDate = [:]
        dryLandByDate = [:]

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        for plan in weeklyPlans {
            for session in plan.detailedSessions {
                if let date = session.scheduledDate {
                    let dateKey = formatter.string(from: date)
                    sessionsByDate[dateKey] = session
                }
            }

            if let dryLand = plan.dryLandProgram {
                for exercise in dryLand {
                    if let date = exercise.scheduledDate {
                        let dateKey = formatter.string(from: date)
                        if dryLandByDate[dateKey] == nil {
                            dryLandByDate[dateKey] = []
                        }
                        dryLandByDate[dateKey]?.append(exercise)
                    }
                }
            }
        }
    }

    public func noteForToday() async -> TrainingNote? {
        guard let userId = activeProfile?.id else { return nil }
        let today = SwimNoteDateFormatting.todayShort()
        if let note = await noteRepository.note(for: userId, date: today) {
            return note
        }
        return .empty(userId: userId, date: today)
    }

    public func noteForDate(_ date: String) async -> TrainingNote? {
        guard let userId = activeProfile?.id else { return nil }
        if let note = await noteRepository.note(for: userId, date: date) {
            return note
        }
        return .empty(userId: userId, date: date)
    }

    public func saveNote(_ note: TrainingNote) async {
        try? await noteRepository.save(note)
        if let userId = activeProfile?.id {
            await reloadNotes(userId: userId)
        }
    }

    // MARK: - Weekly Training Plan Methods

    public func saveWeeklyPlan(_ plan: WeeklyTrainingPlan) async throws {
        guard let userId = activeProfile?.id else {
            throw NSError(domain: "SwimNote", code: -1, userInfo: [NSLocalizedDescriptionKey: "No active profile"])
        }

        // Ensure weekStartingDate is set
        var planToSave = plan
        if planToSave.weekStartingDate == nil {
            planToSave.weekStartingDate = Date()
        }

        // Save to disk
        try await weeklyPlanRepository.save(planToSave, for: userId)

        // Don't reload from disk - we already have the correct state in memory
        // The in-memory weeklyPlans array was already updated before calling this function
        // Reloading would overwrite runtime state like isCompleted with stale disk data
    }

    /// Find session scheduled for a specific date
    public func sessionForDate(_ date: String) async -> DetailedSession? {
        guard let userId = activeProfile?.id else { return nil }
        return await weeklyPlanRepository.sessionForDate(for: userId, date: date)
    }

    /// Get the full weekly plan containing a session for a specific date
    public func weeklyPlanForDate(_ date: String) async -> WeeklyTrainingPlan? {
        guard let userId = activeProfile?.id else { return nil }

        // Find the plan that has a session on this date
        let plans = await weeklyPlanRepository.listPlans(for: userId)
        for plan in plans {
            for session in plan.detailedSessions {
                if let sessionDate = session.scheduledDate {
                    let sessionDateStr = SwimNoteDateFormatting.shortDateString(from: sessionDate)
                    if sessionDateStr == date {
                        return plan
                    }
                }
            }
        }
        return nil
    }

    public func planForWeek(weekStarting: String) async -> TrainingPlan? {
        guard let userId = activeProfile?.id else { return nil }
        return await planRepository.plan(for: userId, weekStarting: weekStarting)
    }

    public func saveWeeklyPlan(_ weeklyPlan: WeeklyTrainingPlan, weekStarting: String) async throws {
        guard let userId = activeProfile?.id else {
            throw NSError(domain: "SwimNote", code: -1, userInfo: [NSLocalizedDescriptionKey: "No active profile"])
        }
        let plan = weeklyPlan.toTrainingPlan(userId: userId, weekStarting: weekStarting)
        try await planRepository.save(plan)
        await reloadNotes(userId: userId)
    }

    public func tree(for strokeId: StrokeID) -> TechniqueTree? {
        if let cached = treeCache[strokeId] {
            return cached
        }
        guard let tree = try? contentLoader.loadTechniqueTree(strokeId: strokeId) else {
            return nil
        }
        treeCache[strokeId] = tree
        return tree
    }

    public func markdown(filename: String) -> String {
        (try? contentLoader.loadMarkdown(filename: filename)) ?? ""
    }

    public func parsedTechnique(filename: String) -> ParsedTechniqueContent? {
        if let cached = parsedContentCache[filename] {
            return cached
        }
        guard let parsed = try? contentLoader.loadParsedTechnique(filename: filename) else {
            return nil
        }
        parsedContentCache[filename] = parsed
        return parsed
    }

    public func createToolExecutor() -> CombinedToolExecutor {
        CombinedToolExecutor(
            contentLoader: contentLoader,
            profile: activeProfile,
            notes: notes
        )
    }

    /// Get today's scheduled session as DetailedSession (for proper display with SessionCard)
    public func sessionForDate(_ date: String) -> DetailedSession? {
        // Use cached lookup for O(1) performance
        if let cached = sessionsByDate[date] {
            return cached
        }

        // Fallback: search through plans (for cases where cache isn't built)
        for weeklyPlan in weeklyPlans {
            for session in weeklyPlan.detailedSessions {
                if let sessionDate = session.scheduledDate {
                    let sessionDateStr = SwimNoteDateFormatting.shortDateString(from: sessionDate)
                    if sessionDateStr == date {
                        return session
                    }
                }
            }
        }
        return nil
    }

    /// Get dry land exercises for a specific date (cached)
    public func dryLandForDate(_ date: String) -> [DryLandExercisePlan] {
        return dryLandByDate[date] ?? []
    }

    public func planForDate(_ date: String) -> TrainingPlan? {
        // First check legacy trainingPlans
        if let plan = trainingPlans.first(where: { $0.date == date }) {
            return plan
        }

        // Note: weeklyPlans sessions are handled separately via sessionForDate
        return nil
    }

    public func saveLLMConfiguration(_ configuration: LLMConfiguration?) {
        llmConfiguration = configuration
        llmConfigurationStore.save(configuration)
    }
}

public enum AppTab: String, CaseIterable, Identifiable, Sendable {
    case dashboard = "Today"
    case calendar = "Calendar"
    case tools = "Tools"
    case plan = "Plan"
    case settings = "Settings"

    public var id: String { rawValue }

    public var symbol: String {
        switch self {
        case .dashboard: "figure.pool.swim"
        case .calendar: "calendar.badge.clock"
        case .tools: "wrench.and.screwdriver"
        case .plan: "lightbulb"
        case .settings: "gearshape"
        }
    }
}

