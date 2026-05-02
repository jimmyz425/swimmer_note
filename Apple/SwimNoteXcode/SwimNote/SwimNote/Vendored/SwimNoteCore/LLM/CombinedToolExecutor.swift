import Foundation

// MARK: - Combined Tool Executor

public final class CombinedToolExecutor: Sendable {
    private let contentLoader: BundleContentLoader
    private let markdownParser = TechniqueMarkdownParser()
    private let profile: UserProfile?
    private let notes: [TrainingNote]

    public init(
        contentLoader: BundleContentLoader,
        profile: UserProfile?,
        notes: [TrainingNote]
    ) {
        self.contentLoader = contentLoader
        self.profile = profile
        self.notes = notes
    }

    public func execute(_ toolCall: ToolCall) async throws -> String {
        let args = try parseArguments(toolCall)

        switch toolCall.function.name {
        // Resources navigation tools
        case "list_technique_files":
            return try listTechniqueFiles(stroke: args["stroke"] as? String)
        case "read_technique_file":
            return try readTechniqueFile(filename: args["filename"] as? String)
        case "search_content":
            return try searchContent(query: args["query"] as? String, stroke: args["stroke"] as? String)
        case "get_related_techniques":
            return try getRelatedTechniques(filename: args["filename"] as? String)

        // User data tools
        case "get_user_profile":
            return try getUserProfile()
        case "get_training_history":
            return try getTrainingHistory(
                days: args["days"] as? Int ?? 7,
                includeGoals: args["include_goals"] as? Bool ?? true
            )
        case "get_active_goals":
            return try getActiveGoals()
        case "get_training_calendar":
            return try getTrainingCalendar(weeks: args["weeks"] as? Int ?? 4)

        // CSS and interval training tools
        case "get_css_info":
            return try getCSSInfo(stroke: args["stroke"] as? String)
        case "read_interval_research":
            return try readIntervalResearch(section: args["section"] as? String)

        // Tier guidance tool
        case "get_tier_guidance":
            return try getTierGuidance()

        default:
            throw ToolError.unknownTool(toolCall.function.name)
        }
    }

    // MARK: - Resources Navigation Tools

    private func listTechniqueFiles(stroke: String?) throws -> String {
        let allFiles = try contentLoader.listTechniqueMarkdownFiles()

        let filteredFiles: [TechniqueFileInfo]
        if let stroke {
            filteredFiles = allFiles.filter { $0.stroke == stroke }
        } else {
            filteredFiles = allFiles
        }

        // Concise format - just filename and title
        let result = filteredFiles.map { file -> [String: String] in
            [
                "filename": file.filename,
                "stroke": file.stroke,
                "title": file.title
            ]
        }

        return try encodeJSON(result)
    }

    private func readTechniqueFile(filename: String?) throws -> String {
        guard let filename else {
            throw ToolError.missingParameter("filename")
        }

        let normalizedFilename = filename.hasSuffix(".md") ? filename : "\(filename).md"

        let content = try contentLoader.loadMarkdown(filename: normalizedFilename)
        let parsed = markdownParser.parse(filename: normalizedFilename, rawContent: content)

        // Combine drills into a simple format
        var allDrills: [[String: Any]] = []

        // Specific drills
        for drill in parsed.specificDrills {
            allDrills.append([
                "name": drill.name,
                "type": "specific",
                "description": String(drill.description.prefix(100))
            ])
        }

        // Competitive drills with tiered targets
        for drill in parsed.competitiveDrills {
            allDrills.append([
                "name": drill.name,
                "type": "competitive",
                "targets": drill.tieredTargets
            ])
        }

        // Build result with navigation links
        var result: [String: Any] = [
            "filename": normalizedFilename,
            "title": parsed.title,
            "difficulty": parsed.difficulty,
            "overview": String(parsed.overview.prefix(200)),
            "key_points": parsed.keyPoints.map { String($0.prefix(80)) },
            "drills": allDrills,
            "related_files": parsed.relatedTechniques
        ]

        // Include technique table for main stroke files (difficulty-ranked progression)
        if !parsed.techniqueTable.isEmpty {
            result["technique_table"] = parsed.techniqueTable.map { entry in
                [
                    "number": entry.number,
                    "name": entry.name,
                    "difficulty": entry.difficulty,
                    "key_focus": String(entry.keyFocus.prefix(50)),
                    "filename": entry.filename
                ]
            }
            result["note"] = "Technique number = difficulty ranking (1=Easiest, 9=Hard). Pick technique matching swimmer's skill level."
        }

        // Add prev/next navigation if available
        if let prev = parsed.prevFile {
            result["prev_file"] = prev
        }
        if let next = parsed.nextFile {
            result["next_file"] = next
        }

        return try encodeJSON(result)
    }

