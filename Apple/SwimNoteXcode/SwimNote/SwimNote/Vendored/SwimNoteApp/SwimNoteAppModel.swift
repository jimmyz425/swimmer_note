import Foundation
import SwiftUI

@Observable
@MainActor
public final class SwimNoteAppModel {
    public let profileStore: ProfileStore
    public let contentStore: ContentStore

    // P3 Step 2: bundle content lives in `ContentStore`; facade keeps call sites stable.
    public var strokes: [Stroke] {
        get { contentStore.strokes }
    }
    public var techniques: [Technique] {
        get { contentStore.techniques }
    }
    public var notes: [TrainingNote] = []

    // P3: forward profile slice to `ProfileStore` (RFC Step 1 facade).
    public var profiles: [UserProfile] {
        get { profileStore.profiles }
    }
    public var activeProfile: UserProfile? {
        get { profileStore.activeProfile }
    }
    public var needsSetup: Bool {
        get { profileStore.needsSetup }
        set { profileStore.needsSetup = newValue }
    }
    public var showingUserSetup: Bool {
        get { profileStore.showingUserSetup }
        set { profileStore.showingUserSetup = newValue }
    }

    public var selectedTab: AppTab = .dashboard
    public var llmConfiguration: LLMConfiguration?
    public var videoRecords: [VideoAnalysisRecord] = []
    public var trainingPlans: [TrainingPlan] = []
    public var weeklyPlans: [WeeklyTrainingPlan] = []
    public var measurements: [TechniqueMeasurement] = []
    public var timerSessions: [TimerSession] = []
    public var isInitialized: Bool = false  // Track initialization state

    // Cached session lookup for O(1) date-based queries
    private var sessionsByDate: [String: [DetailedSession]] = [:]
    private var dryLandByDate: [String: [DryLandExercisePlan]] = [:]

    private let noteRepository: any TrainingNoteRepository
    private let planRepository: any TrainingPlanRepository
    private let weeklyPlanRepository: any WeeklyPlanRepository
    private let measurementRepository: any TechniqueMeasurementRepository
    private let timerSessionRepository: any TimerSessionRepository
    private let outlineRepository: any OutlineRepository
    private let llmConfigurationStore = LLMConfigurationStore()
    private let credentialStore: any SecureCredentialStore = {
        #if canImport(Security)
        KeychainCredentialStore()
        #else
        InMemoryCredentialStore()
        #endif
    }()

    public init(
        noteRepository: any TrainingNoteRepository,
        profileRepository: any UserProfileRepository,
        planRepository: any TrainingPlanRepository,
        weeklyPlanRepository: any WeeklyPlanRepository,
        measurementRepository: any TechniqueMeasurementRepository,
        timerSessionRepository: any TimerSessionRepository,
        outlineRepository: any OutlineRepository,
        contentLoader: BundleContentLoader
    ) {
        self.noteRepository = noteRepository
        self.profileStore = ProfileStore(repository: profileRepository)
        self.contentStore = ContentStore(contentLoader: contentLoader)
        self.planRepository = planRepository
        self.weeklyPlanRepository = weeklyPlanRepository
        self.measurementRepository = measurementRepository
        self.timerSessionRepository = timerSessionRepository
        self.outlineRepository = outlineRepository
    }

