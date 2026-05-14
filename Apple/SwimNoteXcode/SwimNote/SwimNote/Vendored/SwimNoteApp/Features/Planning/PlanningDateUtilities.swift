import Foundation

/// Get next Monday from today
func nextMonday() -> Date {
    let calendar = Calendar.current
    let today = Date()
    let weekday = calendar.component(.weekday, from: today)

    // weekday: 1=Sunday, 2=Monday, ...
    let daysUntilMonday = weekday == 2 ? 0 : (9 - weekday) // If today is Monday, use today; else find next Monday
    return calendar.date(byAdding: .day, value: daysUntilMonday, to: today) ?? today
}