    private func searchContent(query: String?, stroke: String?) throws -> String {
        guard let query else {
            throw ToolError.missingParameter("query")
        }

        let allFiles = try contentLoader.listTechniqueMarkdownFiles()
        let searchTerms = query.lowercased().split(separator: " ").map(String.init)

        let filteredFiles = allFiles.filter { stroke == nil || $0.stroke == stroke }

        var matches: [[String: Any]] = []

        for file in filteredFiles {
            let content = try contentLoader.loadMarkdown(filename: file.filename)
            let lowercased = content.lowercased()

            let hasMatch = searchTerms.contains(where: { term in lowercased.contains(term) })
            if !hasMatch { continue }

            let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
            var excerpts: [String] = []

            for line in lines {
                let lineLower = line.lowercased()
                if searchTerms.contains(where: { term in lineLower.contains(term) }) {
                    let excerpt = String(line).trimmingCharacters(in: .whitespaces)
                    if excerpt.count > 10 && excerpts.count < 3 {
                        excerpts.append(excerpt)
                    }
                }
            }

            if !excerpts.isEmpty {
                matches.append([
                    "filename": file.filename,
                    "title": file.title,
                    "excerpts": excerpts
                ])
            }
        }

        let result: [String: Any] = [
            "query": query,
            "stroke_filter": stroke ?? "",
            "matches_found": matches.count,
            "matches": matches
        ]

        return try encodeJSON(result)
    }

    private func getRelatedTechniques(filename: String?) throws -> String {
        guard let filename else {
            throw ToolError.missingParameter("filename")
        }

        let normalizedFilename = filename.hasSuffix(".md") ? filename : "\(filename).md"

        let content = try contentLoader.loadMarkdown(filename: normalizedFilename)
        let parsed = markdownParser.parse(filename: normalizedFilename, rawContent: content)

        var related: [[String: Any]] = []

        for relatedFile in parsed.relatedTechniques {
            if let relatedContent = try? contentLoader.loadMarkdown(filename: relatedFile) {
                let relatedParsed = markdownParser.parse(filename: relatedFile, rawContent: relatedContent)
                related.append([
                    "filename": relatedFile,
                    "title": relatedParsed.title,
                    "overview_preview": String(relatedParsed.overview.prefix(150))
                ])
            }
        }

        var navigation: [String: Any?] = [:]
        if let prevFile = parsed.prevFile {
            navigation["prev_file"] = prevFile
        }
        if let nextFile = parsed.nextFile {
            navigation["next_file"] = nextFile
        }

        let result: [String: Any] = [
            "source_file": normalizedFilename,
            "source_title": parsed.title,
            "related_techniques": related,
            "navigation": navigation
        ]

        return try encodeJSON(result)
    }

    // MARK: - User Data Tools

    private func getUserProfile() throws -> String {
        guard let profile else {
            return try encodeJSON(["error": "No active profile"])
        }

        // Concise format
        let result: [String: Any] = [
            "name": profile.name,
            "age": profile.age,
            "level": profile.skillLevel.rawValue,
            "weekly_target": profile.weeklySessionTarget,
            "strokes": profile.preferredStrokes.map { $0.rawValue },
            "pb_50m_free": profile.personalBests.freestyle50m ?? 0,
            "pb_50m_back": profile.personalBests.backstroke50m ?? 0
        ]

        return try encodeJSON(result)
    }