    public static func bootstrap() -> SwimNoteAppModel {
        let loader = BundleContentLoader.bundled()
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("SwimNote", isDirectory: true)
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("SwimNote", isDirectory: true)

        // Core Data persistence (local only, no CloudKit)
        let coreDataURL = appSupport.appendingPathComponent("SwimNote.sqlite")
        let controller = CoreDataPersistenceController(modelName: "SwimNote", storageURL: coreDataURL)

        // Use Core Data repositories
        let model = SwimNoteAppModel(
            noteRepository: CoreDataTrainingNoteRepository(controller: controller),
            profileRepository: CoreDataUserProfileRepository(controller: controller),
            planRepository: JSONTrainingPlanRepository(plansDirectory: appSupport.appendingPathComponent("plans")),
            weeklyPlanRepository: CoreDataWeeklyPlanRepository(controller: controller),
            measurementRepository: CoreDataTechniqueMeasurementRepository(controller: controller),
            timerSessionRepository: CoreDataTimerSessionRepository(controller: controller),
            outlineRepository: JSONOutlineRepository(outlinesDirectory: appSupport.appendingPathComponent("outlines")),
            contentLoader: loader
        )

        // Initialize Core Data synchronously on main thread before any operations
        Task { @MainActor in
            // Load Core Data store
            try? await controller.load()

            // Run migration from JSON if needed (only runs once)
            if CoreDataMigration.needsMigration() {
                let migration = CoreDataMigration(controller: controller, appSupportURL: appSupport)
                try? await migration.migrateAll()
            }

            // Now load profiles from Core Data
            await model.loadProfiles()
        }

        model.loadBundledContent()
        model.llmConfiguration = model.llmConfigurationStore.load()
        return model
    }

    public func loadProfiles() async {
        await profileStore.loadProfiles()
        isInitialized = true
        if let profile = profileStore.activeProfile {
            await reloadNotes(userId: profile.id)
            await reloadMeasurements(userId: profile.id)
            await reloadTimerSessions(userId: profile.id)
        }
    }

    public func switchProfile(to profile: UserProfile) async throws {
        try await profileStore.switchProfile(to: profile)
        await reloadNotes(userId: profile.id)
        await reloadMeasurements(userId: profile.id)
        await reloadTimerSessions(userId: profile.id)
    }

    public func createProfile(
        name: String,
        birthday: String,
        sex: Sex,
        mainStroke: StrokeID? = nil,
        distancePreference: DistancePreference = .na,
        preferredDistanceUnit: DistanceUnit = .meters,
        personalBests: PersonalBests = .empty(),
        skillLevelOverride: SkillLevel? = nil,
        weeklySessionTarget: Int = 3,
        profileIconType: ProfileIconType = .letter,
        profileImageData: Data? = nil,
        profileIconName: String? = nil
    ) async throws -> UserProfile {
        let p = try await profileStore.createProfile(
            name: name,
            birthday: birthday,
            sex: sex,
            mainStroke: mainStroke,
            distancePreference: distancePreference,
            preferredDistanceUnit: preferredDistanceUnit,
            personalBests: personalBests,
            skillLevelOverride: skillLevelOverride,
            weeklySessionTarget: weeklySessionTarget,
            profileIconType: profileIconType,
            profileImageData: profileImageData,
            profileIconName: profileIconName
        )
        await reloadNotes(userId: p.id)
        await reloadMeasurements(userId: p.id)
        await reloadTimerSessions(userId: p.id)
        return p
    }

    public func createProfile(
        name: String,
        birthday: String,
        sex: Sex,
        mainStroke: StrokeID? = nil,
        distancePreference: DistancePreference = .na,
        preferredDistanceUnit: DistanceUnit = .meters,
        personalBests: PersonalBests = .empty(),
        trainingTier: TrainingTier,
        subTier: SubTier = .none,
        weeklySessionTarget: Int = 3,
        profileIconType: ProfileIconType = .letter,
        profileImageData: Data? = nil,
        profileIconName: String? = nil
    ) async throws -> UserProfile {
        let p = try await profileStore.createProfile(
            name: name,
            birthday: birthday,
            sex: sex,
            mainStroke: mainStroke,
            distancePreference: distancePreference,
            preferredDistanceUnit: preferredDistanceUnit,
            personalBests: personalBests,
            trainingTier: trainingTier,
            subTier: subTier,
            weeklySessionTarget: weeklySessionTarget,
            profileIconType: profileIconType,
            profileImageData: profileImageData,
            profileIconName: profileIconName
        )
        await reloadNotes(userId: p.id)
        await reloadMeasurements(userId: p.id)
        await reloadTimerSessions(userId: p.id)
        return p
    }

    public func updateProfile(_ profile: UserProfile) async throws {
        try await profileStore.updateProfile(profile)
    }

    public func deleteProfile(id: String) async throws {
        try await profileStore.deleteProfile(id: id)
        if let newActive = profileStore.activeProfile {
            await reloadNotes(userId: newActive.id)
        }
    }

