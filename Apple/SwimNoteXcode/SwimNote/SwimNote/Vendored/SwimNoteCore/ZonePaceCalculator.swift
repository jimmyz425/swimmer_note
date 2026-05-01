import Foundation

// MARK: - Zone Pace Calculator

/// Converts training zones to pace based on CSS (Critical Swim Speed)
/// Uses offsets from interval training research document
public struct ZonePaceCalculator: Sendable {

    /// CSS pace offsets per 100m for each zone (in seconds)
    /// Based on swimming-interval-training-research.md section 3.1
    public static let zoneOffsets: [Int: ClosedRange<Double>] = [
        0: 20...30,       // Recovery: CSS +20-30s/100m
        1: 10...15,       // Aerobic Base: CSS +10-15s/100m
        2: 5...10,        // Aerobic Endurance: CSS +5-10s/100m
        3: 0...5,         // Tempo/AeT: CSS +0-5s/100m
        4: -2...0,        // Lactate Threshold: CSS to -2s/100m
        5: -3...(-6),     // VO2max: CSS -3-6s/100m
        6: 0...0          // Sprint: Race pace (no CSS offset)
    ]

    /// Recommended rest intervals per zone (in seconds)
    /// Based on percentage of work time or fixed ranges from research
    public struct RestRecommendation {
        public let minSeconds: Int
        public let maxSeconds: Int
        public let percentageOfWork: Double?  // For percentage-based rest

        public init(minSeconds: Int, maxSeconds: Int, percentageOfWork: Double? = nil) {
            self.minSeconds = minSeconds
            self.maxSeconds = maxSeconds
            self.percentageOfWork = percentageOfWork
        }
    }

    /// Rest recommendations by zone from interval research document
    public static let restByZone: [Int: RestRecommendation] = [
        0: RestRecommendation(minSeconds: 60, maxSeconds: 120, percentageOfWork: 0.5),  // Recovery: 50-100% of work
        1: RestRecommendation(minSeconds: 12, maxSeconds: 20, percentageOfWork: 0.15),  // Aerobic Base: 15-25%
        2: RestRecommendation(minSeconds: 8, maxSeconds: 16, percentageOfWork: 0.10),   // Aerobic Endurance: 10-20%
        3: RestRecommendation(minSeconds: 8, maxSeconds: 12, percentageOfWork: 0.10),   // Tempo: 10-15%
        4: RestRecommendation(minSeconds: 4, maxSeconds: 12, percentageOfWork: 0.05),   // Lactate Threshold: 5-15%
        5: RestRecommendation(minSeconds: 24, maxSeconds: 40, percentageOfWork: 0.30),  // VO2max: 30-50%
        6: RestRecommendation(minSeconds: 180, maxSeconds: 300)  // Sprint pure speed: 3-5 minutes
    ]

    /// Calculate pace for a zone given CSS pace
    /// - Parameters:
    ///   - zone: Training zone (0-6)
    ///   - cssPacePer100m: CSS pace in seconds per 100m
    ///   - offsetChoice: 0 for lower bound, 1 for upper bound, default uses middle
    /// - Returns: Pace in seconds per 100m, or nil if zone invalid
    public static func paceForZone(
        zone: Int,
        cssPacePer100m: Double,
        offsetChoice: Double = 0.5
    ) -> Double? {
        guard let offsets = zoneOffsets[zone] else { return nil }

        // Sprint zone (6) doesn't use CSS - return CSS as reference
        if zone == 6 {
            return cssPacePer100m  // Sprint uses race pace, not CSS offset
        }

        // Calculate offset based on choice (0 = slowest, 1 = fastest for that zone)
        let offsetRange = offsets.lowerBound - offsets.upperBound  // Note: upper is faster (negative offset)
        let offset = offsets.lowerBound - (offsetRange * offsetChoice)

        return cssPacePer100m + offset
    }

    /// Calculate recommended rest for a zone and rep duration
    /// - Parameters:
    ///   - zone: Training zone (0-6)
    ///   - workTimeSeconds: Duration of the work interval in seconds
    /// - Returns: Recommended rest in seconds
    public static func restForZone(
        zone: Int,
        workTimeSeconds: Int
    ) -> Int? {
        guard let recommendation = restByZone[zone] else { return nil }

        // If percentage-based, calculate from work time
        if let percentage = recommendation.percentageOfWork {
            let percentageRest = Int(Double(workTimeSeconds) * percentage)
            // Clamp to min/max range
            return max(recommendation.minSeconds, min(recommendation.maxSeconds, percentageRest))
        }

        // Otherwise use fixed range - return middle value
        return (recommendation.minSeconds + recommendation.maxSeconds) / 2
    }

