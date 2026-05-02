import SwiftUI

/// Collapsible goal row that shows simple goals inline and competitive goals as expandable
/// Equatable: skips re-renders when goal visual state unchanged
struct CollapsibleGoalRow: View, Equatable {
    let goal: Goal
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onUpdateStatus: (GoalStatus) -> Void
    let onDelete: () -> Void
    let onEditNotes: () -> Void

    // Equatable: compare goal visual state only
    static func == (lhs: CollapsibleGoalRow, rhs: CollapsibleGoalRow) -> Bool {
        lhs.goal.id == rhs.goal.id &&
        lhs.goal.status == rhs.goal.status &&
        lhs.goal.notes == rhs.goal.notes &&
        lhs.isExpanded == rhs.isExpanded
    }

    var body: some View {
        if let snapshot = goal.competitiveDrillSnapshot {
            CompetitiveGoalRow(
                goal: goal,
                snapshot: snapshot,
                isExpanded: isExpanded,
                onToggleExpand: onToggleExpand,
                onUpdateStatus: onUpdateStatus,
                onDelete: onDelete,
                onEditNotes: onEditNotes
            )
        } else {
            SimpleGoalRow(
                goal: goal,
                onUpdateStatus: onUpdateStatus,
                onDelete: onDelete,
                onEditNotes: onEditNotes
            )
        }
    }
}

/// Simple goal row for key points, mistakes, and basic text goals
/// Equatable: skips re-renders when goal state unchanged
struct SimpleGoalRow: View, Equatable {
    let goal: Goal
    let onUpdateStatus: (GoalStatus) -> Void
    let onDelete: () -> Void
    let onEditNotes: () -> Void

    static func == (lhs: SimpleGoalRow, rhs: SimpleGoalRow) -> Bool {
        lhs.goal.id == rhs.goal.id &&
        lhs.goal.status == rhs.goal.status &&
        lhs.goal.notes == rhs.goal.notes
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Status menu
            statusMenu

            // Goal description
            VStack(alignment: .leading, spacing: 2) {
                Text(goal.description)
                    .font(.subheadline.bold())
                    .foregroundStyle(PoolTheme.deep)

                if let notes = goal.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(PoolTheme.smoke)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Notes button
            notesButton
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
    }

    private var statusMenu: some View {
        Menu {
            Button { onUpdateStatus(.planned) } label: {
                Label("Planned", systemImage: "circle")
            }
            Button { onUpdateStatus(.inProgress) } label: {
                Label("In Progress", systemImage: "circle.lefthalf.filled")
            }
            Button { onUpdateStatus(.achieved) } label: {
                Label("Achieved", systemImage: "checkmark.circle.fill")
            }
            Button { onUpdateStatus(.unableToAchieve) } label: {
                Label("Unable", systemImage: "xmark.circle.fill")
            }
            Divider()
            Button(role: .destructive) { onDelete() } label: {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: statusIcon(goal.status))
                .font(.title2)
                .foregroundStyle(statusColor(goal.status))
        }
        .buttonStyle(.plain)
    }

    private var notesButton: some View {
        Button {
            onEditNotes()
        } label: {
            Image(systemName: goal.notes?.isEmpty == false ? "note.text.fill" : "square.and.pencil")
                .font(.title3)
                .foregroundStyle(goal.notes?.isEmpty == false ? PoolTheme.mid : PoolTheme.smoke)
        }
        .buttonStyle(.plain)
    }

    private func statusIcon(_ status: GoalStatus) -> String {
        switch status {
        case .planned: "circle"
        case .inProgress: "circle.lefthalf.filled"
        case .achieved: "checkmark.circle.fill"
        case .unableToAchieve: "xmark.circle.fill"
        }
    }

    private func statusColor(_ status: GoalStatus) -> Color {
        switch status {
        case .planned: PoolTheme.smoke
        case .inProgress: .orange
        case .achieved: .green
        case .unableToAchieve: .red
        }
    }
}

/// Expandable goal row for competitive drill goals with tier targets
/// Equatable: skips re-renders when goal and snapshot state unchanged
struct CompetitiveGoalRow: View, Equatable {
    let goal: Goal
    let snapshot: CompetitiveDrillSnapshot
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onUpdateStatus: (GoalStatus) -> Void
    let onDelete: () -> Void
    let onEditNotes: () -> Void

    private let tierOrder: [String] = ["Beginner", "Intermediate", "Advanced", "Elite"]