    public func seedDemoProfiles() async -> Int {
        let count = await profileStore.seedDemoProfiles()
        await loadProfiles()
        return count
    }

    public func loadBundledContent() {
        contentStore.loadBundledContent()
    }

    public func reloadNotes(userId: String) async {
        notes = await noteRepository.listNotes(for: userId)
        trainingPlans = await planRepository.listPlans(for: userId)
        weeklyPlans = await weeklyPlanRepository.listPlans(for: userId)

        // Build date-based caches for O(1) lookup
        rebuildDateCaches()
    }

    public func reloadMeasurements(userId: String) async {
        measurements = await measurementRepository.list(for: userId)
    }

    public func saveMeasurement(_ measurement: TechniqueMeasurement) async throws {
        try await measurementRepository.save(measurement)
        await reloadMeasurements(userId: measurement.userId)
    }

    public func deleteMeasurement(id: String) async throws {
        try await measurementRepository.delete(id: id)
        if let userId = activeProfile?.id {
            await reloadMeasurements(userId: userId)
        }
    }

    public func reloadTimerSessions(userId: String) async {
        timerSessions = await timerSessionRepository.list(for: userId)
    }

    public func saveTimerSession(_ session: TimerSession) async throws {
        try await timerSessionRepository.save(session)
        await reloadTimerSessions(userId: session.userId)
    }

