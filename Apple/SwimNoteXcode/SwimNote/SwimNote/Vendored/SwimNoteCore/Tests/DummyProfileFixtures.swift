import Foundation

/// Dummy profile fixtures for LLM training plan generation tests.
/// Each profile represents a distinct swimmer with realistic PBs, training history, and goals.
enum DummyProfileFixtures {

// MARK: - Profile Definitions

/// Pre-Competitive — 7-year-old beginner learning all 4 strokes.
/// Weekly: ~3 km, 2 practices. Focus: water comfort, basic streamline.
/// PBs: None yet — still building up to 25m unassisted.
static let preCompetitiveChild = UserProfile(
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
    createdAt: "2026-01-10T09:00:00Z",
    updatedAt: "2026-05-01T09:00:00Z"
)

/// Bronze / Beginner — 10-year-old chasing first legal times.
/// Weekly: ~8 km, 3 practices. Focus: stroke legality, B times.
/// PBs: 50m Free ~45s, 50m Back ~48s
static let bronzeJunior = UserProfile(
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
    createdAt: "2025-09-01T09:00:00Z",
    updatedAt: "2026-04-20T09:00:00Z"
)

/// Silver / Intermediate — 12-year-old working toward A times.
/// Weekly: ~16 km, 4 practices. Focus: aerobic base, technique refinement.
/// PBs: 50m Free ~34s, 100m Free ~1:18, 50m Breast ~40s
static let silverAgeGroup = UserProfile(
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
    createdAt: "2025-06-01T09:00:00Z",
    updatedAt: "2026-05-05T09:00:00Z"
)

/// Gold / Advanced — 14-year-old "Train to Train" phase, Zone qualifier.
/// Weekly: ~30 km, 5 practices. Focus: threshold work, race pace.
/// PBs: 50m Free ~27.5s, 100m Free ~1:01, 200m Free ~2:15
static let goldSeniorAgeGroup = UserProfile(
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
    createdAt: "2024-08-15T09:00:00Z",
    updatedAt: "2026-04-28T09:00:00Z"
)

/// Senior / Competitive — 16-year-old high school varsity, AAA times.
/// Weekly: ~50 km, 7 practices (includes AM/PM doubles). Focus: race strategy, lactate tolerance.
/// PBs: 50m Free ~23.8s, 100m Free ~53.2s, 200m Free ~1:58
static let seniorChampionship = UserProfile(
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
    limitations: ["Shoulder impingement on right side — avoid excessive butterfly volume"],
    revisitNodes: [
        "breaststroke": ["breast_kick_mechanics_whip_kick", "breast_timing_gliding"],
        "butterfly": ["butterfly_08_whole_body_coordination"]
    ],
    createdAt: "2023-09-01T09:00:00Z",
    updatedAt: "2026-05-01T09:00:00Z"
)

/// National / Elite — 19-year-old college D1 swimmer, national qualifier.
/// Weekly: ~65 km, 10 practices. Focus: peak performance, lactate tolerance, race specificity.
/// PBs: 50m Free ~24.9s (LC), 100m Free ~54.3s (LC), 200m Free ~2:00 (LC)
static let nationalElite = UserProfile(
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
    limitations: [],
    revisitNodes: [
        "freestyle": ["free_catch_evf"],
        "master": ["master_start"]
    ],
    createdAt: "2022-06-01T09:00:00Z",
    updatedAt: "2026-04-15T09:00:00Z"
)

// MARK: - All Profiles

static let allProfiles: [UserProfile] = [
    preCompetitiveChild,
    bronzeJunior,
    silverAgeGroup,
    goldSeniorAgeGroup,
    seniorChampionship,
    nationalElite,
]

// MARK: - Helper: Generate JSON for a profile

static func profileJSON(_ profile: UserProfile) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try! encoder.encode(profile)
    return String(data: data, encoding: .utf8)!
}

// MARK: - Helper: Write all profiles to temp directory

static func writeProfilesToDirectory(_ directoryURL: URL) throws {
    let fm = FileManager.default
    if !fm.fileExists(atPath: directoryURL.path) {
        try fm.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }
    for profile in allProfiles {
        let json = profileJSON(profile)
        let fileURL = directoryURL.appendingPathComponent("\(profile.id).json")
        try json.write(to: fileURL, atomically: true, encoding: .utf8)
        print("Wrote: \(fileURL.path)")
    }
}
}