    private func getTrainingHistory(days: Int, includeGoals: Bool) throws -> String {
        let sortedNotes = notes.sorted { $0.date > $1.date }
        let maxDays = min(days, 14)  // Limit to 14 days to reduce context
        let recentNotes = Array(sortedNotes.prefix(maxDays))

        // Concise summary format
        var summaryItems: [String] = []
        for note in recentNotes {
            var item = "\(note.date)"
            if !note.strokeFocus.isEmpty {
                item += " | Strokes: " + note.strokeFocus.map { $0.rawValue }.joined(separator: ",")
            }
            if includeGoals {
                let active = note.goals.filter { $0.status == .planned || $0.status == .inProgress }.count
                let achieved = note.goals.filter { $0.status == .achieved }.count
                if active > 0 || achieved > 0 {
                    item += " | Goals: \(active) active, \(achieved) achieved"
                }
            }
            if !note.notes.isEmpty {
                item += " | Note: " + String(note.notes.prefix(50))
            }
            summaryItems.append(item)
        }

        let result: [String: Any] = [
            "days_returned": recentNotes.count,
            "sessions": summaryItems,
            "summary": [
                "total_sessions": recentNotes.count,
                "strokes_practiced": getMostCommonStrokes(from: recentNotes)
            ]
        ]

        return try encodeJSON(result)
    }

    private func getActiveGoals() throws -> String {
        let sortedNotes = notes.sorted { $0.date > $1.date }

        var activeGoals: [[String: Any]] = []
        var seenGoalIds: Set<String> = []

        for note in sortedNotes {
            for goal in note.goals {
                if (goal.status == .planned || goal.status == .inProgress) && !seenGoalIds.contains(goal.id) {
                    seenGoalIds.insert(goal.id)
                    activeGoals.append([
                        "description": goal.description,
                        "stroke": goal.strokeId?.rawValue ?? "",
                        "date": note.date
                    ])
                }
            }
            if activeGoals.count >= 5 { break }  // Limit to 5 goals
        }

        return try encodeJSON([
            "count": activeGoals.count,
            "goals": activeGoals
        ])
    }

    private func getTrainingCalendar(weeks: Int) throws -> String {
        let calendar = Calendar.current
        let today = Date()
        let startDate = calendar.date(byAdding: .weekOfYear, value: -weeks, to: today) ?? today

        // Build calendar data
        var calendarData: [[String: Any]] = []
        var currentDate = startDate

        while currentDate <= today {
            let dateStr = SwimNoteDateFormatting.shortDateString(from: currentDate)
            let hasSession = notes.contains(where: { $0.date == dateStr })
            let noteForDate = notes.first { $0.date == dateStr }

            let dayOfWeek = calendar.component(.weekday, from: currentDate)
            let weekdayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

            calendarData.append([
                "date": dateStr,
                "day_of_week": weekdayNames[dayOfWeek - 1],
                "had_session": hasSession,
                "stroke_focus": noteForDate?.strokeFocus.map { $0.rawValue } ?? [],
                "goal_count": noteForDate?.goals.count ?? 0
            ])

            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        // Calculate statistics
        let totalSessions = calendarData.filter { ($0["had_session"] as? Bool) == true }.count
        let expectedSessions = profile?.weeklySessionTarget ?? 3
        let weekCount = weeks

        let result: [String: Any] = [
            "weeks_shown": weekCount,
            "calendar": calendarData,
            "statistics": [
                "total_sessions": totalSessions,
                "weekly_target": expectedSessions,
                "average_sessions_per_week": Double(totalSessions) / Double(weekCount),
                "target_met": totalSessions >= expectedSessions * weekCount
            ]
        ]

        return try encodeJSON(result)
    }

    // MARK: - CSS and Interval Training Tools

    private func getCSSInfo(stroke: String?) throws -> String {
        guard let profile else {
            return try encodeJSON(["error": "No active profile"])
        }

        guard let cssHistory = profile.cssHistory, !cssHistory.isEmpty else {
            // No CSS tests recorded
            let result: [String: Any] = [
                "has_css": false,
                "message": "No CSS tests recorded. Ask swimmer to take a CSS test (200m+400m time trials or 3-minute test) before generating zone-based intervals.",
                "fallback_approach": "Use skill level + personal bests to estimate training zones. Beginner: Zone 1-2, Intermediate: Zone 2-3, Advanced: Zone 3-4, Competitive: Zone 4-5."
            ]
            return try encodeJSON(result)
        }

        // Filter by stroke if specified
        let strokeId: StrokeID? = stroke != nil ? StrokeID(rawValue: stroke!.lowercased()) : nil
        let tests = cssHistory.tests.filter { strokeId == nil || $0.strokeId == strokeId }

        guard let latestTest = tests.sorted(by: { $0.date > $1.date }).first else {
            return try encodeJSON(["error": "No CSS test for specified stroke"])
        }

        // Calculate training zone paces from CSS
        let cssPace = latestTest.cssPaceSecondsPer100m
        let zonePaces: [String: Any] = [
            "zone_0_recovery": formatPace(cssPace + 25),
            "zone_1_aerobic_base": formatPace(cssPace + 12),
            "zone_2_aerobic_endurance": formatPace(cssPace + 7),
            "zone_3_tempo": formatPace(cssPace + 2),
            "zone_4_threshold": formatPace(cssPace - 1),
            "zone_5_vo2max": formatPace(cssPace - 5),
            "zone_6_sprint": "Race pace (use personal bests)"
        ]

        let result: [String: Any] = [
            "has_css": true,
            "stroke": latestTest.strokeId.rawValue,
            "test_date": latestTest.date,
            "test_type": latestTest.testType.displayName,
            "css_meters_per_second": latestTest.cssMetersPerSecond,
            "css_pace_per_100m": formatPace(cssPace),
            "training_zone_paces": zonePaces,
            "css_trend": cssHistory.trend?.rawValue ?? "stable",
            "progress_tests_count": tests.count,
            "tip": "Use zone paces to set interval send-off times. Zone 3-4 is ideal for main sets. Add rest interval to pace to calculate send-off."
        ]

        return try encodeJSON(result)
    }

    private func formatPace(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds / 60)
        let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", mins, secs)
    }

