import SwiftUI

// MARK: - Session Card

/// Refined session card with fluid animations and clear visual hierarchy
/// Designed for the Pantone 2026 pool theme - elegant, calm, water-inspired
///
/// Equatable conformance skips re-renders when visual state hasn't changed,
/// even if parent recreates closure callbacks.
struct SessionCard: View, Equatable {
    let session: DetailedSession
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onDateChange: ((Date) -> Void)?
    let showDatePicker: Bool
    let poolType: PoolType?
    let onDelete: (() -> Void)?
    let onComplete: (() -> Void)?

    init(
        session: DetailedSession,
        isExpanded: Bool,
        onToggleExpand: @escaping () -> Void,
        onDateChange: ((Date) -> Void)? = nil,
        showDatePicker: Bool = true,
        poolType: PoolType? = nil,
        onDelete: (() -> Void)? = nil,
        onComplete: (() -> Void)? = nil
    ) {
        self.session = session
        self.isExpanded = isExpanded
        self.onToggleExpand = onToggleExpand
        self.onDateChange = onDateChange
        self.showDatePicker = showDatePicker
        self.poolType = poolType
        self.onDelete = onDelete
        self.onComplete = onComplete
    }

    // Equatable: compare visual state only (ignore closures)
    static func == (lhs: SessionCard, rhs: SessionCard) -> Bool {
        lhs.session.id == rhs.session.id &&
        lhs.session.isCompleted == rhs.session.isCompleted &&
        lhs.session.isAssigned == rhs.session.isAssigned &&
        lhs.isExpanded == rhs.isExpanded &&
        lhs.poolType == rhs.poolType &&
        lhs.showDatePicker == rhs.showDatePicker
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header - always visible
            SessionHeader(
                sessionNumber: session.sessionNumber,
                focus: session.focus,
                goalRef: session.addressesGoal,
                isExpanded: isExpanded,
                isCompleted: session.isCompleted,
                onToggle: onToggleExpand,
                onDelete: onDelete,
                onComplete: onComplete
            )

            // Expanded content with animation
            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    Divider()
                        .background(PoolTheme.light.opacity(0.3))

                    // Summary bar
                    SessionSummaryBar(
                        sessionType: session.sessionType,
                        scheduledDate: session.scheduledDate,
                        timeOfDay: session.timeOfDay,
                        showDatePicker: showDatePicker,
                        onDateChange: onDateChange
                    )

                    // Segments - scrollable
                    ScrollView {
                        LazyVStack(spacing: Spacing.medium) {
                            SegmentView(
                                title: "Warm-up",
                                segment: session.warmUp,
                                icon: "figure.walk",
                                accentColor: .green,
                                poolType: poolType
                            )

                            SegmentView(
                                title: "Drill Set",
                                segment: session.drillSet,
                                icon: "figure.pool.swim",
                                accentColor: PoolTheme.mid,
                                poolType: poolType
                            )

                            if let secondary = session.secondarySet {
                                SegmentView(
                                    title: "Secondary",
                                    segment: secondary,
                                    icon: "plus.circle",
                                    accentColor: .purple,
                                    poolType: poolType
                                )
                            }

                            SegmentView(
                                title: "Main Set",
                                segment: session.mainSet,
                                icon: "flame",
                                accentColor: .orange,
                                poolType: poolType
                            )

                            SegmentView(
                                title: "Cool-down",
                                segment: session.coolDown,
                                icon: "wind",
                                accentColor: .blue,
                                poolType: poolType
                            )
                        }
                        .padding(Spacing.medium)
                    }
                    .frame(maxHeight: 420)

                    // Footer sections
                    if !session.techniqueFocus.isEmpty {
                        Divider()
                            .background(PoolTheme.light.opacity(0.3))
                        TechniqueFocusRow(focus: session.techniqueFocus)
                    }

                    if let notes = session.sessionNotes, !notes.isEmpty {
                        Divider()
                            .background(PoolTheme.light.opacity(0.3))
                        SessionNotesRow(notes: notes)
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
                    removal: .opacity
                ))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .fill(PoolTheme.surface)
                .shadow(color: PoolTheme.shadow, radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .strokeBorder(PoolTheme.border, lineWidth: 1)
        )
    }
}

// MARK: - Spacing & Radius Constants

private enum Spacing {
    static let tight: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let section: CGFloat = 20
}

private enum CornerRadius {
    static let small: CGFloat = 4
    static let medium: CGFloat = 8
    static let large: CGFloat = 12
    static let pill: CGFloat = 100
}

