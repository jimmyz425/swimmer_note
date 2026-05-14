import SwiftUI

/// Individual dry land exercise display row
/// Used in Dashboard and Calendar views for consistent styling
struct DryLandExerciseRow: View {
    let exercise: DryLandExercisePlan
    var onDateChange: ((Date) -> Void)? = nil
    var referenceDate: Date? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Row 1: setsReps (left) | exercise name (right)
            HStack {
                // Completion badge or sets/reps (left justified)
                if exercise.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.green)
                } else {
                    Text(exercise.setsReps)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange)
                        .cornerRadius(6)
                }

                Spacer()

                // Exercise name (right justified)
                Text(exercise.exercise)
                    .font(.subheadline.bold())
                    .foregroundStyle(exercise.isCompleted ? PoolTheme.smoke : PoolTheme.deep)

                if exercise.isCompleted {
                    Text("Done")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.green.opacity(0.2))
                        .cornerRadius(4)
                }
            }

            // Row 2: Category (if available)
            if let focus = exercise.focus, !focus.isEmpty {
                Text(focus)
                    .font(.caption)
                    .foregroundStyle(PoolTheme.mid)
            }

            // Row 3: Stroke focus points (if available)
            if let support = exercise.techniqueSupport {
                Text(support)
                    .font(.caption2)
                    .foregroundStyle(PoolTheme.smoke)
            }

            // Date picker (if editing enabled)
            if let onDateChange, let referenceDate {
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundStyle(PoolTheme.smoke)

                    DatePicker(
                        "",
                        selection: Binding(
                            get: { exercise.scheduledDate ?? referenceDate },
                            set: { onDateChange($0) }
                        ),
                        displayedComponents: .date
                    )
                    .labelsHidden()

                    Spacer()
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(exercise.isCompleted ? PoolTheme.light.opacity(0.05) : PoolTheme.light.opacity(0.08))
        )
    }
}