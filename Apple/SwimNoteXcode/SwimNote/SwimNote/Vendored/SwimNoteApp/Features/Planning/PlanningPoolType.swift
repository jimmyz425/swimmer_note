import SwiftUI

public enum PoolType: String, CaseIterable, Identifiable {
    case scy = "SCY"
    case scm = "SCM"
    case lcm = "LCM"

    public var id: String { rawValue }

    public var shortLabel: String { rawValue }

    public var fullLabel: String {
        switch self {
        case .scy: "Short Course Yards (25yd)"
        case .scm: "Short Course Meters (25m)"
        case .lcm: "Long Course Meters (50m)"
        }
    }

    /// Base pool length in meters for distance calculations
    public var poolLengthMeters: Double {
        switch self {
        case .scy: 22.86  // 25 yards
        case .scm: 25.0
        case .lcm: 50.0
        }
    }
}
