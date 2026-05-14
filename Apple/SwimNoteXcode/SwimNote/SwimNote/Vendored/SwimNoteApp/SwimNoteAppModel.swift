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
    public var measurements: [TechniqueMeasurement] = []
    public var timerSessions: [TimerSession] = []
    public var isInitialized: Bool = false  // Track initialization state

    // Cached session lookup for O(1) date-based queries
    private var sessionsByDate: [String: [DetailedSession]] = [:]
    private var dryLandByDate: [String: [DryLandExercisePlan]] = [:]

    private let noteRepository: any TrainingNoteRepository
    private let profileRepository: any UserProfileRepository
    private let planRepository: any TrainingPlanRepository
    private let weeklyPlanRepository: any WeeklyPlanRepository
    private let measurementRepository: any TechniqueMeasurementRepository
    private let timerSessionRepository: any TimerSessionRepository
    private let outlineRepository: any OutlineRepository
    private let contentLoader: BundleContentLoader
    private let llmConfigurationStore = LLMConfigurationStore()
    private var parsedContentCache: [String: ParsedTechniqueContent] = [:]
    private var treeCache: [StrokeID: TechniqueTree] = [:]
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
        self.profileRepository = profileRepository
        self.planRepository = planRepository
        self.weeklyPlanRepository = weeklyPlanRepository
        self.measurementRepository = measurementRepository
        self.timerSessionRepository = timerSessionRepository
        self.outlineRepository = outlineRepository
        self.contentLoader = contentLoader
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
        profiles = await profileRepository.listProfiles()
        if let activeId = await profileRepository.activeProfileId() {
            activeProfile = profiles.first { $0.id == activeId }
        }
        needsSetup = profiles.isEmpty
        isInitialized = true  // Mark as initialized after loading
        if let profile = activeProfile {
            await reloadNotes(userId: profile.id)
            await reloadMeasurements(userId: profile.id)
            await reloadTimerSessions(userId: profile.id)
            // Note: CSS history is only added when user explicitly does a CSS test
            // No demo data is auto-added
        }
    }

    public func switchProfile(to profile: UserProfile) async throws {
        activeProfile = profile
        needsSetup = false  // No longer need setup once we have an active profile
        try await profileRepository.setActiveProfile(id: profile.id)
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
        let now = Date()
        let timestamp = SwimNoteDateFormatting.string(from: now)
        // Use override if provided, otherwise calculate from PBs
        let skillLevel = skillLevelOverride ?? personalBests.estimatedSkillLevel(birthday: birthday, sex: sex)
        let profile = UserProfile(
            id: UUID().uuidString,
            name: name,
            birthday: birthday,
            sex: sex,
            skillLevel: skillLevel,
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
            // Second createProfile method (trainingTier)
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try await profileRepository.save(profile)
        profiles.append(profile)
        needsSetup = profiles.isEmpty  // Update needsSetup immediately
        // Always switch to newly created profile
        try await switchProfile(to: profile)
        return profile
    }

    /// Create profile with training tier system
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
        let now = Date()
        let timestamp = SwimNoteDateFormatting.string(from: now)
        let effectiveSubTier = subTier == .none ? trainingTier.defaultSubTier : subTier

        let profile = UserProfile(
            id: UUID().uuidString,
            name: name,
            birthday: birthday,
            sex: sex,
            trainingTier: trainingTier,
            subTier: effectiveSubTier,
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
        // First createProfile method (skillLevel)
        )
        try await profileRepository.save(profile)
        profiles.append(profile)
        needsSetup = profiles.isEmpty  // Update needsSetup immediately
        // Always switch to newly created profile
        try await switchProfile(to: profile)
        return profile
    }

    public func updateProfile(_ profile: UserProfile) async throws {
        var updated = profile
        updated.updatedAt = SwimNoteDateFormatting.string(from: Date())
        updated.skillLevel = profile.computedSkillLevel
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

    /// Seed dummy profiles for testing LLM plan generation
    public func seedDemoProfiles() async -> Int {
        let now = Date()
        let timestamp = SwimNoteDateFormatting.string(from: now)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        var seeded = 0

        func seedIfNotExists(id: String, profile: UserProfile) async {
            if await profileRepository.profile(id: id) == nil {
                do {
                    try await profileRepository.save(profile)
                    seeded += 1
                } catch {
                    print("Failed to seed profile \(id): \(error)")
                }
            }
        }

        // 1. Pre-Competitive Child
        await seedIfNotExists(id: "dummy_pre_comp_child_001", profile: UserProfile(
            id: "dummy_pre_comp_child_001",
            name: "Leo Chen",
            birthday: "2019-03-15",
            sex: .male,
            trainingTier: .preCompetitive,
            subTier: .b,
            weeklySessionTarget: 2,
            preferredStrokes: [.freestyle, .backstroke],
            distancePreference: .na,
            personalBests: .empty(),
            trainingGoals: [
                "Complete 25m freestyle with face in water",
                "Learn basic breaststroke kick on back",
                "Hold streamline for 5 seconds off wall"
            ],
            limitations: ["Afraid of deep water", "Cannot do flip turn yet"],
            createdAt: timestamp,
            updatedAt: timestamp
        ))

        // 2. Bronze Junior
        await seedIfNotExists(id: "dummy_bronze_junior_002", profile: UserProfile(
            id: "dummy_bronze_junior_002",
            name: "Mia Rodriguez",
            birthday: "2016-07-22",
            sex: .female,
            trainingTier: .bronze,
            subTier: .two,
            weeklySessionTarget: 3,
            preferredStrokes: [.freestyle, .backstroke],
            mainStroke: .freestyle,
            distancePreference: .short,
            personalBests: PersonalBests(
                freestyle50m: 45.30,
                backstroke50m: 48.70,
                updatedAt: "2026-04-20T00:00:00Z"
            ),
            pbHistory: PBHistory(results: [
                PBResult(date: "2026-04-20", strokeId: .freestyle, distance: 50, time: 45.30, meetName: "Spring Splash", courseType: .shortCourse),
                PBResult(date: "2026-03-15", strokeId: .freestyle, distance: 50, time: 47.80, meetName: "March Madness", courseType: .shortCourse),
                PBResult(date: "2026-04-20", strokeId: .backstroke, distance: 50, time: 48.70, meetName: "Spring Splash", courseType: .shortCourse),
                PBResult(date: "2026-02-10", strokeId: .backstroke, distance: 50, time: 52.10, meetName: "Winter Classic", courseType: .shortCourse),
            ]),
            trainingGoals: [
                "Achieve first B time in 50m freestyle",
                "Legal breaststroke kick in all strokes",
                "Improve flip turn consistency"
            ],
            createdAt: timestamp,
            updatedAt: timestamp
        ))

        // 3. Silver Age Group
        await seedIfNotExists(id: "dummy_silver_agegroup_003", profile: UserProfile(
            id: "dummy_silver_agegroup_003",
            name: "Ethan Park",
            birthday: "2014-01-08",
            sex: .male,
            trainingTier: .silver,
            subTier: .two,
            weeklySessionTarget: 4,
            preferredStrokes: [.freestyle, .breaststroke],
            mainStroke: .freestyle,
            distancePreference: .mid,
            personalBests: PersonalBests(
                freestyle50m: 34.20,
                backstroke50m: 39.50,
                breaststroke50m: 40.80,
                butterfly50m: 38.90,
                updatedAt: "2026-05-05T00:00:00Z"
            ),
            pbHistory: PBHistory(results: [
                PBResult(date: "2026-05-05", strokeId: .freestyle, distance: 50, time: 34.20, meetName: "May Open", courseType: .shortCourse),
                PBResult(date: "2026-03-22", strokeId: .freestyle, distance: 50, time: 35.60, meetName: "Spring Champs", courseType: .shortCourse),
                PBResult(date: "2025-12-01", strokeId: .freestyle, distance: 50, time: 37.40, meetName: "Winter Invitational", courseType: .shortCourse),
                PBResult(date: "2026-05-05", strokeId: .breaststroke, distance: 50, time: 40.80, meetName: "May Open", courseType: .shortCourse),
                PBResult(date: "2026-03-22", strokeId: .breaststroke, distance: 50, time: 42.30, meetName: "Spring Champs", courseType: .shortCourse),
                PBResult(date: "2026-05-05", strokeId: .butterfly, distance: 50, time: 38.90, meetName: "May Open", courseType: .shortCourse),
                PBResult(date: "2026-01-18", strokeId: .butterfly, distance: 50, time: 41.50, meetName: "New Year Classic", courseType: .shortCourse),
                PBResult(date: "2026-05-05", strokeId: .backstroke, distance: 50, time: 39.50, meetName: "May Open", courseType: .shortCourse),
            ]),
            cssHistory: CSSHistory(tests: [
                CSSTestResult(
                    date: "2026-04-15",
                    testType: .twoTrial,
                    strokeId: .freestyle,
                    time200m: 158.0,
                    time400m: 332.0,
                    cssMetersPerSecond: 1.15,
                    cssPaceSecondsPer100m: 87.0
                ),
                CSSTestResult(
                    date: "2026-01-20",
                    testType: .twoTrial,
                    strokeId: .freestyle,
                    time200m: 166.0,
                    time400m: 350.0,
                    cssMetersPerSecond: 1.09,
                    cssPaceSecondsPer100m: 91.7
                ),
            ]),
            trainingGoals: [
                "Break 34s in 50m freestyle (A time target)",
                "Improve underwater pullout distance in breaststroke",
                "Consistent 6-beat kick in freestyle",
                "Legal butterfly kick in all four strokes"
            ],
            revisitNodes: [
                "freestyle": ["free_breathing_technique", "free_catch_evf"],
                "breaststroke": ["breast_timing_gliding"]
            ],
            createdAt: timestamp,
            updatedAt: timestamp
        ))

        // 4. Gold Senior Age Group
        await seedIfNotExists(id: "dummy_gold_train2train_004", profile: UserProfile(
            id: "dummy_gold_train2train_004",
            name: "Sophie Andersen",
            birthday: "2012-05-30",
            sex: .female,
            trainingTier: .gold,
            weeklySessionTarget: 5,
            preferredStrokes: [.freestyle, .backstroke, .butterfly],
            mainStroke: .freestyle,
            distancePreference: .mid,
            personalBests: PersonalBests(
                freestyle50m: 27.50,
                backstroke50m: 32.80,
                breaststroke50m: 37.20,
                butterfly50m: 30.40,
                updatedAt: "2026-04-28T00:00:00Z"
            ),
            pbHistory: PBHistory(results: [
                PBResult(date: "2026-04-28", strokeId: .freestyle, distance: 50, time: 27.50, meetName: "Zone Qualifier", courseType: .shortCourse),
                PBResult(date: "2026-04-28", strokeId: .freestyle, distance: 100, time: 61.20, meetName: "Zone Qualifier", courseType: .shortCourse),
                PBResult(date: "2026-03-10", strokeId: .freestyle, distance: 200, time: 135.0, meetName: "Sectional", courseType: .shortCourse),
                PBResult(date: "2026-04-28", strokeId: .backstroke, distance: 50, time: 32.80, meetName: "Zone Qualifier", courseType: .shortCourse),
                PBResult(date: "2026-04-28", strokeId: .butterfly, distance: 50, time: 30.40, meetName: "Zone Qualifier", courseType: .shortCourse),
                PBResult(date: "2026-02-15", strokeId: .butterfly, distance: 50, time: 32.10, meetName: "February Open", courseType: .shortCourse),
                PBResult(date: "2026-04-28", strokeId: .breaststroke, distance: 50, time: 37.20, meetName: "Zone Qualifier", courseType: .shortCourse),
            ]),
            cssHistory: CSSHistory(tests: [
                CSSTestResult(
                    date: "2026-04-10",
                    testType: .twoTrial,
                    strokeId: .freestyle,
                    time200m: 132.0,
                    time400m: 280.0,
                    cssMetersPerSecond: 1.35,
                    cssPaceSecondsPer100m: 74.1
                ),
                CSSTestResult(
                    date: "2026-01-15",
                    testType: .twoTrial,
                    strokeId: .freestyle,
                    time200m: 138.0,
                    time400m: 292.0,
                    cssMetersPerSecond: 1.30,
                    cssPaceSecondsPer100m: 76.9
                ),
                CSSTestResult(
                    date: "2025-10-01",
                    testType: .twoTrial,
                    strokeId: .freestyle,
                    time200m: 144.0,
                    time400m: 306.0,
                    cssMetersPerSecond: 1.25,
                    cssPaceSecondsPer100m: 80.0
                ),
            ]),
            trainingGoals: [
                "Break 1:00 in 100m freestyle",
                "Improve underwater dolphin kick off turns (5+ kicks per wall)",
                "AA time in 50m butterfly",
                "Reduce stroke count from 18 to 16 per 25m at race pace"
            ],
            revisitNodes: [
                "freestyle": ["free_catch_evf", "free_pull_phase"],
                "butterfly": ["butterfly_02_dolphin_kick_mechanics"]
            ],
            createdAt: timestamp,
            updatedAt: timestamp
        ))

        // 5. Senior Championship
        await seedIfNotExists(id: "dummy_senior_championship_005", profile: UserProfile(
            id: "dummy_senior_championship_005",
            name: "Jake Thompson",
            birthday: "2010-02-14",
            sex: .male,
            trainingTier: .senior,
            weeklySessionTarget: 7,
            preferredStrokes: [.freestyle, .butterfly, .im],
            mainStroke: .im,
            distancePreference: .mid,
            personalBests: PersonalBests(
                freestyle50m: 23.80,
                backstroke50m: 28.50,
                breaststroke50m: 31.20,
                butterfly50m: 25.60,
                updatedAt: "2026-05-01T00:00:00Z"
            ),
            pbHistory: PBHistory(results: [
                PBResult(date: "2026-05-01", strokeId: .freestyle, distance: 50, time: 23.80, meetName: "State Champs", courseType: .shortCourse),
                PBResult(date: "2026-05-01", strokeId: .freestyle, distance: 100, time: 53.20, meetName: "State Champs", courseType: .shortCourse),
                PBResult(date: "2026-03-15", strokeId: .freestyle, distance: 200, time: 118.0, meetName: "Sectional", courseType: .shortCourse),
                PBResult(date: "2026-05-01", strokeId: .butterfly, distance: 50, time: 25.60, meetName: "State Champs", courseType: .shortCourse),
                PBResult(date: "2026-05-01", strokeId: .butterfly, distance: 100, time: 57.80, meetName: "State Champs", courseType: .shortCourse),
                PBResult(date: "2026-03-15", strokeId: .butterfly, distance: 100, time: 59.40, meetName: "Sectional", courseType: .shortCourse),
                PBResult(date: "2026-05-01", strokeId: .backstroke, distance: 50, time: 28.50, meetName: "State Champs", courseType: .shortCourse),
                PBResult(date: "2026-05-01", strokeId: .backstroke, distance: 100, time: 63.20, meetName: "State Champs", courseType: .shortCourse),
                PBResult(date: "2026-05-01", strokeId: .breaststroke, distance: 50, time: 31.20, meetName: "State Champs", courseType: .shortCourse),
                PBResult(date: "2026-05-01", strokeId: .breaststroke, distance: 100, time: 69.50, meetName: "State Champs", courseType: .shortCourse),
                PBResult(date: "2025-11-10", strokeId: .freestyle, distance: 50, time: 24.50, meetName: "November Open", courseType: .shortCourse),
                PBResult(date: "2025-11-10", strokeId: .freestyle, distance: 100, time: 54.80, meetName: "November Open", courseType: .shortCourse),
            ]),
            cssHistory: CSSHistory(tests: [
                CSSTestResult(
                    date: "2026-04-01",
                    testType: .twoTrial,
                    strokeId: .freestyle,
                    time200m: 114.0,
                    time400m: 242.0,
                    cssMetersPerSecond: 1.56,
                    cssPaceSecondsPer100m: 64.1
                ),
                CSSTestResult(
                    date: "2026-01-10",
                    testType: .twoTrial,
                    strokeId: .freestyle,
                    time200m: 117.0,
                    time400m: 248.0,
                    cssMetersPerSecond: 1.52,
                    cssPaceSecondsPer100m: 65.8
                ),
            ]),
            trainingGoals: [
                "Break 53s in 100m freestyle (AAAA target)",
                "Break 57s in 100m butterfly",
                "Improve breaststroke split in IM (currently weakest leg)",
                "Qualify for Junior Nationals in 200m IM"
            ],
            limitations: ["Shoulder impingement on right side - avoid excessive butterfly volume"],
            revisitNodes: [
                "breaststroke": ["breast_kick_mechanics_whip_kick", "breast_timing_gliding"],
                "butterfly": ["butterfly_08_whole_body_coordination"]
            ],
            createdAt: timestamp,
            updatedAt: timestamp
        ))

        // 6. National Elite
        await seedIfNotExists(id: "dummy_national_elite_006", profile: UserProfile(
            id: "dummy_national_elite_006",
            name: "Yuki Tanaka",
            birthday: "2007-09-03",
            sex: .female,
            trainingTier: .national,
            weeklySessionTarget: 10,
            preferredStrokes: [.freestyle, .butterfly],
            mainStroke: .freestyle,
            distancePreference: .short,
            personalBests: PersonalBests(
                freestyle50m: 24.90,
                backstroke50m: 29.80,
                breaststroke50m: 34.50,
                butterfly50m: 26.80,
                updatedAt: "2026-04-15T00:00:00Z"
            ),
            pbHistory: PBHistory(results: [
                PBResult(date: "2026-04-15", strokeId: .freestyle, distance: 50, time: 24.90, meetName: "NCAA Champs", courseType: .longCourse),
                PBResult(date: "2026-04-15", strokeId: .freestyle, distance: 100, time: 54.30, meetName: "NCAA Champs", courseType: .longCourse),
                PBResult(date: "2026-04-15", strokeId: .freestyle, distance: 200, time: 120.0, meetName: "NCAA Champs", courseType: .longCourse),
                PBResult(date: "2026-04-15", strokeId: .butterfly, distance: 50, time: 26.80, meetName: "NCAA Champs", courseType: .longCourse),
                PBResult(date: "2026-04-15", strokeId: .butterfly, distance: 100, time: 59.20, meetName: "NCAA Champs", courseType: .longCourse),
                PBResult(date: "2026-04-15", strokeId: .backstroke, distance: 50, time: 29.80, meetName: "NCAA Champs", courseType: .longCourse),
                PBResult(date: "2026-04-15", strokeId: .breaststroke, distance: 50, time: 34.50, meetName: "NCAA Champs", courseType: .longCourse),
                PBResult(date: "2025-08-20", strokeId: .freestyle, distance: 50, time: 25.40, meetName: "Summer Nationals", courseType: .longCourse),
                PBResult(date: "2025-08-20", strokeId: .freestyle, distance: 100, time: 55.80, meetName: "Summer Nationals", courseType: .longCourse),
            ]),
            cssHistory: CSSHistory(tests: [
                CSSTestResult(
                    date: "2026-03-20",
                    testType: .twoTrial,
                    strokeId: .freestyle,
                    time200m: 110.0,
                    time400m: 230.0,
                    cssMetersPerSecond: 1.67,
                    cssPaceSecondsPer100m: 59.9
                ),
                CSSTestResult(
                    date: "2025-12-10",
                    testType: .twoTrial,
                    strokeId: .freestyle,
                    time200m: 114.0,
                    time400m: 238.0,
                    cssMetersPerSecond: 1.61,
                    cssPaceSecondsPer100m: 62.1
                ),
            ]),
            trainingGoals: [
                "Break 24.5s in 50m freestyle (Olympic Trials cut)",
                "Break 58s in 100m butterfly (LC)",
                "Maintain sub-1:00 CSS pace through taper",
                "Improve reaction time off blocks (currently 0.72s, target 0.65s)"
            ],
            createdAt: timestamp,
            updatedAt: timestamp
        ))

        // Reload profiles from repository
        await loadProfiles()
        return seeded
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

        Return ONLY a JSON array of strings, nothing else. Example: ["Speedboat", "Stay on top of the water", "Flat on the water"]
        """

        let userPrompt = """
        Stroke: \(strokeName)
        Focus area: \(goalDescription)

        Look up external focus cues for this focus area and return 3-5 cues as a JSON array.
        """

        let tools = ResourcesNavigationTools.all.filter { $0.function.name == "get_external_focus_cues" } + [getFocusAreaCuesTool()]

        do {
            let result = try await conversation.run(
                systemRole: systemPrompt,
                userPrompt: userPrompt,
                tools: tools,
                maxIterations: 3
            )

            // Parse JSON array response
            let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
            let jsonText = trimmed.hasPrefix("[") ? trimmed : trimmed.components(separatedBy: "\n").first { $0.trimmingCharacters(in: .whitespaces).hasPrefix("[") }?.trimmingCharacters(in: .whitespaces) ?? trimmed

            if let data = jsonText.data(using: .utf8),
               let cues = try? JSONSerialization.jsonObject(with: data) as? [String] {
                return cues
            }

            return nil
        } catch {
            #if DEBUG
            print("🔧 Focus cues generation failed: \(error)")
            #endif
            return nil
        }
    }

    // Helper tool: get focus area cues by description matching
    private func getFocusAreaCuesTool() -> Tool {
        Tool(
            function: ToolFunction(
                name: "get_focus_area_cues",
                description: "Get external focus cues for a specific issue within a stroke. Returns matching cues from the coaching cue library.",
                parameters: JSONSchema(
                    properties: [
                        "stroke": JSONSchemaProperty(type: "string", description: "Stroke name: freestyle, backstroke, breaststroke, butterfly, starts, turns"),
                        "issue": JSONSchemaProperty(type: "string", description: "The specific technique issue to find cues for (e.g. 'hips sinking', 'head too high', 'no body rotation')")
                    ],
                    required: ["stroke", "issue"],
                    additionalProperties: false
                ),
                strict: true
            )
        )
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

    public func createToolExecutor(referenceDate: Date? = nil) -> CombinedToolExecutor {
        CombinedToolExecutor(
            contentLoader: contentLoader,
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

