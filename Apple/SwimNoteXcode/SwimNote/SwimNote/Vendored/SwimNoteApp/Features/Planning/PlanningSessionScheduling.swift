import Foundation

/// Day-of-week offsets and time-of-day for pool sessions (matches legacy `PlanningView` scheduling).
enum PlanningSessionScheduling {
    /// Reuse the same day offset logic as session scheduling when summarizing past plans.
    static func computeDayOffsets(count: Int) -> [(dayOffset: Int, timeOfDay: SessionTimeOfDay)] {
        switch count {
        case 1: return [(0, .morning)]
        case 2: return [(0, .morning), (2, .morning)]
        case 3: return [(0, .morning), (2, .morning), (4, .morning)]
        case 4: return [(0, .morning), (1, .morning), (3, .morning), (4, .morning)]
        case 5: return [(0, .morning), (1, .morning), (2, .morning), (3, .morning), (4, .morning)]
        case 6: return [(0, .morning), (1, .morning), (2, .morning), (3, .morning), (4, .morning), (5, .morning)]
        case 7: return [(0, .morning), (1, .morning), (2, .morning), (3, .morning), (4, .morning), (5, .morning), (6, .morning)]
        case 8: return [(0, .morning), (1, .morning), (2, .morning), (2, .afternoon), (3, .morning), (4, .morning), (5, .morning), (6, .morning)]
        default: return (0..<count).map { ($0, SessionTimeOfDay.morning) }
        }
    }

    /// Day offsets and time of day for session distribution (supports double sessions for higher tiers).
    static func dayOffsetsForSessions(count: Int) -> [(dayOffset: Int, timeOfDay: SessionTimeOfDay)] {
        switch count {
        case 1:
            return [(0, .morning)] // Monday morning
        case 2:
            return [(0, .morning), (2, .morning)] // Mon AM, Wed AM
        case 3:
            return [(0, .morning), (2, .morning), (4, .morning)] // Mon, Wed, Fri AM
        case 4:
            return [(0, .morning), (1, .morning), (3, .morning), (4, .morning)] // Mon, Tue, Thu, Fri AM
        case 5:
            return [(0, .morning), (1, .morning), (2, .morning), (3, .morning), (4, .morning)] // Mon-Fri AM
        case 6:
            return [(0, .morning), (1, .morning), (2, .morning), (3, .morning), (4, .morning), (5, .morning)] // Mon-Sat AM
        case 7:
            return [(0, .morning), (1, .morning), (2, .morning), (3, .morning), (4, .morning), (5, .morning), (6, .morning)] // All week AM
        case 8:
            // 6 days with 1 double day (Mon-Sat, with Wed having morning + afternoon)
            return [
                (0, .morning), (1, .morning), (2, .morning), (2, .afternoon), // Mon, Tue, Wed AM+PM
                (3, .morning), (4, .morning), (5, .morning), (6, .morning) // Thu-Sun AM
            ]
        case 9:
            // 7 days with 2 double days
            return [
                (0, .morning), (1, .morning), (2, .morning), (2, .afternoon), // Mon, Tue, Wed AM+PM
                (3, .morning), (3, .afternoon), (4, .morning), // Thu AM+PM, Fri AM
                (5, .morning), (6, .morning) // Sat, Sun AM
            ]
        case 10:
            // 7 days with 3 double days (common for National tier)
            return [
                (0, .morning), (0, .afternoon), // Mon AM+PM
                (1, .morning), (2, .morning), (2, .afternoon), // Tue, Wed AM+PM
                (3, .morning), (4, .morning), (4, .afternoon), // Thu, Fri AM+PM
                (5, .morning), (6, .morning) // Sat, Sun AM
            ]
        case 11:
            // 7 days with 4 double days
            return [
                (0, .morning), (0, .afternoon), // Mon AM+PM
                (1, .morning), (1, .afternoon), // Tue AM+PM
                (2, .morning), (3, .morning), (3, .afternoon), // Wed, Thu AM+PM
                (4, .morning), (4, .afternoon), // Fri AM+PM
                (5, .morning), (6, .morning) // Sat, Sun AM
            ]
        case 12:
            // 6 days with all doubles (National elite: morning + afternoon every day except Sunday)
            return [
                (0, .morning), (0, .afternoon), // Mon AM+PM
                (1, .morning), (1, .afternoon), // Tue AM+PM
                (2, .morning), (2, .afternoon), // Wed AM+PM
                (3, .morning), (3, .afternoon), // Thu AM+PM
                (4, .morning), (4, .afternoon), // Fri AM+PM
                (5, .morning), (5, .afternoon), // Sat AM+PM
                (6, .morning) // Sun AM (rest day PM)
            ]
        default:
            // For counts > 12, cycle through days with doubles
            return Array(0..<count).map { index in
                let dayOffset = index % 7
                let isSecondSession = index >= 7
                let timeOfDay: SessionTimeOfDay = isSecondSession ? .afternoon : .morning
                return (dayOffset, timeOfDay)
            }
        }
    }
}