// MARK: - Header Component

private struct SessionHeader: View {
    let sessionNumber: Int
    let focus: String
    let goalRef: String?
    let isExpanded: Bool
    let isCompleted: Bool
    let onToggle: () -> Void
    let onDelete: (() -> Void)?
    let onComplete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main header row - use Button for proper gesture handling
            Button {
                onToggle()
            } label: {
                HStack(alignment: .center, spacing: Spacing.medium) {
                    SessionNumberBadge(number: sessionNumber, isCompleted: isCompleted)

                    Text(focus)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(isCompleted ? PoolTheme.smoke : PoolTheme.deep)
                        .lineLimit(2)

                    if isCompleted {
                        Text("Done")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.green.opacity(0.2))
                            .cornerRadius(4)
                    }

                    Spacer()

                    // Action buttons in header
                    HStack(spacing: 8) {
                        if let onComplete = onComplete, !isCompleted {
                            Button {
                                onComplete()
                            } label: {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.green)
                            }
                            .buttonStyle(.plain)
                        }

                        if let onDelete = onDelete {
                            Button {
                                onDelete()
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(.red.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(PoolTheme.smoke)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                }
                .padding(.horizontal, Spacing.large)
                .padding(.vertical, Spacing.medium)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Goal reference row (if exists)
            if let goalRef = goalRef {
                HStack(spacing: Spacing.small) {
                    Spacer().frame(width: 30 + Spacing.medium)

                    Image(systemName: "target")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PoolTheme.mid)

                    Text(goalRef)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(PoolTheme.smoke)
                        .lineLimit(2)

                    Spacer()
                }
                .padding(.horizontal, Spacing.large)
                .padding(.bottom, Spacing.small)
            }
        }
    }
}

// MARK: - Session Number Badge

private struct SessionNumberBadge: View {
    let number: Int
    let isCompleted: Bool

    init(number: Int, isCompleted: Bool = false) {
        self.number = number
        self.isCompleted = isCompleted
    }

    var body: some View {
        if isCompleted {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.green)
                .frame(width: 30, height: 30)
        } else {
            Text("\(number)")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .fill(PoolTheme.mid)
                )
        }
    }
}

// MARK: - Summary Bar Component

private struct SessionSummaryBar: View {
    let sessionType: String?
    let scheduledDate: Date?
    let timeOfDay: SessionTimeOfDay?
    let showDatePicker: Bool
    let onDateChange: ((Date) -> Void)?

    var body: some View {
        HStack(spacing: Spacing.large) {
            // Duration metric (placeholder - could be calculated)
            SummaryMetric(
                icon: "clock",
                value: "~60min",
                label: "Duration",
                color: PoolTheme.smoke
            )

            if let sessionType = sessionType {
                SummaryMetric(
                    icon: "figure.pool.swim",
                    value: sessionType,
                    label: "Type",
                    color: PoolTheme.deep
                )
            }

            // Time of day indicator (for double sessions)
            if let timeOfDay = timeOfDay {
                SummaryMetric(
                    icon: timeOfDayIcon(timeOfDay),
                    value: timeOfDay.displayName,
                    label: "Time",
                    color: timeOfDayColor(timeOfDay)
                )
            }

            // Date
            if showDatePicker && onDateChange != nil {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { scheduledDate ?? Date() },
                        set: { onDateChange?($0) }
                    ),
                    displayedComponents: .date
                )
                .labelsHidden()
                .scaleEffect(0.85)
                .tint(PoolTheme.mid)
            } else if let scheduledDate = scheduledDate {
                SummaryMetric(
                    icon: "calendar",
                    value: DateFormatter.weekdayDate.string(from: scheduledDate),
                    label: "Date",
                    color: PoolTheme.mid
                )
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.large)
        .padding(.vertical, Spacing.small + Spacing.tight)
        .background(
            PoolTheme.light.opacity(0.12)
        )
    }

    private func timeOfDayIcon(_ timeOfDay: SessionTimeOfDay) -> String {
        switch timeOfDay {
        case .morning: return "sunrise"
        case .afternoon: return "sun.max"
        case .evening: return "moon.stars"
        }
    }

    private func timeOfDayColor(_ timeOfDay: SessionTimeOfDay) -> Color {
        switch timeOfDay {
        case .morning: return .orange
        case .afternoon: return .yellow
        case .evening: return .indigo
        }
    }
}

