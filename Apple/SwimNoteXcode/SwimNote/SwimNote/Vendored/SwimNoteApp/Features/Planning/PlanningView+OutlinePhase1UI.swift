import SwiftUI
import UIKit

extension PlanningView {
    // MARK: - Phase 1: Outline Review Section

    @ViewBuilder
    func outlineReviewSection(_ outline: WeeklyPlanOutline) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Phase indicator
            phaseIndicator(phase: 1, title: "Weekly Outline Review")

            // Resume banner if incomplete sessions or missing dry land
            let incompleteCount = outline.schedule.filter { !$0.isDetailsGenerated }.count
            let hasDryLand = outline.dryLandExercises != nil && !outline.dryLandExercises!.isEmpty

            if incompleteCount > 0 {
                resumeBanner(type: .sessions(incomplete: incompleteCount, total: outline.schedule.count))
            } else if !hasDryLand && outline.schedule.allSatisfy({ $0.isDetailsGenerated }) {
                resumeBanner(type: .dryLand)
            }

            // Overview card
            outlineOverviewCard(outline)

            // Session outlines
            sessionOutlinesGrid(outline)

            // Generate All Details button
            generateAllDetailsButton(outline)
        }
    }

    enum ResumeType: Equatable {
        case sessions(incomplete: Int, total: Int)
        case dryLand
    }

    func resumeBanner(type: ResumeType) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Incomplete Generation")
                    .font(.headline)
                    .foregroundStyle(PoolTheme.deep)
                switch type {
                case .sessions(let incomplete, let total):
                    Text("\(incomplete) of \(total) sessions need details")
                        .font(.caption)
                        .foregroundStyle(PoolTheme.mid)
                case .dryLand:
                    Text("Sessions complete, generating dry land exercises")
                        .font(.caption)
                        .foregroundStyle(PoolTheme.mid)
                }
            }

            Spacer()

            Button {
                switch type {
                case .sessions:
                    Task { await generateAllDetailedSessionsParallel(for: planOutline!) }
                case .dryLand:
                    Task {
                        await generateWeeklyDryLand(outline: planOutline!)
                        convertOutlineToFullPlan(planOutline!)
                        try? await appModel.deleteOutline()
                    }
                }
            } label: {
                Text(type == .dryLand ? "Generate Dry Land" : "Continue")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.orange)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.orange.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.orange.opacity(0.3), lineWidth: 1)
        )
    }

    func phaseIndicator(phase: Int, title: String) -> some View {
        HStack(spacing: 8) {
            Text("Phase \(phase)")
                .font(.caption.bold())
                .foregroundStyle(PoolTheme.mid)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(PoolTheme.mid.opacity(0.15))
                .cornerRadius(6)

            Text(title)
                .font(.headline)
                .foregroundStyle(PoolTheme.deep)

            Spacer()

            if phase == 1 {
                Text("Review before generating details")
                    .font(.caption)
                    .foregroundStyle(PoolTheme.smoke)
            }
        }
    }

    func outlineOverviewCard(_ outline: WeeklyPlanOutline) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Week Focus Banner
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Week Focus")
                        .font(.caption.bold())
                        .foregroundStyle(PoolTheme.smoke)

                    Text(outline.overview.weekFocus)
                        .font(.title3.bold())
                        .foregroundStyle(PoolTheme.mid)
                }

                Spacer()

                Image(systemName: planType.icon)
                    .font(.system(size: 28, weight: .light))
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

            // Fundamental revisit plan
            if let revisitPlan = outline.overview.fundamentalRevisitPlan, !revisitPlan.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Fundamentals Revisit", systemImage: "arrow.uturn.backward")
                        .font(.caption.bold())
                        .foregroundStyle(PoolTheme.smoke)

                    Text(revisitPlan)
                        .font(.subheadline)
                        .foregroundStyle(PoolTheme.deep)
                }
            }

            // Stroke rotation plan
            if let rotationPlan = outline.overview.strokeRotationPlan, !rotationPlan.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Stroke Rotation", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption.bold())
                        .foregroundStyle(PoolTheme.smoke)

                    Text(rotationPlan)
                        .font(.subheadline)
                        .foregroundStyle(PoolTheme.deep)
                }
            }

            // Past 2-week training summary
            if let summary = outline.twoWeekSummary {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Past 2 Weeks Training", systemImage: "calendar.badge.clock")
                        .font(.caption.bold())
                        .foregroundStyle(PoolTheme.smoke)

                    // Session count and stroke chips
                    HStack(spacing: 12) {
                        Text("\(summary.totalSessions) sessions")
                            .font(.subheadline.bold())
                            .foregroundStyle(PoolTheme.mid)

                        Spacer()

                        if summary.totalSessions > 0 {
                            let dist = summary.strokeDistribution
                            ForEach([
                                ("Free", dist.freestyle),
                                ("Back", dist.backstroke),
                                ("Breast", dist.breaststroke),
                                ("Fly", dist.butterfly)
                            ], id: \.0) { label, count in
                                Text("\(label) \(count)")
                                    .font(.caption)
                                    .foregroundStyle(count > 0 ? PoolTheme.deep : PoolTheme.smoke)
                                    .padding(4)
                                    .background(count > 0 ? PoolTheme.light.opacity(0.2) : PoolTheme.smoke.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                    }

                    if !summary.neglectedStrokes.isEmpty {
                        Text("Neglected: \(summary.neglectedStrokes.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(PoolTheme.smoke)
                            .italic()
                    }

                    if !summary.goalProgress.isEmpty {
                        Text(summary.goalProgress)
                            .font(.subheadline)
                            .foregroundStyle(PoolTheme.deep)
                    }

                    if !summary.keyTrends.isEmpty {
                        Text(summary.keyTrends)
                            .font(.subheadline)
                            .foregroundStyle(PoolTheme.deep)
                    }

                    if !summary.techniqueProgression.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Technique Progression", systemImage: "arrow.up.right")
                                .font(.caption.bold())
                                .foregroundStyle(PoolTheme.smoke)

                            Text(summary.techniqueProgression)
                                .font(.subheadline)
                                .foregroundStyle(PoolTheme.deep)
                        }
                    }

                    if !summary.coveredTechniques.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Techniques Previously Covered", systemImage: "checkmark.circle")
                                .font(.caption.bold())
                                .foregroundStyle(PoolTheme.smoke)

                            Text(summary.coveredTechniques)
                                .font(.subheadline)
                                .foregroundStyle(PoolTheme.deep)
                        }
                    }
                }
                .padding(10)
                .background(PoolTheme.light.opacity(0.08))
                .cornerRadius(8)
            } else if let pastSummary = outline.pastTrainingSummary, !pastSummary.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Recent Training", systemImage: "calendar.badge.clock")
                        .font(.caption.bold())
                        .foregroundStyle(PoolTheme.smoke)

                    Text(pastSummary)
                        .font(.subheadline)
                        .foregroundStyle(PoolTheme.deep)
                }
            }

            // Plan connection rationale
            if let rationale = outline.planConnectionRationale, !rationale.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Why This Plan", systemImage: "lightbulb")
                        .font(.caption.bold())
                        .foregroundStyle(PoolTheme.smoke)

                    Text(rationale)
                        .font(.subheadline)
                        .foregroundStyle(PoolTheme.deep)
                }
            }
        }
        .poolCard()
    }

    func sessionOutlinesGrid(_ outline: WeeklyPlanOutline) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Outlines")
                .font(.headline)
                .foregroundStyle(PoolTheme.deep)

            LazyVStack(spacing: 12) {
                ForEach(outline.schedule) { session in
                    SessionOutlineCard(
                        session: session,
                        isGenerating: generatingSessions.contains(session.sessionNumber),
                        onGenerateDetails: {
                            Task { await generateDetailedSession(for: session, in: outline) }
                        }
                    )
                }
            }
        }
        .poolCard()
    }

    func generateAllDetailsButton(_ outline: WeeklyPlanOutline) -> some View {
        VStack(spacing: 12) {
            // Parallel generation progress
            if isGeneratingDetails && !generatingSessions.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(PoolTheme.mid)
                    Text("Generating sessions: \(generatingSessions.sorted().map { "#\($0)" }.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(PoolTheme.mid)
                }
                .padding(.horizontal)
            }

            Button {
                Task { await generateAllDetailedSessionsParallel(for: outline) }
            } label: {
                HStack(spacing: 8) {
                    if isGeneratingDetails {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(isGeneratingDetails ? "Generating..." : "Generate All Session Details")
                        .font(.headline.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(PoolTheme.mid)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
            .disabled(isGeneratingDetails || outline.schedule.allSatisfy { $0.isDetailsGenerated })

            Text("Or click \"Generate Details\" on individual sessions above")
                .font(.caption)
                .foregroundStyle(PoolTheme.smoke)
        }
        .poolCard()
    }
}