    private func readIntervalResearch(section: String?) throws -> String {
        let sectionParam = section ?? "all"

        // Load the research document
        let filename = "swimming-interval-training-research.md"
        let content = try contentLoader.loadMarkdown(filename: filename)

        // If requesting all, return the full document (but cap at reasonable size)
        if sectionParam == "all" {
            // Return first ~3000 chars which covers table of contents and overview
            let preview = String(content.prefix(3500))
            let result: [String: Any] = [
                "document": "swimming-interval-training-research",
                "section": "all",
                "content_preview": preview,
                "note": "Full document is comprehensive. Call with specific section (zones, intervals, periodization, events, levels) for focused content."
            ]
            return try encodeJSON(result)
        }

        // Extract specific section based on section parameter
        let sectionContent = extractSection(content: content, section: sectionParam)

        let result: [String: Any] = [
            "document": "swimming-interval-training-research",
            "section_requested": sectionParam,
            "content": sectionContent
        ]

        return try encodeJSON(result)
    }

    // MARK: - Tier Guidance Tool

    private func getTierGuidance() throws -> String {
        guard let profile else {
            return try encodeJSON(["error": "No active profile"])
        }

        let tier = profile.trainingTier
        let subTier = profile.subTier

        // Get weekly and per-session distance based on tier/sub-tier
        let weeklyDistance = weeklyDistanceForTier(tier: tier, subTier: subTier)
        let perSessionDistance = perSessionDistanceForTier(tier: tier, subTier: subTier)
        let practicesPerWeek = practicesPerWeekForTier(tier: tier, subTier: subTier)
        let zoneDistribution = zoneDistributionForTier(tier: tier, subTier: subTier)
        let trainingFocus = trainingFocusForTier(tier: tier, subTier: subTier)

        let result: [String: Any] = [
            "tier": tier.displayName,
            "tier_raw": tier.rawValue,
            "sub_tier": subTier.displayName,
            "sub_tier_raw": subTier.rawValue,
            "full_level": fullLevelName(tier: tier, subTier: subTier),
            "weekly_distance": weeklyDistance,
            "per_session_distance": perSessionDistance,
            "practices_per_week": practicesPerWeek,
            "zone_distribution": zoneDistribution,
            "training_focus": trainingFocus,
            "guidance_source": "usa-swimming-club-training-structure.md",
            "critical_notes": [
                "Zone distribution must be followed - higher tiers can handle more intensity",
                "Session total distance should not exceed per_session_distance max",
                "Weekly total across all sessions should align with weekly_distance target",
                "Training focus priorities should inform the main set structure"
            ]
        ]

        return try encodeJSON(result)
    }

