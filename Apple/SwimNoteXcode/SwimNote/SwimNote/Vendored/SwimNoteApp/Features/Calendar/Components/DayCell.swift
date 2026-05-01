import SwiftUI

/// Calendar day cell with indicators for sessions, dry land, and content
struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let hasContent: Bool
    let hasSession: Bool
    let hasDryLand: Bool
    let isToday: Bool
    let onTap: () -> Void

    private let calendar = Calendar.current

    private var dayNumber: String {
        String(calendar.component(.day, from: date))
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Selection or today indicator
                if isSelected {
                    Circle()
                        .fill(PoolTheme.mid)
                        .frame(width: 32, height: 32)
                } else if isToday {
                    Circle()
                        .stroke(PoolTheme.mid, lineWidth: 2)
                        .frame(width: 32, height: 32)
                }

                // Day number
                Text(dayNumber)
                    .font(.system(size: 14, weight: isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? .white : PoolTheme.deep)

                // Indicators below the day number
                if hasSession || hasDryLand {
                    HStack(spacing: 3) {
                        // Session indicator (teal dot)
                        if hasSession {
                            Circle()
                                .fill(PoolTheme.mid)
                                .frame(width: 5, height: 5)
                        }
                        // Dry land indicator (orange dot)
                        if hasDryLand {
                            Circle()
                                .fill(.orange)
                                .frame(width: 5, height: 5)
                        }
                    }
                    .offset(y: 12)
                } else if hasContent {
                    // Other content indicator (light blue dot)
                    Circle()
                        .fill(PoolTheme.light)
                        .frame(width: 4, height: 4)
                        .offset(y: 12)
                }
            }
            .frame(height: 36)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Day Cells") {
    HStack(spacing: 8) {
        DayCell(date: Date(), isSelected: true, hasContent: true, hasSession: true, hasDryLand: false, isToday: true, onTap: {})
        DayCell(date: Date(), isSelected: false, hasContent: true, hasSession: false, hasDryLand: true, isToday: true, onTap: {})
        DayCell(date: Date(), isSelected: false, hasContent: false, hasSession: false, hasDryLand: false, isToday: false, onTap: {})
        DayCell(date: Date(), isSelected: false, hasContent: true, hasSession: true, hasDryLand: true, isToday: false, onTap: {})
    }
    .padding()
    .background(PoolTheme.surface)
}