    /// Format pace as readable string (e.g., "1:17")
    public static func formatPace(secondsPer100m: Double) -> String {
        let mins = Int(secondsPer100m / 60)
        let secs = Int(secondsPer100m.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", mins, secs)
    }

    /// Calculate swim time for a rep given distance and pace
    /// - Parameters:
    ///   - distanceMeters: Distance of the rep in meters
    ///   - paceSecondsPer100m: Pace in seconds per 100m
    /// - Returns: Swim time in seconds
    public static func swimTimeForRep(distanceMeters: Int, paceSecondsPer100m: Double) -> Int {
        return Int(Double(distanceMeters) / 100.0 * paceSecondsPer100m)
    }

    /// Calculate complete set timing with swim and rest
    /// - Parameters:
    ///   - distanceMeters: Distance per rep in meters
    ///   - zone: Training zone (0-6)
    ///   - cssPacePer100m: CSS pace in seconds per 100m
    ///   - restOverride: Optional explicit rest time (if LLM provided)
    /// - Returns: Tuple of (swimSeconds, restSeconds) or nil if zone invalid
    public static func setTiming(
        distanceMeters: Int,
        zone: Int,
        cssPacePer100m: Double,
        restOverride: Int? = nil
    ) -> (swimSeconds: Int, restSeconds: Int)? {
        guard let pace = paceForZone(zone: zone, cssPacePer100m: cssPacePer100m) else { return nil }

        let swimSeconds = swimTimeForRep(distanceMeters: distanceMeters, paceSecondsPer100m: pace)

        // Use explicit rest if provided, otherwise calculate from zone
        let restSeconds: Int
        if let explicitRest = restOverride {
            restSeconds = explicitRest
        } else {
            guard let calculatedRest = restForZone(zone: zone, workTimeSeconds: swimSeconds) else { return nil }
            restSeconds = calculatedRest
        }

        return (swimSeconds, restSeconds)
    }

    /// Format set timing as Sxxxs Rxxxs display
    /// - Parameters:
    ///   - swimSeconds: Swim time in seconds
    ///   - restSeconds: Rest time in seconds (optional)
    /// - Returns: Formatted string like "S65s R15s" or just "S65s"
    public static func formatSetTiming(swimSeconds: Int, restSeconds: Int?) -> String {
        if let rest = restSeconds {
            return "S\(swimSeconds)s R\(rest)s"
        }
        return "S\(swimSeconds)s"
    }

    /// Calculate send-off time given pace and rest
    /// - Parameters:
    ///   - paceSeconds: Target pace per rep in seconds
    ///   - restSeconds: Rest interval in seconds
    /// - Returns: Send-off time in seconds
    public static func sendOffTime(paceSeconds: Int, restSeconds: Int) -> Int {
        return paceSeconds + restSeconds
    }

    /// Format send-off time as readable string (e.g., "1:30")
    public static func formatSendOff(seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    /// Get zone name for display
    public static func zoneName(zone: Int) -> String {
        switch zone {
        case 0: return "Recovery"
        case 1: return "Aerobic Base"
        case 2: return "Aerobic Endurance"
        case 3: return "Tempo"
        case 4: return "Threshold"
        case 5: return "VO2max"
        case 6: return "Sprint"
        default: return "Unknown"
        }
    }

    /// Get zone color for UI display
    public static func zoneColor(zone: Int) -> String {
        switch zone {
        case 0: return "gray"
        case 1: return "green"
        case 2: return "cyan"
        case 3: return "yellow"
        case 4: return "orange"
        case 5: return "red"
        case 6: return "purple"
        default: return "gray"
        }
    }

    /// Get summary of all zones with CSS-based paces
    public static func zonePacesSummary(cssPacePer100m: Double) -> [String: String] {
        var summary: [String: String] = [:]
        for zone in 0...6 {
            if let pace = paceForZone(zone: zone, cssPacePer100m: cssPacePer100m) {
                let rest = restByZone[zone]
                let restStr = rest != nil ? "\(rest!.minSeconds)-\(rest!.maxSeconds)s" : "N/A"
                summary["zone_\(zone)"] = "\(zoneName(zone: zone)): \(formatPace(secondsPer100m: pace))/100m, rest \(restStr)"
            }
        }
        return summary
    }
}