    private func weeklyDistanceForTier(tier: TrainingTier, subTier: SubTier) -> [String: Any] {
        switch tier {
        case .preCompetitive:
            switch subTier {
            case .a: return ["min": 1000, "max": 2500, "unit": "meters", "description": "1-2.5 km/week (Pre-Comp A: Foundations)"]
            case .b: return ["min": 2000, "max": 4000, "unit": "meters", "description": "2-4 km/week (Pre-Comp B: Skill Building)"]
            case .c: return ["min": 3000, "max": 7000, "unit": "meters", "description": "3-7 km/week (Pre-Comp C: Pre-Competitive)"]
            default: return ["min": 3000, "max": 8000, "unit": "meters", "description": "3-8 km/week"]
            }
        case .bronze:
            switch subTier {
            case .one: return ["min": 4500, "max": 7500, "unit": "meters", "description": "4.5-7.5 km/week (Bronze 1: First Year)"]
            case .two: return ["min": 6000, "max": 14000, "unit": "meters", "description": "6-14 km/week (Bronze 2: Toward B Times)"]
            case .three: return ["min": 10000, "max": 18000, "unit": "meters", "description": "10-18 km/week (Bronze 3: Has B Times)"]
            default: return ["min": 8000, "max": 18000, "unit": "meters", "description": "8-18 km/week"]
            }
        case .silver:
            switch subTier {
            case .one: return ["min": 10000, "max": 16000, "unit": "meters", "description": "10-16 km/week (Silver 1: Early Silver)"]
            case .two: return ["min": 12000, "max": 20000, "unit": "meters", "description": "12-20 km/week (Silver 2: Mid-Silver)"]
            case .three: return ["min": 14000, "max": 28000, "unit": "meters", "description": "14-28 km/week (Silver 3: Upper Silver)"]
            default: return ["min": 15000, "max": 28000, "unit": "meters", "description": "15-28 km/week"]
            }
        case .gold:
            return ["min": 25000, "max": 40000, "unit": "meters", "description": "25-40 km/week (Gold: Senior Age Group)"]
        case .senior:
            return ["min": 40000, "max": 60000, "unit": "meters", "description": "40-60 km/week (Senior: Championship)"]
        case .national:
            return ["min": 50000, "max": 80000, "unit": "meters", "description": "50-80+ km/week (National: Elite)"]
        }
    }

    private func perSessionDistanceForTier(tier: TrainingTier, subTier: SubTier) -> [String: Any] {
        switch tier {
        case .preCompetitive:
            switch subTier {
            case .a: return ["min": 500, "max": 1200, "unit": "meters", "description": "500-1,200m per practice (30-45 min)"]
            case .b: return ["min": 1000, "max": 2000, "unit": "meters", "description": "1,000-2,000m per practice (45-60 min)"]
            case .c: return ["min": 1500, "max": 2500, "unit": "meters", "description": "1,500-2,500m per practice (45-60 min)"]
            default: return ["min": 500, "max": 2500, "unit": "meters"]
            }
        case .bronze:
            switch subTier {
            case .one: return ["min": 1500, "max": 2500, "unit": "meters", "description": "1,500-2,500m per practice (60 min)"]
            case .two: return ["min": 2000, "max": 3500, "unit": "meters", "description": "2,000-3,500m per practice (60-75 min)"]
            case .three: return ["min": 2500, "max": 4500, "unit": "meters", "description": "2,500-4,500m per practice (60-75 min)"]
            default: return ["min": 1500, "max": 4500, "unit": "meters"]
            }
        case .silver:
            switch subTier {
            case .one: return ["min": 2500, "max": 4000, "unit": "meters", "description": "2,500-4,000m per practice (75 min)"]
            case .two: return ["min": 3000, "max": 5000, "unit": "meters", "description": "3,000-5,000m per practice (75-90 min)"]
            case .three: return ["min": 3500, "max": 5500, "unit": "meters", "description": "3,500-5,500m per practice (75-90 min)"]
            default: return ["min": 2500, "max": 5500, "unit": "meters"]
            }
        case .gold:
            return ["min": 4500, "max": 7500, "unit": "meters", "description": "4,500-7,500m per practice (90-105 min)"]
        case .senior:
            return ["min": 5500, "max": 8500, "unit": "meters", "description": "5,500-8,500m per practice (90-120 min)"]
        case .national:
            return ["min": 5000, "max": 10000, "unit": "meters", "description": "5,000-10,000+ m per practice (120-180 min)"]
        }
    }