private struct SummaryMetric: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.tight) {
            HStack(spacing: Spacing.tight) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(color)

            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(PoolTheme.smoke.opacity(0.7))
        }
    }
}

// MARK: - Segment View Component

private struct SegmentView: View {
    let title: String
    let segment: SessionSegment
    let icon: String
    let accentColor: Color
    let poolType: PoolType?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            // Segment header
            SegmentHeader(
                title: title,
                icon: icon,
                distance: segment.distance,
                accentColor: accentColor
            )

            // Sets list
            if let sets = segment.sets, !sets.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.small) {
                    ForEach(sets) { set in
                        SetRowView(set: set, accentColor: accentColor, poolType: poolType)
                    }
                }
            } else {
                Text(segment.description)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(PoolTheme.deep.opacity(0.8))
            }
        }
        .padding(Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(accentColor.opacity(0.08))
        )
    }
}

// MARK: - Segment Header

private struct SegmentHeader: View {
    let title: String
    let icon: String
    let distance: String
    let accentColor: Color

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.small) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(accentColor)

            // Title
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(accentColor)

            Spacer()

            // Distance pill
            Text(distance)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, Spacing.small)
                .padding(.vertical, Spacing.tight + 1)
                .background(
                    Capsule(style: .continuous)
                        .fill(accentColor)
                )
        }
    }
}

// MARK: - Set Row View

private struct SetRowView: View {
    let set: SetItem
    let accentColor: Color
    let poolType: PoolType?

    private var zoneColor: Color {
        switch set.zone ?? 0 {
        case 0: return .gray
        case 1: return .green
        case 2: return .cyan
        case 3: return .yellow
        case 4: return .orange
        case 5: return .red
        case 6: return .purple
        default: return .gray
        }
    }

    /// Format timing as swim/rest (e.g., "1:05/0:15")
    private var timingText: String? {
        if let swim = set.swimSeconds, let rest = set.restSeconds {
            return "\(formatSecondsAsTime(swim))/\(formatSecondsAsTime(rest))"
        } else if let swim = set.swimSeconds {
            return formatSecondsAsTime(swim)
        }
        return nil
    }

    /// Format distance with appropriate unit (yards or meters)
    private func formatDistance(_ meters: Int) -> String {
        if let pool = poolType, pool == .scy {
            let yards = Int(Double(meters) * 1.09361)
            return "\(yards)yd"
        }
        return "\(meters)m"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.tight + 2) {
            // Row 1: Zone + Timing + Rep×Distance
            HStack(alignment: .center, spacing: Spacing.small) {
                // Zone badge (color coded)
                if let zone = set.zone {
                    Text("Z\(zone)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(zoneColor)
                        )
                } else {
                    Text("—")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(PoolTheme.smoke)
                        .frame(width: 28)
                }

                // Swim/Rest timing
                if let timing = timingText {
                    Text(timing)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(PoolTheme.deep)
                }

                // Rep × Distance
                HStack(spacing: 2) {
                    Text("\(set.repeatCount)×")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(PoolTheme.deep)

                    if let dist = set.distancePerRep {
                        Text(formatDistance(dist))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(PoolTheme.deep)
                    } else {
                        Text("—")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(PoolTheme.smoke)
                    }
                }

                Spacer()
            }

            // Row 2: Item description + notes
            HStack(spacing: Spacing.tight) {
                if set.zone != nil {
                    Spacer()
                        .frame(width: 32)
                }

                Text(set.item)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(PoolTheme.smoke)

                if let notes = set.notes {
                    Text("· \(notes)")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(PoolTheme.smoke.opacity(0.7))
                }

                Spacer()
            }
        }
    }
}

// MARK: - Time Formatting

/// Format seconds as mm:ss (e.g., 65 → "1:05", 30 → "0:30")
private func formatSecondsAsTime(_ seconds: Int) -> String {
    let mins = seconds / 60
    let secs = seconds % 60
    return "\(mins):\(String(format: "%02d", secs))"
}

// MARK: - Technique Focus Row

private struct TechniqueFocusRow: View {
    let focus: String

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.small) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.yellow)

            Text(focus)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(PoolTheme.deep)
        }
        .padding(.horizontal, Spacing.large)
        .padding(.vertical, Spacing.medium)
        .background(PoolTheme.light.opacity(0.08))
    }
}

// MARK: - Session Notes Row

private struct SessionNotesRow: View {
    let notes: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(alignment: .center, spacing: Spacing.small) {
                Image(systemName: "note.text")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PoolTheme.smoke)

