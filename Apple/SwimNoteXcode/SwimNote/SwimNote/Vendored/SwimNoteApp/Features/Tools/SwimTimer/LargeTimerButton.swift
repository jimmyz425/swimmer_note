import SwiftUI

/// Large touch-friendly button for poolside timer controls
/// Designed for easy tapping during swim practice
struct LargeTimerButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .medium))
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }
            .frame(minWidth: 110, minHeight: 90)
            .foregroundStyle(.white)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .heavy), trigger: title)
    }
}

// MARK: - Preview

#Preview("Timer Buttons") {
    HStack(spacing: 16) {
        LargeTimerButton(
            title: "START",
            icon: "play.fill",
            color: PoolTheme.mid,
            action: {}
        )

        LargeTimerButton(
            title: "STOP",
            icon: "stop.fill",
            color: .red,
            action: {}
        )

        LargeTimerButton(
            title: "SPLIT",
            icon: "flag.fill",
            color: PoolTheme.gold,
            action: {}
        )

        LargeTimerButton(
            title: "RESET",
            icon: "arrow.counterclockwise",
            color: PoolTheme.smoke,
            action: {}
        )
    }
    .padding()
    .background(PoolTheme.surface)
}