    private func practicesPerWeekForTier(tier: TrainingTier, subTier: SubTier) -> [String: Any] {
        switch tier {
        case .preCompetitive:
            switch subTier {
            case .a: return ["min": 2, "max": 2, "recommended": 2]
            case .b: return ["min": 2, "max": 2, "recommended": 2]
            case .c: return ["min": 2, "max": 3, "recommended": 2]
            default: return ["min": 2, "max": 3, "recommended": 2]
            }
        case .bronze:
            switch subTier {
            case .one: return ["min": 3, "max": 3, "recommended": 3]
            case .two: return ["min": 3, "max": 4, "recommended": 3]
            case .three: return ["min": 4, "max": 4, "recommended": 4]
            default: return ["min": 3, "max": 4, "recommended": 3]
            }
        case .silver:
            switch subTier {
            case .one: return ["min": 4, "max": 4, "recommended": 4]
            case .two: return ["min": 4, "max": 4, "recommended": 4]
            case .three: return ["min": 4, "max": 5, "recommended": 4]
            default: return ["min": 4, "max": 5, "recommended": 4]
            }
        case .gold:
            return ["min": 5, "max": 6, "recommended": 5]
        case .senior:
            return ["min": 6, "max": 8, "recommended": 6]
        case .national:
            return ["min": 8, "max": 12, "recommended": 8]
        }
    }

