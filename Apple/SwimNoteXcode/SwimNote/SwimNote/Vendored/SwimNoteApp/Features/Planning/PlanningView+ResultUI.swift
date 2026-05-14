import SwiftUI
import UIKit

extension PlanningView {
    @ViewBuilder
    var resultSection: some View {
        if let plan = parsedPlan {
            VStack(alignment: .leading, spacing: 20) {
                // Summary Stats Bar
                summaryStatsBar(plan)

                // Overview Hero Card
                overviewHeroCard(plan)

                // Goal Progress (collapsible)
                if let techniquePlan = plan.techniqueProgressPlan {
                    techniqueProgressCollapsible(techniquePlan)
                }

                // Sessions Grid
                sessionsGrid(plan)

                // Dry Land Section (if included)
                if let dryLand = plan.dryLandProgram, !dryLand.isEmpty {
                    dryLandCard(dryLand)
                }

                // Notes
                if !plan.notes.isEmpty {
                    notesCard(plan.notes)
                }

                // Save Button
                savePlanButton(plan)

                // Debug toggle
                debugToggle
            }
        } else if let generatedPlan {
            // Fallback if parsing failed
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(PoolTheme.mid)
                    Text("Your Training Plan")
                        .font(.title3.bold())
                        .foregroundStyle(PoolTheme.deep)
                }

                Text(generatedPlan)
                    .font(.body)
                    .foregroundStyle(PoolTheme.deep)
            }
            .poolCard()
        }
    }

    // MARK: - Summary Stats Bar

    func summaryStatsBar(_ plan: WeeklyTrainingPlan) -> some View {
        HStack(spacing: 12) {
            statItem(
                icon: "figure.pool.swim",
                value: "\(plan.overview.sessionCount ?? 0)",
                label: "Sessions",
                color: PoolTheme.mid
            )

            statItem(
                icon: planType.icon,
                value: planType.rawValue,
                label: "Plan",
                color: .blue
            )

            statItem(
                icon: "calendar",
                value: plan.overview.poolType ?? "Pool",
                label: "Pool",
                color: PoolTheme.smoke
            )
        }
    }

    func statItem(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(PoolTheme.deep)
                .lineLimit(1)

            Text(label)
                .font(.caption2)
                .foregroundStyle(PoolTheme.smoke)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(PoolTheme.surface)
        .cornerRadius(12)
    }

    // MARK: - Save Plan Button

    func savePlanButton(_ plan: WeeklyTrainingPlan) -> some View {
        VStack(spacing: 12) {
            if let status = savedStatus {
                HStack {
                    Image(systemName: status.contains("Failed") ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(status.contains("Failed") ? .red : .green)
                    Text(status)
                        .font(.subheadline)
                        .foregroundStyle(PoolTheme.deep)
                }
                .poolCard()
            }

            Button {
                savePlan(plan)
            } label: {
                HStack {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.down")
                    }
                    Text(isSaving ? "Saving..." : "Save Plan")
                        .font(.headline.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(PoolTheme.mid)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
            .disabled(isSaving)
            .poolCard()

            Text("Sessions will appear in Calendar on their scheduled dates")
                .font(.caption)
                .foregroundStyle(PoolTheme.smoke)
        }
    }

    func savePlan(_ plan: WeeklyTrainingPlan) {
        isSaving = true
        savedStatus = nil

        Task { @MainActor in
            do {
                try await appModel.saveWeeklyPlan(plan)
                savedStatus = "Saved \(plan.detailedSessions.count) sessions for \(formatWeekRange(plan.weekStartingDate ?? Date()))"
            } catch {
                savedStatus = "Failed to save: \(error.localizedDescription)"
            }
            isSaving = false
        }
    }

    func formatWeekRange(_ date: Date) -> String {
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .day, value: 6, to: date) ?? date
        return "\(DateFormatter.shortMonthDay.string(from: date)) - \(DateFormatter.shortMonthDay.string(from: endDate))"
    }

    // MARK: - Overview Hero Card

    func overviewHeroCard(_ plan: WeeklyTrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Swimmer Summary (computed from profile)
            Text(plan.overview.swimmerSummary ?? "Swimmer Profile")
                .font(.headline)
                .foregroundStyle(PoolTheme.deep)

            // Past Month Analysis (if available)
            if let pastMonth = plan.overview.pastMonthAnalysis, !pastMonth.isEmpty {
                pastMonthCard(pastMonth)
            }

            // Week Focus Banner
            weekFocusBanner(plan)

            // Objectives Row
            HStack(spacing: 16) {
                objectivePill(
                    icon: "figure.pool.swim",
                    label: plan.overview.technicalObjective ?? "Technique focus",
                    color: PoolTheme.mid
                )

                objectivePill(
                    icon: "flame",
                    label: plan.overview.physicalObjective ?? "Fitness focus",
                    color: .orange
                )
            }
        }
        .poolCard()
    }

    func pastMonthCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Past Month", systemImage: "calendar.badge.clock")
                .font(.caption.bold())
                .foregroundStyle(PoolTheme.smoke)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(PoolTheme.deep)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PoolTheme.light.opacity(0.2))
                .cornerRadius(8)
        }
    }

    func weekFocusBanner(_ plan: WeeklyTrainingPlan) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("This Week's Focus")
                    .font(.caption.bold())
                    .foregroundStyle(PoolTheme.smoke)

                Text(plan.overview.weekFocus)
                    .font(.title3.bold())
                    .foregroundStyle(PoolTheme.mid)
            }

            Spacer()

            Image(systemName: planType.icon)
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(PoolTheme.mid.opacity(0.6))
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [PoolTheme.mid.opacity(0.1), PoolTheme.light.opacity(0.05)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
    }

    func objectivePill(icon: String, label: String, color: Color) -> some View {
        Label(label, systemImage: icon)
            .font(.caption)
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(color.opacity(0.1))
            .cornerRadius(20)
    }

    // MARK: - Technique Progress Collapsible

    func techniqueProgressCollapsible(_ plan: TechniqueProgressPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showGoalProgress.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "figure.pool.swim")
                        .foregroundStyle(PoolTheme.deep)
                    Text("Technique Progress Plan")
                        .font(.headline)
                        .foregroundStyle(PoolTheme.deep)

                    Spacer()

                    Image(systemName: showGoalProgress ? "chevron.down" : "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(PoolTheme.smoke)
                }
            }
            .buttonStyle(.plain)

            if showGoalProgress {
                VStack(alignment: .leading, spacing: 12) {
                    if !plan.continueGoals.isEmpty {
                        techniqueCategoryRow(
                            title: "Continuing",
                            goals: plan.continueGoals,
                            icon: "arrow.forward.circle.fill",
                            color: PoolTheme.mid
                        )
                    }

                    if !plan.achievedGoalsNextLevel.isEmpty {
                        techniqueCategoryRow(
                            title: "Achieved → Next",
                            goals: plan.achievedGoalsNextLevel,
                            icon: "checkmark.circle.fill",
                            color: .green
                        )
                    }

                    if !plan.revisitGoals.isEmpty {
                        techniqueCategoryRow(
                            title: "Revisit",
                            goals: plan.revisitGoals,
                            icon: "arrow.uturn.backward.circle.fill",
                            color: .orange
                        )
                    }

                    if !plan.newGoals.isEmpty {
                        techniqueCategoryRow(
                            title: "New",
                            goals: plan.newGoals,
                            icon: "plus.circle.fill",
                            color: PoolTheme.deep
                        )
                    }
                }
                .padding(.top, 8)
            }
        }
        .poolCard()
    }

    func techniqueCategoryRow(title: String, goals: [String], icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.subheadline.bold())
                .foregroundStyle(color)

            ForEach(goals, id: \.self) { goal in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.3))
                        .frame(width: 4, height: 24)

                    Text(goal)
                        .font(.subheadline)
                        .foregroundStyle(PoolTheme.deep)
                }
            }
        }
    }

    // MARK: - Sessions Grid

    func sessionsGrid(_ plan: WeeklyTrainingPlan) -> some View {
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
                        onDateChange: { newDate in
                            updateSessionDate(sessionNumber: session.sessionNumber, date: newDate)
                        },
                        showDatePicker: true,
                        poolType: poolType,
                        onDelete: nil,  // No buttons in PlanningView - use swipe in Dashboard
                        onComplete: nil
                    )
                }
            }
        }
        .poolCard()
    }

    // MARK: - Dry Land Card

    func dryLandCard(_ exercises: [DryLandExercisePlan]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Dry Land Program", systemImage: "figure.strengthtraining.traditional")
                .font(.headline)
                .foregroundStyle(PoolTheme.deep)

            VStack(spacing: 8) {
                ForEach(exercises) { exercise in
                    DryLandExerciseRow(
                        exercise: exercise,
                        onDateChange: { newDate in updateDryLandDate(exerciseId: exercise.id, date: newDate) },
                        referenceDate: weekStartingDate
                    )
                }
            }
        }
        .poolCard()
    }

    // MARK: - Notes Card

    func notesCard(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Coach Notes", systemImage: "note.text")
                .font(.caption.bold())
                .foregroundStyle(PoolTheme.smoke)

            Text(notes)
                .font(.subheadline)
                .foregroundStyle(PoolTheme.deep)
        }
        .poolCard()
    }

    // MARK: - Debug Toggle

    var debugToggle: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                showRawJSON.toggle()
            } label: {
                Text(showRawJSON ? "Hide Raw JSON" : "Show Raw JSON")
                    .font(.caption)
                    .foregroundStyle(PoolTheme.smoke)
            }
            .buttonStyle(.plain)

            if showRawJSON, let generatedPlan {
                ScrollView {
                    Text(generatedPlan)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(PoolTheme.smoke)
                }
                .frame(maxHeight: 200)
                .background(PoolTheme.surface)
                .cornerRadius(8)
            }
        }
    }
}