    // Equatable: compare visual state only
    static func == (lhs: CompetitiveGoalRow, rhs: CompetitiveGoalRow) -> Bool {
        lhs.goal.id == rhs.goal.id &&
        lhs.goal.status == rhs.goal.status &&
        lhs.goal.notes == rhs.goal.notes &&
        lhs.snapshot.selectedTier == rhs.snapshot.selectedTier &&
        lhs.isExpanded == rhs.isExpanded
    }

    private var sortedTiers: [(String, String)] {
        tierOrder.compactMap { tier in
            snapshot.tieredTargets[tier].map { (tier, $0) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row (collapsed view)
            headerRow

            // Expanded content
            if isExpanded {
                expandedContent
            }
        }
        .background(PoolTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(PoolTheme.light.opacity(0.5), lineWidth: 1)
        )
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 12) {
            // Status menu
            statusMenu

            // Drill name + tier badge
            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(PoolTheme.deep)

                // Selected tier badge
                HStack(spacing: 4) {
                    Text(snapshot.selectedTier)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(PoolTheme.mid)
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    Text(snapshot.selectedTarget)
                        .font(.caption)
                        .foregroundStyle(PoolTheme.smoke)
                }
            }

            Spacer()

            // Expand indicator
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(PoolTheme.smoke)
                .frame(width: 20)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggleExpand()
        }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            // Self-check
            if !snapshot.selfCheck.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "eye")
                        .font(.caption)
                        .foregroundStyle(PoolTheme.mid)
                    Text("Self-Check: \(snapshot.selfCheck)")
                        .font(.subheadline)
                        .foregroundStyle(PoolTheme.deep)
                }
                .padding(.horizontal, 12)
            }

            // All tier targets
            if !sortedTiers.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    if !snapshot.tieredTargetsTitle.isEmpty {
                        Text(snapshot.tieredTargetsTitle)
                            .font(.caption.bold())
                            .foregroundStyle(PoolTheme.mid)
                            .padding(.horizontal, 12)
                    }

                    ForEach(sortedTiers, id: \.0) { tier, target in
                        HStack(spacing: 8) {
                            Text(tier)
                                .font(.caption)
                                .foregroundStyle(tier == snapshot.selectedTier ? PoolTheme.mid : PoolTheme.smoke)
                                .bold(tier == snapshot.selectedTier)

                            Text(target)
                                .font(.caption)
                                .foregroundStyle(PoolTheme.deep)

                            if tier == snapshot.selectedTier {
                                Image(systemName: "checkmark")
                                    .font(.caption)
                                    .foregroundStyle(PoolTheme.mid)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 12)
                    }
                }
            }

            // Video checks
            if !snapshot.videoChecks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Video Checks")
                        .font(.caption.bold())
                        .foregroundStyle(PoolTheme.smoke)
                        .padding(.horizontal, 12)

                    ForEach(snapshot.videoChecks, id: \.self) { check in
                        HStack(spacing: 6) {
                            Image(systemName: "video")
                                .font(.caption2)
                                .foregroundStyle(PoolTheme.smoke)
                            Text(check)
                                .font(.caption)
                                .foregroundStyle(PoolTheme.deep)
                        }
                        .padding(.horizontal, 12)
                    }
                }
            }

            // Competitive impact
            if !snapshot.competitiveImpact.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "trophy")
                        .font(.caption)
                        .foregroundStyle(PoolTheme.gold)
                    Text("Impact: \(snapshot.competitiveImpact)")
                        .font(.subheadline)
                        .foregroundStyle(PoolTheme.deep)
                }
                .padding(.horizontal, 12)
            }

            // Notes section
            Divider()
            HStack {
                Button { onEditNotes() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: goal.notes?.isEmpty == false ? "note.text.fill" : "square.and.pencil")
                        Text(goal.notes?.isEmpty == false ? "View Notes" : "Add Notes")
                    }
                    .font(.caption)
                    .foregroundStyle(goal.notes?.isEmpty == false ? PoolTheme.mid : PoolTheme.smoke)
                }
                .buttonStyle(.plain)

                Spacer()

                if let notes = goal.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(PoolTheme.smoke)
                        .lineLimit(2)
                        .frame(maxWidth: 150, alignment: .trailing)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }

    private var statusMenu: some View {
        Menu {
            Button { onUpdateStatus(.planned) } label: {
                Label("Planned", systemImage: "circle")
            }
            Button { onUpdateStatus(.inProgress) } label: {
                Label("In Progress", systemImage: "circle.lefthalf.filled")
            }
            Button { onUpdateStatus(.achieved) } label: {
                Label("Achieved", systemImage: "checkmark.circle.fill")
            }
            Button { onUpdateStatus(.unableToAchieve) } label: {
                Label("Unable", systemImage: "xmark.circle.fill")
            }
            Divider()
            Button(role: .destructive) { onDelete() } label: {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: statusIcon(goal.status))
                .font(.title2)
                .foregroundStyle(statusColor(goal.status))
        }
        .buttonStyle(.plain)
    }

    private func statusIcon(_ status: GoalStatus) -> String {
        switch status {
        case .planned: "circle"
        case .inProgress: "circle.lefthalf.filled"
        case .achieved: "checkmark.circle.fill"
        case .unableToAchieve: "xmark.circle.fill"
        }
    }

    private func statusColor(_ status: GoalStatus) -> Color {
        switch status {
        case .planned: PoolTheme.smoke
        case .inProgress: .orange
        case .achieved: .green
        case .unableToAchieve: .red
        }
    }
}

