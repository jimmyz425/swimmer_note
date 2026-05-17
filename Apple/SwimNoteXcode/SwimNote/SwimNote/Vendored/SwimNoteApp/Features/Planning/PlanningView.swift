import SwiftUI
import UIKit

struct PlanningView: View {
    @Bindable var appModel: SwimNoteAppModel
    @Environment(ContentStore.self) var contentStore
    @State var generatedPlan: String?
    @State var parsedPlan: WeeklyTrainingPlan?
    @State var isGenerating: Bool = false
    @State var errorMessage: String?
    @State var showRawJSON: Bool = false
    @State var expandedSessions: Set<Int> = []
    @State var showGoalProgress: Bool = true
    @State var isSaving: Bool = false
    @State var savedStatus: String?
    @State var showPlanHistory: Bool = false
    @State var selectedHistoryPlan: WeeklyTrainingPlan?
    @State var isSettingsExpanded: Bool = true

    /// Present share sheet after writing a PDF to a temp file.
    @State var pdfShareFile: ShareableFile?
    @State var isExportingPDF: Bool = false
    @State var pdfExportError: String?

    // Two-phase generation state
    @State var planOutline: WeeklyPlanOutline?
    @State var isGeneratingOutline: Bool = false
    @State var isGeneratingDetails: Bool = false
    @State var isGeneratingDryLand: Bool = false
    @State var generatingSessionNumber: Int?
    @State var generatingSessions: Set<Int> = []  // Track parallel session generation
    @State var showOutlineReview: Bool = false

    /// Dry land exercises accumulated during multi-phase generation (before outline is converted to a full plan).
    @State var accumulatedDryLand: [MinimalDryLandExercise] = []

    /// P2-2G: tail of streamed assistant text while outline / session / dry land / legacy plan is generating.
    @State var generationStreamPreview: String = ""

    /// Max concurrent session generations (avoid API rate limits)
    let maxConcurrentSessions: Int = 2

    // Plan settings - sessions determined by tier guidance, not user selection
    @State var poolType: PoolType = .scm
    @State var planType: PlanType = .mixed
    @State var weekStartingDate: Date = nextMonday()
    @State var selectedCoachingStyleIDs: Set<String> = []

    let llmClient = OpenAIClient()
    let credentialStore: any SecureCredentialStore = {
        #if canImport(Security)
        KeychainCredentialStore()
        #else
        InMemoryCredentialStore()
        #endif
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection

                    if shouldShowGenerationStreamPreview {
                        generationStreamPreviewPanel
                    }

                    // Collapsible Settings Card with Generate Button
                    CollapsibleSettingsCard(
                        isExpanded: isSettingsExpanded,
                        poolType: $poolType,
                        planType: $planType,
                        weekStartingDate: $weekStartingDate,
                        skillLevel: appModel.activeProfile?.skillLevel ?? .beginner,
                        profile: appModel.activeProfile,
                        coachTiers: CoachTierProfileMapping.coachTiersForStylePicker(profile: appModel.activeProfile),
                        selectedCoachingStyleIDs: $selectedCoachingStyleIDs,
                        isGenerating: isGeneratingOutline,
                        onToggle: { isSettingsExpanded.toggle() },
                        onGenerate: { Task { await generateOutline() } },
                        onLoadSample: loadSamplePlan
                    )

                    if errorMessage != nil {
                        errorSection
                    }

                    // Phase 1: Outline Review
                    if let outline = planOutline, parsedPlan == nil {
                        outlineReviewSection(outline)
                    }

                    // Phase 2: Full Plan (after all details generated)
                    if generatedPlan != nil {
                        resultSection
                    }
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [PoolTheme.surface, PoolTheme.light.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPlanHistory) {
                PlanHistoryView(appModel: appModel, selectedPlan: $selectedHistoryPlan)
            }
            .sheet(item: $selectedHistoryPlan) { plan in
                PlanDetailView(plan: plan, appModel: appModel)
            }
            .sheet(item: $pdfShareFile) { file in
                ActivityView(activityItems: [file.url])
            }
            .alert(
                "Export failed",
                isPresented: Binding(
                    get: { pdfExportError != nil },
                    set: { if !$0 { pdfExportError = nil } }
                )
            ) {
                Button("OK", role: .cancel) { pdfExportError = nil }
            } message: {
                Text(pdfExportError ?? "")
            }
            .onChange(of: selectedHistoryPlan) { _, newPlan in
                if let plan = newPlan {
                    // Load selected plan into current view
                    parsedPlan = plan
                    expandedSessions.insert(1) // Expand first session
                    savedStatus = nil // Reset save status
                    planOutline = nil // Clear outline when loading history
                    accumulatedDryLand = [] // Clear dry land - plan has its own
                }
            }
            // Reset all plan state when profile changes
            .onChange(of: appModel.activeProfile?.id) { _, _ in
                resetPlanState()
            }
            // Load saved outline on appear (for resumption)
            .onAppear {
                syncCoachingStyleDefaultsIfNeeded()
                Task {
                    await loadSavedOutline()
                }
            }
        }
    }
}

#Preview("Planning") {
    let model = SwimNoteAppModel.bootstrap()
    model.profileStore.activeProfile = UserProfile(
        id: "preview-user",
        name: "Alex Swimmer",
        birthday: "1995-06-15",
        sex: .male,
        skillLevel: .intermediate,
        weeklySessionTarget: 3,
        preferredStrokes: [.freestyle, .backstroke],
        personalBests: PersonalBests(freestyle50m: 32.5),
        trainingGoals: [],
        createdAt: "2024-01-01T00:00:00Z",
        updatedAt: "2024-01-01T00:00:00Z"
    )
    model.llmConfiguration = try? LLMConfiguration(
        provider: .openAI,
        apiKeyReference: "llm-openai",
        baseURL: nil,
        modelName: "gpt-4.1-mini"
    )
    return PlanningView(appModel: model)
        .environment(model.contentStore)
}