    private func zoneDistributionForTier(tier: TrainingTier, subTier: SubTier) -> [String: Any] {
        // Zone distribution based on USA Swimming club structure
        switch tier {
        case .preCompetitive:
            switch subTier {
            case .a:
                return [
                    "zone_0_recovery": "10-15%",
                    "zone_1_aerobic_base": "60-70%",
                    "zone_2_aerobic_endurance": "10-15%",
                    "zone_3_tempo": "0-5%",
                    "zone_4_threshold": "0%",
                    "zone_5_vo2max": "0%",
                    "zone_6_sprint": "0%",
                    "note": "Overwhelmingly Zone 1. No formal high-intensity training."
                ]
            case .b:
                return [
                    "zone_0_recovery": "10-15%",
                    "zone_1_aerobic_base": "55-65%",
                    "zone_2_aerobic_endurance": "15-20%",
                    "zone_3_tempo": "5-10%",
                    "zone_4_threshold": "0%",
                    "zone_5_vo2max": "0%",
                    "zone_6_sprint": "0%",
                    "note": "Still primarily Zone 1. Brief Zone 3 bursts only."
                ]
            case .c:
                return [
                    "zone_0_recovery": "10-15%",
                    "zone_1_aerobic_base": "55-60%",
                    "zone_2_aerobic_endurance": "15-20%",
                    "zone_3_tempo": "5-10%",
                    "zone_4_threshold": "0-5%",
                    "zone_5_vo2max": "0%",
                    "zone_6_sprint": "0%",
                    "note": "First exposure to Zone 4 for brief sprint games only."
                ]
            default:
                return [
                    "zone_0_recovery": "10-15%",
                    "zone_1_aerobic_base": "55-65%",
                    "zone_2_aerobic_endurance": "15-20%",
                    "zone_3_tempo": "5-10%",
                    "zone_4_threshold": "0-5%",
                    "zone_5_vo2max": "0%",
                    "zone_6_sprint": "0-5%"
                ]
            }
        case .bronze:
            switch subTier {
            case .one:
                return [
                    "zone_0_recovery": "10%",
                    "zone_1_aerobic_base": "55-60%",
                    "zone_2_aerobic_endurance": "15-20%",
                    "zone_3_tempo": "5-10%",
                    "zone_4_threshold": "0%",
                    "zone_5_vo2max": "0%",
                    "zone_6_sprint": "0%",
                    "note": "No threshold or sprint work. Focus on technique and easy swimming."
                ]
            case .two:
                return [
                    "zone_0_recovery": "10%",
                    "zone_1_aerobic_base": "50-55%",
                    "zone_2_aerobic_endurance": "20-25%",
                    "zone_3_tempo": "10-15%",
                    "zone_4_threshold": "0-5%",
                    "zone_5_vo2max": "0%",
                    "zone_6_sprint": "0%",
                    "note": "First introduction to Zone 4. Brief threshold pieces."
                ]
            case .three:
                return [
                    "zone_0_recovery": "10%",
                    "zone_1_aerobic_base": "45-50%",
                    "zone_2_aerobic_endurance": "25-30%",
                    "zone_3_tempo": "10-15%",
                    "zone_4_threshold": "5%",
                    "zone_5_vo2max": "0%",
                    "zone_6_sprint": "0%",
                    "note": "Regular Zone 3-4 work. Preparing for Silver-level intensity."
                ]
            default:
                return [
                    "zone_0_recovery": "10%",
                    "zone_1_aerobic_base": "50-55%",
                    "zone_2_aerobic_endurance": "20-25%",
                    "zone_3_tempo": "10-15%",
                    "zone_4_threshold": "0-5%",
                    "zone_5_vo2max": "0%",
                    "zone_6_sprint": "0%"
                ]
            }
        case .silver:
            switch subTier {
            case .one:
                return [
                    "zone_0_recovery": "10%",
                    "zone_1_aerobic_base": "45-50%",
                    "zone_2_aerobic_endurance": "25-30%",
                    "zone_3_tempo": "10-15%",
                    "zone_4_threshold": "5%",
                    "zone_5_vo2max": "0%",
                    "zone_6_sprint": "0%",
                    "note": "Threshold sets introduced. Building aerobic engine."
                ]
            case .two:
                return [
                    "zone_0_recovery": "10%",
                    "zone_1_aerobic_base": "40-45%",
                    "zone_2_aerobic_endurance": "25-30%",
                    "zone_3_tempo": "15%",
                    "zone_4_threshold": "5-10%",
                    "zone_5_vo2max": "0-5%",
                    "zone_6_sprint": "0%",
                    "note": "CSS pace sets introduced. Regular threshold work."
                ]
            case .three:
                return [
                    "zone_0_recovery": "10%",
                    "zone_1_aerobic_base": "35-40%",
                    "zone_2_aerobic_endurance": "25-30%",
                    "zone_3_tempo": "15-20%",
                    "zone_4_threshold": "10%",
                    "zone_5_vo2max": "5%",
                    "zone_6_sprint": "0-3%",
                    "note": "Race-pace work enters. Preparing for Gold group."
                ]
            default:
                return [
                    "zone_0_recovery": "10%",
                    "zone_1_aerobic_base": "40-45%",
                    "zone_2_aerobic_endurance": "25-30%",
                    "zone_3_tempo": "10-15%",
                    "zone_4_threshold": "5-10%",
                    "zone_5_vo2max": "0-5%",
                    "zone_6_sprint": "0%"
                ]
            }
        case .gold:
            return [
                "zone_0_recovery": "10%",
                "zone_1_aerobic_base": "35-40%",
                "zone_2_aerobic_endurance": "25-30%",
                "zone_3_tempo": "15-20%",
                "zone_4_threshold": "5-10%",
                "zone_5_vo2max": "0-5%",
                "zone_6_sprint": "0-3%",
                "note": "Full training spectrum available. Systematic threshold introduction."
            ]
        case .senior:
            return [
                "zone_0_recovery": "10%",
                "zone_1_aerobic_base": "25-30%",
                "zone_2_aerobic_endurance": "25-30%",
                "zone_3_tempo": "15-20%",
                "zone_4_threshold": "10-15%",
                "zone_5_vo2max": "5-10%",
                "zone_6_sprint": "3-5%",
                "note": "Significant high-intensity work. Event-specific training."
            ]
        case .national:
            return [
                "zone_0_recovery": "10%",
                "zone_1_aerobic_base": "15-20%",
                "zone_2_aerobic_endurance": "20-25%",
                "zone_3_tempo": "15-20%",
                "zone_4_threshold": "15-20%",
                "zone_5_vo2max": "10-15%",
                "zone_6_sprint": "5-10%",
                "note": "Elite training. Still 55-65% in Zones 0-2. Periodized intensity."
            ]
        }
    }

