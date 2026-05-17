import Foundation

/// P3 Step 1 — profile slice extracted from `SwimNoteAppModel` (see `docs/refactors/APPMODEL_SPLIT.md`).
@Observable
@MainActor
public final class ProfileStore {
    public var profiles: [UserProfile] = []
    public var activeProfile: UserProfile?
    public var needsSetup: Bool = true
    public var showingUserSetup: Bool = false

    private let profileRepository: any UserProfileRepository
    private var activeProfileSubscribers: [UUID: AsyncStream<UserProfile?>.Continuation] = [:]

    public init(repository: any UserProfileRepository) {
        self.profileRepository = repository
    }

    private func broadcastActiveProfileChange() {
        let snapshot = activeProfile
        for (_, continuation) in activeProfileSubscribers {
            continuation.yield(snapshot)
        }
    }

    /// Multicast stream: each subscriber receives the current profile immediately, then every change.
    public func subscribeActiveProfileChanges() -> AsyncStream<UserProfile?> {
        AsyncStream(bufferingPolicy: .unbounded) { continuation in
            let id = UUID()
            continuation.yield(self.activeProfile)
            self.activeProfileSubscribers[id] = continuation
            continuation.onTermination = { @Sendable _ in
                Task { @MainActor in
                    self.activeProfileSubscribers[id] = nil
                }
            }
        }
    }

    /// Loads profiles + active id from persistence. Does not load notes/plans (composition root handles that).
    public func loadProfiles() async {
        profiles = await profileRepository.listProfiles()
        if let activeId = await profileRepository.activeProfileId() {
            activeProfile = profiles.first { $0.id == activeId }
        } else {
            activeProfile = nil
        }
        needsSetup = profiles.isEmpty
        broadcastActiveProfileChange()
    }

    public func switchProfile(to profile: UserProfile) async throws {
        activeProfile = profile
        needsSetup = false
        try await profileRepository.setActiveProfile(id: profile.id)
        broadcastActiveProfileChange()
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
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try await profileRepository.save(profile)
        profiles.append(profile)
        needsSetup = profiles.isEmpty
        try await switchProfile(to: profile)
        return profile
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
        let now = Date()
        let timestamp = SwimNoteDateFormatting.string(from: now)
        let effectiveSubTier = trainingTier.clampedSubTier(subTier)

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
        )
        try await profileRepository.save(profile)
        profiles.append(profile)
        needsSetup = profiles.isEmpty
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
        broadcastActiveProfileChange()
    }

    public func deleteProfile(id: String) async throws {
        try await profileRepository.delete(id: id)
        profiles.removeAll { $0.id == id }
        if activeProfile?.id == id {
            activeProfile = profiles.first
            if let newActive = activeProfile {
                try await profileRepository.setActiveProfile(id: newActive.id)
            } else {
                needsSetup = true
            }
        }
        broadcastActiveProfileChange()
    }

    public func seedDemoProfiles() async -> Int {
        let now = Date()
        let timestamp = SwimNoteDateFormatting.string(from: now)
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

        await loadProfiles()
        return seeded
    }
}
