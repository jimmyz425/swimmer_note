import Foundation

extension CombinedToolExecutor {
    // MARK: - CSS and Interval Training Tools

    func getCSSInfo(stroke: String?) throws -> String {
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

    func formatPace(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds / 60)
        let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", mins, secs)
    }

    func readIntervalResearch(section: String?) throws -> String {
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
}