    private func trainingFocusForTier(tier: TrainingTier, subTier: SubTier) -> [String] {
        switch tier {
        case .preCompetitive:
            return [
                "60-70%: Stroke technique drills (all four strokes introduced)",
                "15-20%: Starts and turns (basic dive, elementary flip turn)",
                "10-15%: Games, relays, fun activities",
                "0-5%: Timed swimming (sprint games only)"
            ]
        case .bronze:
            return [
                "40-50%: Stroke technique refinement (all four strokes)",
                "20-25%: Aerobic base building (distance at easy pace)",
                "15-20%: Starts, turns, underwater skills",
                "10-15%: Introduction to interval training",
                "0-5%: Sprint/race-pace (brief activities only)"
            ]
        case .silver:
            return [
                "30-35%: Stroke technique refinement (stroke-specific drills)",
                "30-35%: Aerobic base and endurance (longer sets, building volume)",
                "15-20%: Threshold introduction (CSS pace work)",
                "10-15%: Starts, turns, race strategy",
                "5-10%: Sprint work and race-pace activities"
            ]
        case .gold:
            return [
                "25-30%: Stroke-specific technique (form at higher volume)",
                "30-35%: Aerobic base and endurance (building capacity)",
                "15-20%: Threshold training (CSS work, pace clock intervals)",
                "10-15%: Race-pace work and sprint development",
                "10%: Starts, turns, underwaters, race strategy"
            ]
        case .senior:
            return [
                "20-25%: Stroke technique (fine-tuning at race pace)",
                "25-30%: Aerobic endurance (maintaining base)",
                "20-25%: Threshold and race-pace work",
                "10-15%: VO2max and lactate tolerance",
                "10%: Sprint work, starts, turns, race strategy"
            ]
        case .national:
            return [
                "15-20%: Technique fine-tuning (video analysis)",
                "20-25%: Aerobic maintenance",
                "20-25%: Threshold and race-pace (event-specific)",
                "15-20%: VO2max and lactate tolerance",
                "10-15%: Sprint and speed development",
                "10%: Starts, turns, race strategy, mental skills"
            ]
        }
    }

    private func fullLevelName(tier: TrainingTier, subTier: SubTier) -> String {
        if tier.hasSubTiers && subTier != .none {
            return "\(tier.displayName) \(subTier.displayName)"
        }
        return tier.displayName
    }

    // MARK: - Helpers

    private func extractSection(content: String, section: String) -> String {
        // Find section markers in the document
        let sectionMarkers: [String: String] = [
            "zones": "## 2. Training Zones by Purpose",
            "intervals": "## 3. Interval Calculation Methods",
            "periodization": "## 4. Periodization and Interval Selection",
            "events": "## 5. Event-Specific Considerations",
            "levels": "## 6. Swimmer Level Adjustments"
        ]

        guard let marker = sectionMarkers[section] else {
            return "Section not found. Available sections: zones, intervals, periodization, events, levels"
        }

        // Find the section start
        guard let sectionStart = content.range(of: marker) else {
            return "Section content not found in document"
        }

        // Find the next major section (## number) to determine end
        let remainingContent = String(content[sectionStart.lowerBound...])
        let nextSectionPattern = "\n## [0-9]+."

        if let nextSectionRange = remainingContent.range(of: nextSectionPattern, options: .regularExpression) {
            let sectionContent = String(remainingContent[..<nextSectionRange.lowerBound])
            // Cap at 2000 chars for reasonable context
            return String(sectionContent.prefix(2000))
        } else {
            // Last section - return remaining content (capped)
            return String(remainingContent.prefix(2000))
        }
    }

    private func parseArguments(_ toolCall: ToolCall) throws -> [String: Any] {
        guard let data = toolCall.function.arguments.data(using: .utf8) else {
            throw ToolError.executionError("Could not decode arguments")
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ToolError.executionError("Arguments are not valid JSON")
        }
        return json
    }

    private func encodeJSON(_ value: Any) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted])
        guard let string = String(data: data, encoding: .utf8) else {
            throw ToolError.executionError("Could not encode result as JSON")
        }
        return string
    }

    private func getMostCommonStrokes(from notes: [TrainingNote]) -> [String] {
        var strokeCounts: [String: Int] = [:]
        for note in notes {
            for stroke in note.strokeFocus {
                strokeCounts[stroke.rawValue, default: 0] += 1
            }
        }
        return strokeCounts.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
    }

    private func groupGoalsByStroke(_ goals: [[String: Any]]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for goal in goals {
            if let stroke = goal["stroke"] as? String {
                counts[stroke, default: 0] += 1
            }
        }
        return counts
    }
}