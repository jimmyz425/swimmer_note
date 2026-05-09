import SwiftUI

// MARK: - Plan History View

struct PlanHistoryView: View {
    let appModel: SwimNoteAppModel
    @Binding var selectedPlan: WeeklyTrainingPlan?
    @Environment(\.dismiss) private var dismiss

    private var sortedPlans: [WeeklyTrainingPlan] {
        appModel.weeklyPlans.sorted { ($0.weekStartingDate ?? .distantPast) > ($1.weekStartingDate ?? .distantPast) }
    }

    var body: some View {
        NavigationStack {
            List {
                if sortedPlans.isEmpty {
                    ContentUnavailableView(
                        "No Saved Plans",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("Generate and save a training plan to view it here")
                    )
                } else {
                    ForEach(sortedPlans) { plan in
                        Button {
                            selectedPlan = plan
                            dismiss()
                        } label: {
                            PlanHistoryRow(plan: plan)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Plan History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Plan History Row

struct PlanHistoryRow: View {
    let plan: WeeklyTrainingPlan

    private var weekStartString: String {
        DateFormatter.monthDayYear.string(from: plan.weekStartingDate ?? .distantPast)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(weekStartString)
                    .font(.headline)
                    .foregroundStyle(PoolTheme.deep)

                Spacer()

                Text("\(plan.detailedSessions.count) sessions")
                    .font(.caption)
                    .foregroundStyle(PoolTheme.mid)
            }

            Text(plan.overview.weekFocus)
                .font(.subheadline)
                .foregroundStyle(PoolTheme.smoke)
                .lineLimit(2)

            HStack(spacing: 12) {
                Label(plan.overview.poolType ?? "Pool", systemImage: "water.waves")
                    .font(.caption)
                    .foregroundStyle(PoolTheme.mid)

                if let dryLand = plan.dryLandProgram, !dryLand.isEmpty {
                    Label("\(dryLand.count) dry land", systemImage: "figure.strengthtraining.traditional")
                        .font(.caption)
                        .foregroundStyle(PoolTheme.mid)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Plan Detail View

struct PlanDetailView: View {
    let plan: WeeklyTrainingPlan
    let appModel: SwimNoteAppModel
    @Environment(\.dismiss) private var dismiss
    @State private var expandedSessions: Set<Int> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Week info
                    weekInfoSection

                    // Sessions
                    sessionsSection

                    // Dry Land (if present)
                    dryLandSection
                }
                .padding()
            }
            .navigationTitle("Plan Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var weekInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(PoolTheme.mid)
                Text(formatWeekRange())
                    .font(.headline)
                    .foregroundStyle(PoolTheme.deep)
            }

            Text(plan.overview.weekFocus)
                .font(.subheadline)
                .foregroundStyle(PoolTheme.smoke)

            HStack(spacing: 16) {
                statBadge(icon: "figure.pool.swim", value: "\(plan.detailedSessions.count)", label: "Sessions")
                statBadge(icon: "water.waves", value: plan.overview.poolType ?? "25m", label: "Pool")

                if let dryLand = plan.dryLandProgram, !dryLand.isEmpty {
                    statBadge(icon: "figure.strengthtraining.traditional", value: "\(dryLand.count)", label: "Dry Land")
                }
            }
        }
        .poolCard()
    }

    private func formatWeekRange() -> String {
        guard let startDate = plan.weekStartingDate else { return "Unknown week" }
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .day, value: 6, to: startDate) ?? startDate

        return "\(DateFormatter.shortMonthDay.string(from: startDate)) - \(DateFormatter.shortMonthDay.string(from: endDate))"
    }

    private func statBadge(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(PoolTheme.mid)
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(PoolTheme.deep)
            Text(label)
                .font(.caption2)
                .foregroundStyle(PoolTheme.smoke)
        }
        .frame(maxWidth: .infinity)
    }

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Training Sessions")
                .font(.headline)
                .foregroundStyle(PoolTheme.deep)

            LazyVStack(spacing: 12) {
                ForEach(plan.detailedSessions) { session in
                    SessionCard(
                        session: session,
                        isExpanded: expandedSessions.contains(session.sessionNumber),
                        onToggleExpand: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                if expandedSessions.contains(session.sessionNumber) {
                                    expandedSessions.remove(session.sessionNumber)
                                } else {
                                    expandedSessions.insert(session.sessionNumber)
                                }
                            }
                        },
                        onDateChange: nil,
                        showDatePicker: false
                    )
                }
            }
        }
        .poolCard()
    }

    private var dryLandSection: some View {
        guard let dryLand = plan.dryLandProgram, !dryLand.isEmpty else {
            return AnyView(EmptyView())
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("Dry Land Exercises")
                    .font(.headline)
                    .foregroundStyle(PoolTheme.deep)

                LazyVStack(spacing: 8) {
                    ForEach(dryLand) { exercise in
                        DryLandExerciseRow(exercise: exercise)
                    }
                }
            }
            .poolCard()
        )
    }
}

#Preview("Plan History") {
    PlanHistoryView(appModel: SwimNoteAppModel.bootstrap(), selectedPlan: Binding.constant(nil))
}

#Preview("Plan Detail") {
    let plan = WeeklyTrainingPlan(
        overview: PlanOverview(weekFocus: "Backstroke technique week"),
        schedule: [],
        detailedSessions: [],
        dryLandProgram: nil,
        weeklyGoals: nil,
        techniqueProgressPlan: nil,
        notes: "",
        weekStartingDate: Date()
    )
    PlanDetailView(plan: plan, appModel: SwimNoteAppModel.bootstrap())
}