                Text("Notes")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(PoolTheme.smoke)
            }

            Text(notes)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(PoolTheme.deep.opacity(0.9))
        }
        .padding(.horizontal, Spacing.large)
        .padding(.vertical, Spacing.medium)
        .background(PoolTheme.light.opacity(0.08))
    }
}

// MARK: - Compact Session Card

/// Minimal compact card for dashboard and list views
struct SessionCompactCard: View {
    let session: DetailedSession
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                // Header row
                HStack(alignment: .center, spacing: Spacing.small) {
                    SessionNumberBadge(number: session.sessionNumber)

                    Text(session.focus)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(PoolTheme.deep)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(PoolTheme.light)
                }

                // Distance summary pills
                HStack(alignment: .center, spacing: Spacing.small) {
                    DistanceDot(distance: session.warmUp.distance, color: .green)
                    DistanceDot(distance: session.mainSet.distance, color: .orange)

                    if let secondary = session.secondarySet {
                        DistanceDot(distance: secondary.distance, color: .purple)
                    }

                    DistanceDot(distance: session.coolDown.distance, color: .blue)
                }

                // Technique focus hint
                if !session.techniqueFocus.isEmpty {
                    HStack(alignment: .center, spacing: Spacing.tight) {
                        Image(systemName: "lightbulb")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(PoolTheme.mid)

                        Text(session.techniqueFocus)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(PoolTheme.mid)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .poolCard()
        }
        .buttonStyle(.plain)
    }
}

private struct DistanceDot: View {
    let distance: String
    let color: Color

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.tight) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(distance)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(PoolTheme.smoke)
    }
}

// MARK: - Previews

#Preview("Session Card - Expanded (with CSS timing)") {
    let session = DetailedSession(
        id: "session-1",
        sessionNumber: 1,
        focus: "Freestyle Sprint Focus",
        warmUp: SessionSegment(
            distance: "400m",
            description: "Easy swim, progressive build",
            sets: [
                SetItem(repeatCount: 4, distancePerRep: 100, swimSeconds: 95, restSeconds: 15, item: "freestyle easy", notes: "build last 2", zone: 1)
            ]
        ),
        drillSet: SessionSegment(
            distance: "200m",
            description: "6-1-6 drill",
            sets: [
                SetItem(repeatCount: 4, distancePerRep: 50, swimSeconds: 50, restSeconds: 10, item: "6-1-6 drill", notes: "breathing every 6", zone: 2)
            ]
        ),
        mainSet: SessionSegment(
            distance: "800m",
            description: "Threshold work",
            sets: [
                SetItem(repeatCount: 4, distancePerRep: 200, swimSeconds: 160, restSeconds: 20, item: "freestyle", notes: "hold pace", zone: 4),
                SetItem(repeatCount: 4, distancePerRep: 50, swimSeconds: 35, restSeconds: 40, item: "pace bursts", notes: "sprint", zone: 5)
            ]
        ),
        secondarySet: SessionSegment(
            distance: "300m",
            description: "Backstroke easy",
            sets: [
                SetItem(repeatCount: 3, distancePerRep: 100, swimSeconds: 90, restSeconds: 15, item: "backstroke", zone: 2)
            ]
        ),
        coolDown: SessionSegment(
            distance: "200m",
            description: "Easy swim",
            sets: [
                SetItem(repeatCount: 4, distancePerRep: 50, swimSeconds: 60, restSeconds: 60, item: "easy choice", zone: 0)
            ]
        ),
        techniqueFocus: "High elbow catch and body rotation",
        techniqueFileRef: nil,
        addressesGoal: nil,
        sessionType: "Sprint",
        progressionRationale: nil,
        sessionNotes: "Focus on maintaining pace through final 50m of each rep",
        scheduledDate: Date()
    )

    SessionCard(
        session: session,
        isExpanded: true,
        onToggleExpand: {},
        onDateChange: nil,
        showDatePicker: false,
        poolType: nil
    )
    .padding()
    .background(PoolTheme.surface)
}

