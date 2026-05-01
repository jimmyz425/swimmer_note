import SwiftUI

/// Badge displaying goal status with appropriate color and icon
struct GoalStatusBadge: View {
    let status: GoalStatus

    var color: Color {
        switch status {
        case .planned: return PoolTheme.mid
        case .inProgress: return .blue
        case .achieved: return .green
        case .unableToAchieve: return .red
        }
    }

    var icon: String {
        switch status {
        case .planned: return "circle"
        case .inProgress: return "circle.lefthalf.filled"
        case .achieved: return "checkmark.circle.fill"
        case .unableToAchieve: return "xmark.circle.fill"
        }
    }

    var body: some View {
        Image(systemName: icon)
            .font(.caption)
            .foregroundStyle(color)
    }
}

#Preview("Goal Status Badges") {
    HStack(spacing: 12) {
        GoalStatusBadge(status: .planned)
        GoalStatusBadge(status: .inProgress)
        GoalStatusBadge(status: .achieved)
        GoalStatusBadge(status: .unableToAchieve)
    }
    .padding()
    .background(PoolTheme.surface)
}