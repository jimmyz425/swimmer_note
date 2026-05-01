import SwiftUI

/// Dry land exercises section card
struct DryLandCard: View {
    let exercises: [DryLandExercisePlan]
    let onDateChange: ((String, Date) -> Void)?
    let weekStartingDate: Date?

    init(
        exercises: [DryLandExercisePlan],
        onDateChange: ((String, Date) -> Void)? = nil,
        weekStartingDate: Date? = nil
    ) {
        self.exercises = exercises
        self.onDateChange = onDateChange
        self.weekStartingDate = weekStartingDate
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Dry Land Program", systemImage: "figure.strengthtraining.traditional")
                .font(.headline)
                .foregroundStyle(PoolTheme.deep)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(exercises) { exercise in
                    DryLandExerciseTile(
                        exercise: exercise,
                        onDateChange: onDateChange != nil ? { date in
                            onDateChange?(exercise.id, date)
                        } : nil,
                        weekStartingDate: weekStartingDate
                    )
                }
            }
        }
        .poolCard()
    }
}

/// Individual dry land exercise tile
struct DryLandExerciseTile: View {
    let exercise: DryLandExercisePlan
    let onDateChange: ((Date) -> Void)?
    let weekStartingDate: Date?

    init(
        exercise: DryLandExercisePlan,
        onDateChange: ((Date) -> Void)? = nil,
        weekStartingDate: Date? = nil
    ) {
        self.exercise = exercise
        self.onDateChange = onDateChange
        self.weekStartingDate = weekStartingDate
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Exercise name
            Text(exercise.exercise)
                .font(.subheadline.bold())
                .foregroundStyle(PoolTheme.deep)
                .lineLimit(2)

            // Sets/Reps badge
            Text(exercise.setsReps)
                .font(.caption.bold())
                .foregroundStyle(PoolTheme.mid)

            // Focus area
            if let focus = exercise.focus, !focus.isEmpty {
                Text(focus)
                    .font(.caption)
                    .foregroundStyle(PoolTheme.smoke)
            }

            // Technique support
            if let support = exercise.techniqueSupport {
                Text("→ \(support)")
                    .font(.caption2)
                    .foregroundStyle(PoolTheme.smoke)
            }

            // Date picker (if editing enabled)
            if onDateChange != nil {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { exercise.scheduledDate ?? weekStartingDate ?? Date() },
                        set: { onDateChange?($0) }
                    ),
                    displayedComponents: .date
                )
                .labelsHidden()
                .scaleEffect(0.85)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PoolTheme.light.opacity(0.2))
        .cornerRadius(8)
    }
}

/// Dry land section for calendar day detail (read-only display)
struct DryLandSection: View {
    let exercises: [DryLandExercisePlan]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(.orange)
                Text("Dry Land Training")
                    .font(.headline)
                    .foregroundStyle(PoolTheme.deep)
            }

            ForEach(exercises) { exercise in
                HStack(alignment: .top, spacing: 12) {
                    // Sets/Reps badge
                    Text(exercise.setsReps)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange)
                        .cornerRadius(6)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.exercise)
                            .font(.subheadline.bold())
                            .foregroundStyle(PoolTheme.deep)

                        if let focus = exercise.focus, !focus.isEmpty {
                            Text(focus)
                                .font(.caption)
                                .foregroundStyle(PoolTheme.smoke)
                        }

                        if let support = exercise.techniqueSupport {
                            Text("→ \(support)")
                                .font(.caption2)
                                .foregroundStyle(PoolTheme.mid)
                        }
                    }

                    Spacer()
                }
            }
        }
    }
}

#Preview("Dry Land Card - Editing") {
    let exercises = [
        DryLandExercisePlan(
            exercise: "Push-ups",
            setsReps: "3x15",
            focus: "Core strength",
            techniqueSupport: "Improves streamline hold",
            scheduledDate: Date()
        ),
        DryLandExercisePlan(
            exercise: "Plank Hold",
            setsReps: "3x30s",
            focus: "Core stability",
            techniqueSupport: "Body position maintenance",
            scheduledDate: Date()
        ),
        DryLandExercisePlan(
            exercise: "Medicine Ball Throws",
            setsReps: "3x10",
            focus: "Explosive power",
            techniqueSupport: "Start power",
            scheduledDate: Date()
        )
    ]

    DryLandCard(
        exercises: exercises,
        onDateChange: { _, _ in },
        weekStartingDate: Date()
    )
}

#Preview("Dry Land Section - Read-only") {
    let exercises = [
        DryLandExercisePlan(
            exercise: "Squats",
            setsReps: "3x12",
            focus: "Leg strength",
            techniqueSupport: "Push-off power",
            scheduledDate: Date()
        )
    ]

    DryLandSection(exercises: exercises)
        .padding()
        .background(PoolTheme.surface)
}