#Preview("Session Card - No CSS (effort % only)") {
    let session = DetailedSession(
        id: "session-2",
        sessionNumber: 2,
        focus: "Backstroke Technique",
        warmUp: SessionSegment(
            distance: "300m",
            description: "Easy freestyle",
            sets: [
                SetItem(repeatCount: 6, distancePerRep: 50, restSeconds: 15, item: "easy freestyle", notes: "60% effort", zone: 1)
            ]
        ),
        drillSet: SessionSegment(
            distance: "150m",
            description: "Single-arm backstroke",
            sets: [
                SetItem(repeatCount: 3, distancePerRep: 50, restSeconds: 12, item: "single-arm back", notes: "focus on rotation", zone: 2)
            ]
        ),
        mainSet: SessionSegment(
            distance: "600m",
            description: "3x200m backstroke",
            sets: [
                SetItem(repeatCount: 3, distancePerRep: 200, restSeconds: 15, item: "backstroke swim", notes: "75% effort", zone: 3)
            ]
        ),
        coolDown: SessionSegment(
            distance: "150m",
            description: "Easy choice",
            sets: [
                SetItem(repeatCount: 3, distancePerRep: 50, restSeconds: 60, item: "easy choice", notes: "50% effort", zone: 0)
            ]
        ),
        techniqueFocus: "Horizontal body position",
        techniqueFileRef: nil,
        addressesGoal: "Maintain horizontal body position",
        sessionType: "Technique",
        progressionRationale: nil,
        sessionNotes: nil,
        scheduledDate: Date()
    )

    SessionCard(
        session: session,
        isExpanded: true,
        onToggleExpand: {},
        onDateChange: nil,
        showDatePicker: false
    )
    .padding()
    .background(PoolTheme.surface)
}

#Preview("Session Card - Collapsed with Actions") {
    let session = DetailedSession(
        id: "session-3",
        sessionNumber: 3,
        focus: "IM Transition Work",
        warmUp: SessionSegment(distance: "300m", description: "Mixed warm-up"),
        drillSet: SessionSegment(distance: "150m", description: "Transition drills"),
        mainSet: SessionSegment(distance: "500m", description: "IM sets"),
        coolDown: SessionSegment(distance: "150m", description: "Easy swim"),
        techniqueFocus: "",
        techniqueFileRef: nil,
        addressesGoal: nil,
        sessionType: "IM",
        progressionRationale: nil,
        sessionNotes: nil,
        scheduledDate: Date()
    )

    SessionCard(
        session: session,
        isExpanded: false,
        onToggleExpand: {},
        onDateChange: nil,
        showDatePicker: false,
        onDelete: { print("Delete tapped") },
        onComplete: { print("Complete tapped") }
    )
    .padding()
    .background(PoolTheme.surface)
}

#Preview("Compact Session Card") {
    let session = DetailedSession(
        id: "session-1",
        sessionNumber: 1,
        focus: "Freestyle Sprint Focus",
        warmUp: SessionSegment(distance: "400m", description: "Easy swim"),
        drillSet: SessionSegment(distance: "200m", description: "6-1-6 drill"),
        mainSet: SessionSegment(distance: "800m", description: "4x200m threshold"),
        secondarySet: SessionSegment(distance: "300m", description: "3x100m back"),
        coolDown: SessionSegment(distance: "200m", description: "Easy swim"),
        techniqueFocus: "High elbow catch",
        techniqueFileRef: nil,
        addressesGoal: nil,
        sessionType: nil,
        progressionRationale: nil,
        sessionNotes: nil,
        scheduledDate: Date()
    )

    SessionCompactCard(session: session, onTap: {})
        .padding()
        .background(PoolTheme.surface)
}

#Preview("Dark Mode - Expanded") {
    let session = DetailedSession(
        id: "session-1",
        sessionNumber: 1,
        focus: "Freestyle Sprint Focus",
        warmUp: SessionSegment(
            distance: "400m",
            description: "Easy swim",
            sets: [
                SetItem(repeatCount: 4, distancePerRep: 100, swimSeconds: 95, restSeconds: 15, item: "freestyle easy", notes: "build last 2", zone: 1)
            ]
        ),
        drillSet: SessionSegment(
            distance: "200m",
            description: "6-1-6 drill",
            sets: [
                SetItem(repeatCount: 4, distancePerRep: 50, swimSeconds: 50, restSeconds: 10, item: "6-1-6 drill", zone: 2)
            ]
        ),
        mainSet: SessionSegment(
            distance: "800m",
            description: "Threshold",
            sets: [
                SetItem(repeatCount: 4, distancePerRep: 200, swimSeconds: 160, restSeconds: 20, item: "freestyle", notes: "hold pace", zone: 4),
                SetItem(repeatCount: 4, distancePerRep: 50, swimSeconds: 35, restSeconds: 40, item: "pace bursts", zone: 5)
            ]
        ),
        coolDown: SessionSegment(
            distance: "200m",
            description: "Easy",
            sets: [
                SetItem(repeatCount: 4, distancePerRep: 50, swimSeconds: 60, restSeconds: 60, item: "easy choice", zone: 0)
            ]
        ),
        techniqueFocus: "High elbow catch",
        techniqueFileRef: nil,
        addressesGoal: nil,
        sessionType: "Sprint",
        progressionRationale: nil,
        sessionNotes: "Focus on maintaining pace through final 50m",
        scheduledDate: Date()
    )

    VStack {
        Text("Light Mode")
            .font(.caption)
        SessionCard(session: session, isExpanded: true, onToggleExpand: {}, onDateChange: nil, showDatePicker: false, poolType: nil)
            .padding()
            .background(PoolTheme.surface)
            .environment(\.colorScheme, .light)

        Divider()

        Text("Dark Mode")
            .font(.caption)
        SessionCard(session: session, isExpanded: true, onToggleExpand: {}, onDateChange: nil, showDatePicker: false, poolType: nil)
            .padding()
            .background(PoolTheme.surface)
            .environment(\.colorScheme, .dark)
    }
}

