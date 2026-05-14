import Foundation

extension CombinedToolExecutor {
    // MARK: - User Data Tools

    func getUserProfile() throws -> String {
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

    func getTrainingHistory(days: Int, includeGoals: Bool) throws -> String {
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

    func getActiveGoals() throws -> String {
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

    func getTrainingCalendar(weeks: Int) throws -> String {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .weekOfYear, value: -weeks, to: referenceDate) ?? referenceDate

        // Build calendar data
        var calendarData: [[String: Any]] = []
        var currentDate = startDate

        while currentDate <= referenceDate {
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
    func getMostCommonStrokes(from notes: [TrainingNote]) -> [String] {
        var strokeCounts: [String: Int] = [:]
        for note in notes {
            for stroke in note.strokeFocus {
                strokeCounts[stroke.rawValue, default: 0] += 1
            }
        }
        return strokeCounts.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
    }

    func groupGoalsByStroke(_ goals: [[String: Any]]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for goal in goals {
            if let stroke = goal["stroke"] as? String {
                counts[stroke, default: 0] += 1
            }
        }
        return counts
    }
}
