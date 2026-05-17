import SwiftUI
import UIKit

extension PlanningView {
    /// Load saved outline for resumption if generation was interrupted
    func loadSavedOutline() async {
        // Ensure latest data is loaded (notes + weekly plans) so buildPlanContext has current data
        if let userId = appModel.activeProfile?.id {
            await appModel.reloadNotes(userId: userId)
        }

        // Only load if there's no current outline and no generated plan
        if planOutline == nil && parsedPlan == nil && generatedPlan == nil {
            if let savedOutline = await appModel.loadOutline() {
                let allSessionsComplete = savedOutline.schedule.allSatisfy { $0.isDetailsGenerated }
                let hasDryLand = savedOutline.dryLandExercises != nil && !savedOutline.dryLandExercises!.isEmpty

                if !allSessionsComplete {
                    // Resume incomplete session generation
                    planOutline = savedOutline
                    // Restore accumulated dry land if present
                    accumulatedDryLand = savedOutline.dryLandExercises ?? []
                    #if DEBUG
                    print("📱 Loaded saved outline with \(savedOutline.schedule.count - savedOutline.schedule.filter { $0.isDetailsGenerated }.count) incomplete sessions")
                    #endif
                } else if allSessionsComplete && !hasDryLand {
                    // All sessions done but missing dry land - resume from there
                    planOutline = savedOutline
                    accumulatedDryLand = []  // Clear since no dry land yet
                    #if DEBUG
                    print("📱 Loaded saved outline - all sessions complete, missing dry land")
                    #endif
                } else if allSessionsComplete && hasDryLand {
                    // Everything complete - convert to full plan
                    planOutline = savedOutline
                    accumulatedDryLand = savedOutline.dryLandExercises ?? []
                    convertOutlineToFullPlan(savedOutline)
                    try? await appModel.deleteOutline()
                    #if DEBUG
                    print("📱 Loaded complete outline - converted to full plan")
                    #endif
                }
            }
        }
    }

    /// Pre-select tier-appropriate coaching styles when profile loads or selection is empty.
    func syncCoachingStyleDefaultsIfNeeded() {
        // Migrate any old-style IDs (yb-*, int-*, etc.) to new TrainingTier IDs.
        selectedCoachingStyleIDs = CoachingStyleCatalog.migrateSelectionIDs(selectedCoachingStyleIDs)

        let profile = appModel.activeProfile
        let pruned = CoachingStyleCatalog.pruneSelection(selectedCoachingStyleIDs, profile: profile)
        if pruned != selectedCoachingStyleIDs {
            selectedCoachingStyleIDs = pruned
        }
        guard selectedCoachingStyleIDs.isEmpty else { return }
        selectedCoachingStyleIDs = CoachingStyleCatalog.defaultSelectionIDs(forProfile: profile)
    }

    /// Reset all plan generation state when switching profiles
    func resetPlanState() {
        // Race prep is Gold+ only — reset to mixed if the new profile isn't eligible
        let tier = appModel.activeProfile?.trainingTier ?? .preCompetitive
        let isGoldPlus = tier == .gold || tier == .senior || tier == .national
        if planType == .racePrep && !isGoldPlus {
            planType = .mixed
            racePrepPhase = nil
        }
        selectedCoachingStyleIDs = []
        syncCoachingStyleDefaultsIfNeeded()
        generatedPlan = nil
        parsedPlan = nil
        planOutline = nil
        accumulatedDryLand = []
        selectedHistoryPlan = nil
        errorMessage = nil
        savedStatus = nil
        expandedSessions = []
        isGenerating = false
        isGeneratingOutline = false
        isGeneratingDetails = false
        isGeneratingDryLand = false
        generatingSessionNumber = nil
        showOutlineReview = false
        generationStreamPreview = ""
    }

    var shouldShowGenerationStreamPreview: Bool {
        !generationStreamPreview.isEmpty
            && (isGeneratingOutline || isGenerating || isGeneratingDryLand || generatingSessionNumber != nil)
    }

    @ViewBuilder
    var generationStreamPreviewPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Drafting…")
                    .font(.caption.bold())
                    .foregroundStyle(PoolTheme.mid)
            }
            ScrollView {
                Text(generationStreamPreview)
                    .font(.caption.monospaced())
                    .foregroundStyle(PoolTheme.smoke)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 160)
        }
        .padding(12)
        .background(PoolTheme.surface)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(PoolTheme.mid.opacity(0.2), lineWidth: 1)
        )
    }

    var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("AI TRAINING PLANNER")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(PoolTheme.deep)
                Text("Describe your goals and get a personalized plan")
                    .font(.headline)
                    .foregroundStyle(PoolTheme.mid)
            }

            Spacer()

            // History button
            Button {
                showPlanHistory = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title2)
                    .foregroundStyle(PoolTheme.mid)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    var errorSection: some View {
        if let errorMessage {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                    Text("Error")
                        .font(.headline)
                        .foregroundStyle(.red)
                }
                Text(errorMessage)
                    .font(.body)
                    .foregroundStyle(PoolTheme.smoke)
            }
            .poolCard()
        }
    }
}