#Preview("Dark Mode - Compact Card") {
    let session = DetailedSession(
        id: "session-1",
        sessionNumber: 1,
        focus: "Freestyle Sprint",
        warmUp: SessionSegment(distance: "400m", description: "Easy"),
        drillSet: SessionSegment(distance: "200m", description: "Drill"),
        mainSet: SessionSegment(distance: "800m", description: "Main"),
        coolDown: SessionSegment(distance: "200m", description: "Cool"),
        techniqueFocus: "High elbow",
        techniqueFileRef: nil,
        addressesGoal: nil,
        sessionType: nil,
        progressionRationale: nil,
        sessionNotes: nil,
        scheduledDate: Date()
    )

    HStack(spacing: 20) {
        VStack {
            Text("Light").font(.caption)
            SessionCompactCard(session: session, onTap: {})
                .background(PoolTheme.surface)
                .environment(\.colorScheme, .light)
        }

        VStack {
            Text("Dark").font(.caption)
            SessionCompactCard(session: session, onTap: {})
                .background(PoolTheme.surface)
                .environment(\.colorScheme, .dark)
        }
    }
    .padding()
}

#Preview("25yd Pool - Distance Conversion") {
    let session = DetailedSession(
        id: "session-yd",
        sessionNumber: 1,
        focus: "Freestyle Sprint Focus",
        warmUp: SessionSegment(
            distance: "437yd",  // ~400m converted
            description: "Easy swim",
            sets: [
                SetItem(repeatCount: 4, distancePerRep: 100, swimSeconds: 95, restSeconds: 15, item: "freestyle easy", zone: 1)
            ]
        ),
        drillSet: SessionSegment(
            distance: "218yd",  // ~200m converted
            description: "Drill work",
            sets: [
                SetItem(repeatCount: 4, distancePerRep: 50, swimSeconds: 50, restSeconds: 10, item: "6-1-6 drill", zone: 2)
            ]
        ),
        mainSet: SessionSegment(
            distance: "874yd",  // ~800m converted
            description: "Threshold",
            sets: [
                SetItem(repeatCount: 4, distancePerRep: 200, swimSeconds: 160, restSeconds: 20, item: "freestyle", notes: "hold pace", zone: 4)
            ]
        ),
        coolDown: SessionSegment(
            distance: "218yd",
            description: "Easy",
            sets: [
                SetItem(repeatCount: 4, distancePerRep: 50, swimSeconds: 60, restSeconds: 60, item: "easy choice", zone: 0)
            ]
        ),
        techniqueFocus: "High elbow catch",
        techniqueFileRef: nil,
        addressesGoal: nil,
        sessionType: "Sprint",
        progressionRationale: nil,
        sessionNotes: nil,
        scheduledDate: Date()
    )

    VStack {
        Text("25m Pool (meters)")
            .font(.caption.bold())
        SessionCard(
            session: session,
            isExpanded: true,
            onToggleExpand: {},
            onDateChange: nil,
            showDatePicker: false,
            poolType: .scm
        )
        .padding()
        .background(PoolTheme.surface)

        Divider()

        Text("25yd Pool (SCY)")
            .font(.caption.bold())
        SessionCard(
            session: session,
            isExpanded: true,
            onToggleExpand: {},
            onDateChange: nil,
            showDatePicker: false,
            poolType: .scy
        )
        .padding()
        .background(PoolTheme.surface)
    }
}