#Preview("Simple Goal") {
    let goal = Goal(
        id: "goal-1",
        type: .technique,
        strokeId: .freestyle,
        description: "High elbow catch",
        status: .inProgress,
        notes: nil,
        goalKind: .keyPoint,
        createdAt: "2024-01-01T00:00:00Z",
        updatedAt: "2024-01-01T00:00:00Z"
    )

    SimpleGoalRow(
        goal: goal,
        onUpdateStatus: { _ in },
        onDelete: {},
        onEditNotes: {}
    )
    .padding()
    .background(PoolTheme.surface)
}

#Preview("Competitive Goal - Collapsed") {
    let snapshot = CompetitiveDrillSnapshot(
        drillId: "drill-1",
        name: "Distance Per Stroke",
        selfCheck: "Count strokes per lap",
        tieredTargetsTitle: "Stroke Count Efficiency",
        tieredTargets: ["Beginner": "12 strokes", "Intermediate": "10 strokes", "Advanced": "8 strokes", "Elite": "6 strokes"],
        videoChecks: ["Check entry angle", "Watch recovery"],
        competitiveImpact: "Improves efficiency and reduces fatigue",
        selectedTier: "Intermediate",
        selectedTarget: "10 strokes"
    )

    let goal = Goal(
        id: "goal-2",
        type: .technique,
        strokeId: .freestyle,
        description: "Distance Per Stroke",
        status: .planned,
        notes: nil,
        goalKind: .competitiveMetric,
        competitiveDrillSnapshot: snapshot,
        createdAt: "2024-01-01T00:00:00Z",
        updatedAt: "2024-01-01T00:00:00Z"
    )

    CompetitiveGoalRow(
        goal: goal,
        snapshot: snapshot,
        isExpanded: false,
        onToggleExpand: {},
        onUpdateStatus: { _ in },
        onDelete: {},
        onEditNotes: {}
    )
    .padding()
    .background(PoolTheme.surface)
}

#Preview("Competitive Goal - Expanded") {
    let snapshot = CompetitiveDrillSnapshot(
        drillId: "drill-1",
        name: "Distance Per Stroke",
        selfCheck: "Count strokes per lap - aim for consistent count",
        tieredTargetsTitle: "Stroke Count Efficiency (25m pool)",
        tieredTargets: ["Beginner": "12-14 strokes", "Intermediate": "10-12 strokes", "Advanced": "8-10 strokes", "Elite": "6-8 strokes"],
        videoChecks: ["Check hand entry angle", "Watch recovery smoothness", "Verify full extension"],
        competitiveImpact: "Reduces stroke count by 2-3 strokes per lap, improving race times by 3-5 seconds in 100m events",
        selectedTier: "Intermediate",
        selectedTarget: "10-12 strokes"
    )

    let goal = Goal(
        id: "goal-3",
        type: .technique,
        strokeId: .freestyle,
        description: "Distance Per Stroke",
        status: .inProgress,
        notes: "Focusing on longer glide phase",
        goalKind: .competitiveMetric,
        competitiveDrillSnapshot: snapshot,
        createdAt: "2024-01-01T00:00:00Z",
        updatedAt: "2024-01-01T00:00:00Z"
    )

    CompetitiveGoalRow(
        goal: goal,
        snapshot: snapshot,
        isExpanded: true,
        onToggleExpand: {},
        onUpdateStatus: { _ in },
        onDelete: {},
        onEditNotes: {}
    )
    .padding()
    .background(PoolTheme.surface)
}