    public func deleteTimerSession(id: String) async throws {
        try await timerSessionRepository.delete(id: id)
        if let userId = activeProfile?.id {
            await reloadTimerSessions(userId: userId)
        }
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
                    if sessionsByDate[dateKey] == nil {
                        sessionsByDate[dateKey] = []
                    }
                    sessionsByDate[dateKey]?.append(session)
                }
            }

            // Sort sessions by time of day (morning → afternoon → evening)
            for dateKey in sessionsByDate.keys {
                sessionsByDate[dateKey]?.sort { first, second in
                    let firstOrder = first.timeOfDay?.rawValue ?? "morning"
                    let secondOrder = second.timeOfDay?.rawValue ?? "morning"
                    return firstOrder < secondOrder
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

    // MARK: - LLM Focus Cues Generation

    public func generateFocusCues(for goal: Goal, stroke: StrokeID?) async -> [String]? {
        guard let config = llmConfiguration else { return nil }

        let apiKey: String
        do {
            guard let key = try credentialStore.load(account: config.apiKeyReference) else {
                return nil
            }
            apiKey = key
        } catch {
            return nil
        }

        let executor = createToolExecutor()
        let conversation = ToolCallingConversation(
            configuration: config,
            apiKey: apiKey,
            executor: executor
        )

        let strokeName = stroke?.rawValue.capitalized ?? "General"
        let goalDescription = goal.description

        let systemPrompt = """
        You are an expert swimming coach assistant. Your task is to generate 3-5 external focus cues for a specific swimming focus area.

        External focus cues are short, memorable phrases that help swimmers feel and execute correct movement patterns. They should be:
        - Concrete and actionable (not technical jargon)
        - Easy to remember during swimming
        - Focused on the EFFECT or OUTCOME, not body mechanics
        - Age-appropriate (you can use images, feelings, targets, rhythms)

        Use the get_external_focus_cues tool to look up cues for the given stroke and issue. Then select 3-5 that best match the swimmer's focus area. You can adapt or combine them, but keep them short and punchy.

        Return a single JSON array of strings only (no markdown fences, no commentary). Example: ["Speedboat", "Stay on top of the water", "Flat on the water"]
        """

        let userPrompt = """
        Stroke: \(strokeName)
        Focus area: \(goalDescription)

        Look up external focus cues for this focus area and return 3-5 cues as a JSON array.
        """

        // Only `get_external_focus_cues` — executor implements it (see CombinedToolExecutor).
        // A duplicate `get_focus_area_cues` registration previously caused unknownTool + iteration burn.
        let tools = ResourcesNavigationTools.all.filter { $0.function.name == "get_external_focus_cues" }

        do {
            let result = try await conversation.run(
                systemRole: systemPrompt,
                userPrompt: userPrompt,
                tools: tools,
                maxIterations: 16,
                maxTokens: 4096
            )

            return Self.parseFocusCuesJSONArray(from: result)
        } catch {
            #if DEBUG
            print("🔧 Focus cues generation failed: \(error)")
            #endif
            return nil
        }
    }

    /// Extracts `["cue", ...]` from model output: tolerates markdown fences, leading labels, and multi-line JSON.
    private static func parseFocusCuesJSONArray(from raw: String) -> [String]? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            text.removeFirst(3)
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.lowercased().hasPrefix("json") {
                text.removeFirst(4)
                text = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            }
            if let fence = text.range(of: "```", options: .backwards) {
                text = String(text[..<fence.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        guard let open = text.firstIndex(of: "["),
              let close = text.lastIndex(of: "]"),
              open < close
        else { return nil }

        let slice = String(text[open...close])
        guard let data = slice.data(using: .utf8) else { return nil }

        if let cues = try? JSONSerialization.jsonObject(with: data) as? [String] {
            return cues
        }
        if let any = try? JSONSerialization.jsonObject(with: data) as? [Any] {
            let strings = any.compactMap { $0 as? String }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            return strings.isEmpty ? nil : strings
        }
        return nil
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

        // Save to Core Data
        try await weeklyPlanRepository.save(planToSave, for: userId)

        // Reload from repository to ensure in-memory state matches Core Data
        await reloadNotes(userId: userId)
    }

    /// Find all sessions scheduled for a specific date
    public func sessionsForDate(_ date: String) async -> [DetailedSession] {
        guard let userId = activeProfile?.id else { return [] }
        return await weeklyPlanRepository.sessionsForDate(for: userId, date: date)
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

    // MARK: - Outline Persistence (for in-progress generation)

    public func loadOutline() async -> WeeklyPlanOutline? {
        guard let userId = activeProfile?.id else { return nil }
        return await outlineRepository.loadOutline(for: userId)
    }

    public func saveOutline(_ outline: WeeklyPlanOutline) async throws {
        guard let userId = activeProfile?.id else {
            throw NSError(domain: "SwimNote", code: -1, userInfo: [NSLocalizedDescriptionKey: "No active profile"])
        }
        try await outlineRepository.saveOutline(outline, for: userId)
    }

    public func deleteOutline() async throws {
        guard let userId = activeProfile?.id else { return }
        try await outlineRepository.deleteOutline(for: userId)
    }

    public func tree(for strokeId: StrokeID) -> TechniqueTree? {
        contentStore.tree(for: strokeId)
    }

    public func markdown(filename: String) -> String {
        contentStore.markdown(filename: filename)
    }

    public func parsedTechnique(filename: String) -> ParsedTechniqueContent? {
        contentStore.parsedTechnique(filename: filename)
    }

    public func createToolExecutor(referenceDate: Date? = nil) -> CombinedToolExecutor {
        CombinedToolExecutor(
            contentLoader: contentStore.bundleContentLoader,
            profile: activeProfile,
            notes: notes,
            referenceDate: referenceDate
        )
    }

    /// Get all sessions scheduled for a specific date (cached)
    public func sessionsForDate(_ date: String) -> [DetailedSession] {
        // Use cached lookup for O(1) performance
        if let cached = sessionsByDate[date] {
            return cached
        }

        // Fallback: search through plans (for cases where cache isn't built)
        var matching: [DetailedSession] = []
        for weeklyPlan in weeklyPlans {
            for session in weeklyPlan.detailedSessions {
                if let sessionDate = session.scheduledDate {
                    let sessionDateStr = SwimNoteDateFormatting.shortDateString(from: sessionDate)
                    if sessionDateStr == date {
                        matching.append(session)
                    }
                }
            }
        }
        // Sort by time of day
        return matching.sorted { first, second in
            let firstOrder = first.timeOfDay?.rawValue ?? "morning"
            let secondOrder = second.timeOfDay?.rawValue ?? "morning"
            return firstOrder < secondOrder
        }
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

        // Note: weeklyPlans sessions are handled separately via sessionsForDate
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

