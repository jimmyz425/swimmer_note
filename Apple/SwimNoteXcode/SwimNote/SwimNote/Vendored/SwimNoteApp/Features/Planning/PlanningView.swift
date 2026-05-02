import SwiftUI

public enum PoolType: String, CaseIterable, Identifiable {
    case shortCourse = "Short Course (25m)"
    case shortCourseYards = "Short Course (25yd)"
    case longCourse = "Long Course (50m)"
    case longCourseYards = "Long Course (50yd)"

    public var id: String { rawValue }

    public var shortLabel: String {
        switch self {
        case .shortCourse: "25m"
        case .shortCourseYards: "25yd"
        case .longCourse: "50m"
        case .longCourseYards: "50yd"
        }
    }

    /// Whether this pool uses yards (needs conversion for display)
    public var isYards: Bool {
        self == .shortCourseYards || self == .longCourseYards
    }

    /// Convert meters to yards for display (1m = 1.09361yd, round to nearest)
    public func metersToYards(_ meters: Int) -> Int {
        Int(Double(meters) * 1.09361)
    }

    /// Format distance with appropriate unit
    public func formatDistance(_ meters: Int) -> String {
        if isYards {
            let yards = metersToYards(meters)
            return "\(yards)yd"
        }
        return "\(meters)m"
    }
}

struct PlanningView: View {
    @Bindable var appModel: SwimNoteAppModel
    @State private var generatedPlan: String?
    @State private var parsedPlan: WeeklyTrainingPlan?
    @State private var isGenerating: Bool = false
    @State private var errorMessage: String?
    @State private var showRawJSON: Bool = false
    @State private var expandedSessions: Set<Int> = []
    @State private var showGoalProgress: Bool = true
    @State private var isSaving: Bool = false
    @State private var savedStatus: String?
    @State private var showPlanHistory: Bool = false
    @State private var selectedHistoryPlan: WeeklyTrainingPlan?
    @State private var isSettingsExpanded: Bool = true

    // Plan settings
    @State private var poolType: PoolType = .shortCourse
    @State private var sessionsPerWeek: Int = 3
    @State private var planType: PlanType = .mixed
    @State private var includeDryLand: Bool = true
    @State private var weekStartingDate: Date = nextMonday()

    private let llmClient = OpenAIClient()
    private let credentialStore: any SecureCredentialStore = {
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

                    // Collapsible Settings Card with Generate Button
                    CollapsibleSettingsCard(
                        isExpanded: isSettingsExpanded,
                        poolType: $poolType,
                        sessionsPerWeek: $sessionsPerWeek,
                        planType: $planType,
                        includeDryLand: $includeDryLand,
                        weekStartingDate: $weekStartingDate,
                        isGenerating: isGenerating,
                        onToggle: { isSettingsExpanded.toggle() },
                        onGenerate: { Task { await generatePlan() } },
                        onLoadSample: loadSamplePlan
                    )

                    if errorMessage != nil {
                        errorSection
                    }

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
            .onChange(of: selectedHistoryPlan) { _, newPlan in
                if let plan = newPlan {
                    // Load selected plan into current view
                    parsedPlan = plan
                    expandedSessions.insert(1) // Expand first session
                    savedStatus = nil // Reset save status
                }
            }
        }
    }

    private var headerSection: some View {
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
    private var errorSection: some View {
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

    @ViewBuilder
    private var resultSection: some View {
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

    private func summaryStatsBar(_ plan: WeeklyTrainingPlan) -> some View {
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

    private func statItem(icon: String, value: String, label: String, color: Color) -> some View {
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

    private func savePlanButton(_ plan: WeeklyTrainingPlan) -> some View {
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

    private func savePlan(_ plan: WeeklyTrainingPlan) {
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

    private func formatWeekRange(_ date: Date) -> String {
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .day, value: 6, to: date) ?? date
        return "\(DateFormatter.shortMonthDay.string(from: date)) - \(DateFormatter.shortMonthDay.string(from: endDate))"
    }

    // MARK: - Overview Hero Card

    private func overviewHeroCard(_ plan: WeeklyTrainingPlan) -> some View {
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

    private func pastMonthCard(_ text: String) -> some View {
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

    private func weekFocusBanner(_ plan: WeeklyTrainingPlan) -> some View {
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

    private func objectivePill(icon: String, label: String, color: Color) -> some View {
        Label(label, systemImage: icon)
            .font(.caption)
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(color.opacity(0.1))
            .cornerRadius(20)
    }

    // MARK: - Technique Progress Collapsible

    private func techniqueProgressCollapsible(_ plan: TechniqueProgressPlan) -> some View {
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

    private func techniqueCategoryRow(title: String, goals: [String], icon: String, color: Color) -> some View {
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

    private func sessionsGrid(_ plan: WeeklyTrainingPlan) -> some View {
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

    private func dryLandCard(_ exercises: [DryLandExercisePlan]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Dry Land Program", systemImage: "figure.strengthtraining.traditional")
                .font(.headline)
                .foregroundStyle(PoolTheme.deep)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(exercises) { exercise in
                    dryLandExerciseTile(exercise)
                }
            }
        }
        .poolCard()
    }

    private func dryLandExerciseTile(_ exercise: DryLandExercisePlan) -> some View {
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
            Text(exercise.focus ?? "")
                .font(.caption)
                .foregroundStyle(PoolTheme.smoke)

            // Technique support
            if let support = exercise.techniqueSupport {
                Text("→ \(support)")
                    .font(.caption2)
                    .foregroundStyle(PoolTheme.smoke)
            }

            // Date picker
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption2)
                    .foregroundStyle(PoolTheme.smoke)

                DatePicker(
                    "",
                    selection: Binding(
                        get: { exercise.scheduledDate ?? weekStartingDate },
                        set: { newDate in updateDryLandDate(exerciseId: exercise.id, date: newDate) }
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

    // MARK: - Notes Card

    private func notesCard(_ notes: String) -> some View {
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

    private var debugToggle: some View {
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

    private func generatePlan() async {
        guard let config = appModel.llmConfiguration else {
            errorMessage = "Configure LLM provider in Settings first"
            return
        }

        // Load API key from Keychain
        let apiKey: String
        do {
            guard let key = try credentialStore.load(account: config.apiKeyReference) else {
                errorMessage = "API key not found. Re-save settings in Settings tab."
                return
            }
            apiKey = key
        } catch {
            errorMessage = "Could not load API key: \(error.localizedDescription)"
            return
        }

        isGenerating = true
        errorMessage = nil

        // Get strategy for selected plan type
        let strategy = PlanStrategyFactory.strategy(for: planType)

        // Build plan context from swimmer data
        let planContext = buildPlanContext()

        // Increase timeout for plan generation (long prompt + multiple tool calls)
        let planConfig: LLMConfiguration
        do {
            planConfig = try LLMConfiguration(
                provider: config.provider,
                apiKeyReference: config.apiKeyReference,
                baseURL: config.baseURL,
                modelName: config.modelName,
                timeoutSeconds: 300,  // 5 minutes for plan generation with more sessions
                maxRetries: config.maxRetries
            )
        } catch {
            planConfig = config  // Use original if modification fails
        }

        // Use tool calling conversation to let LLM read technique files
        let conversation = ToolCallingConversation(
            configuration: planConfig,
            apiKey: apiKey,
            executor: appModel.createToolExecutor()
        )

        do {
            let rawOutput = try await conversation.run(
                systemRole: strategy.buildSystemRole(),
                userPrompt: strategy.buildUserPrompt(context: planContext),
                tools: AllTools.all,
                maxIterations: 50  // Increased for complex plans with more sessions - LLM needs multiple reads for stroke rotation
            )

            generatedPlan = rawOutput
            var plan = try parsePlanJSON(rawOutput)
            plan = enrichPlanWithComputedFields(plan: plan, sessionsPerWeek: sessionsPerWeek, poolType: poolType, profile: appModel.activeProfile)
            parsedPlan = plan
            savedStatus = nil // Reset save status when new plan generated
        } catch LLMServiceError.maxIterationsReached {
            errorMessage = "Plan generation took too long (50 iterations). Try with fewer sessions."
        } catch {
            errorMessage = "Failed to generate plan: \(error.localizedDescription)"
        }

        isGenerating = false
    }

    private func buildPlanContext() -> PlanContext {
        // Analyze stroke balance from recent notes
        let recentNotes = Array(appModel.notes.sorted { $0.date > $1.date }.prefix(14))
        let strokeBalance = analyzeStrokeBalance(recentNotes)

        // Analyze goal progress
        let goalProgress = analyzeGoalProgressInfo(appModel.notes)

        return PlanContext(
            profile: appModel.activeProfile,
            notes: recentNotes,
            poolType: poolType,
            sessionsPerWeek: sessionsPerWeek,
            includeDryLand: includeDryLand,
            strokeBalance: strokeBalance,
            goalProgress: goalProgress
        )
    }

    private func analyzeStrokeBalance(_ notes: [TrainingNote]) -> [StrokeBalanceInfo] {
        var counts: [StrokeID: Int] = [:]
        for note in notes {
            for stroke in note.strokeFocus {
                counts[stroke, default: 0] += 1
            }
        }
        let total = max(counts.values.reduce(0, +), 1)
        return StrokeID.allCases.filter { $0 != .im && $0 != .master }.map { stroke in
            StrokeBalanceInfo(
                stroke: stroke.rawValue,
                sessions: counts[stroke] ?? 0,
                percentage: Int((Double(counts[stroke] ?? 0) / Double(total)) * 100)
            )
        }.sorted { $0.sessions > $1.sessions }
    }

    private func analyzeGoalProgressInfo(_ notes: [TrainingNote]) -> GoalProgressInfo {
        var achieved: [GoalSummary] = []
        var struggling: [GoalSummary] = []
        var inProgress: [GoalSummary] = []
        var seenIds: Set<String> = []

        for note in notes.sorted(by: { $0.date > $1.date }) {
            for goal in note.goals {
                if seenIds.contains(goal.id) { continue }
                seenIds.insert(goal.id)

                let summary = GoalSummary(
                    stroke: goal.strokeId?.rawValue,
                    description: goal.description
                )

                switch goal.status {
                case .achieved:
                    if achieved.count < 3 { achieved.append(summary) }
                case .unableToAchieve:
                    if struggling.count < 3 { struggling.append(summary) }
                case .inProgress, .planned:
                    if inProgress.count < 5 { inProgress.append(summary) }
                }
            }
        }

        return GoalProgressInfo(achieved: achieved, struggling: struggling, inProgress: inProgress)
    }

    private func parsePlanJSON(_ raw: String) throws -> WeeklyTrainingPlan {
        // Extract JSON from response (may have markdown wrapper)
        var jsonString = raw.trimmingCharacters(in: .whitespaces)

        // Remove markdown code block wrapper if present
        if jsonString.hasPrefix("```json") {
            jsonString = jsonString.dropFirst(7).trimmingCharacters(in: .whitespaces)
        }
        if jsonString.hasPrefix("```") {
            jsonString = jsonString.dropFirst(3).trimmingCharacters(in: .whitespaces)
        }
        if jsonString.hasSuffix("```") {
            jsonString = String(jsonString.dropLast(3).trimmingCharacters(in: .whitespaces))
        }

        // Repair common LLM JSON typos
        jsonString = repairLLMJSON(jsonString)

        let decoder = JSONDecoder()
        let data = jsonString.data(using: .utf8) ?? Data()

        do {
            return try decoder.decode(WeeklyTrainingPlan.self, from: data)
        } catch let decodingError as DecodingError {
            // Provide detailed error info for debugging
            #if DEBUG
            print("❌ JSON Decoding Error:")
            print("Raw JSON (first 500 chars): \(String(jsonString.prefix(500)))")
            switch decodingError {
            case .keyNotFound(let key, let context):
                print("Missing key: \(key.stringValue) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                print("Debug description: \(context.debugDescription)")
            case .typeMismatch(let type, let context):
                print("Type mismatch: expected \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                print("Debug description: \(context.debugDescription)")
            case .valueNotFound(let type, let context):
                print("Value not found: \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
            case .dataCorrupted(let context):
                print("Data corrupted at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                print("Debug description: \(context.debugDescription)")
            @unknown default:
                print("Unknown decoding error: \(decodingError)")
            }
            #endif
            throw decodingError
        }
    }

    /// Repair common LLM JSON output issues
    private func repairLLMJSON(_ json: String) -> String {
        var repaired = json

        // Fix truncated keys: "ills" -> "drills"
        repaired = repaired.replacingOccurrences(of: "\"ills\":", with: "\"drills\":")
        repaired = repaired.replacingOccurrences(of: "\"ills\" :", with: "\"drills\" :")

        // Fix wrong field names from LLM
        repaired = repaired.replacingOccurrences(of: "\"sessions\":", with: "\"detailedSessions\":")
        repaired = repaired.replacingOccurrences(of: "\"exercisePlan\":", with: "\"dryLandProgram\":")
        repaired = repaired.replacingOccurrences(of: "\"dryLand\":", with: "\"dryLandProgram\":")
        repaired = repaired.replacingOccurrences(of: "\"goals\":", with: "\"weeklyGoals\":") // careful: don't break nested goals

        // Fix numbers as strings for Int fields (sessionNumber, sessionCount)
        // Pattern: "sessionNumber": "1" -> "sessionNumber": 1
        repaired = repaired.replacingOccurrences(of: "\"sessionNumber\": \"", with: "\"sessionNumber\": ")
        repaired = repaired.replacingOccurrences(of: "\"sessionCount\": \"", with: "\"sessionCount\": ")
        // Remove trailing quote after the number
        let intPattern = #"\"(sessionNumber|sessionCount|id)": (\d+)\""#
        if let regex = try? NSRegularExpression(pattern: intPattern, options: []) {
            let range = NSRange(repaired.startIndex..., in: repaired)
            repaired = regex.stringByReplacingMatches(in: repaired, options: [], range: range, withTemplate: "\"$1\": $2")
        }

        // Fix boolean values where strings are expected (common LLM mistake)
        // poolSession: true -> "Pool Session", false -> "Rest Day"
        repaired = repaired.replacingOccurrences(of: "\"poolSession\": true", with: "\"poolSession\": \"Pool Session\"")
        repaired = repaired.replacingOccurrences(of: "\"poolSession\": false", with: "\"poolSession\": \"Rest Day\"")
        // dryLand in schedule: true -> "Dry Land", false -> "None"
        repaired = repaired.replacingOccurrences(of: "\"dryLand\": true", with: "\"dryLand\": \"Dry Land Training\"")
        repaired = repaired.replacingOccurrences(of: "\"dryLand\": false", with: "\"dryLand\": \"None\"")
        // Other string fields that might get bools
        repaired = repaired.replacingOccurrences(of: "\"focus\": true", with: "\"focus\": \"Training\"")
        repaired = repaired.replacingOccurrences(of: "\"focus\": false", with: "\"focus\": \"Rest\"")
        repaired = repaired.replacingOccurrences(of: "\"duration\": true", with: "\"duration\": \"60 min\"")
        repaired = repaired.replacingOccurrences(of: "\"duration\": false", with: "\"duration\": \"0 min\"")
        repaired = repaired.replacingOccurrences(of: "\"sessionType\": true", with: "\"sessionType\": \"Pool\"")
        repaired = repaired.replacingOccurrences(of: "\"sessionType\": false", with: "\"sessionType\": \"Rest\"")

        // Fix malformed text in strings (e.g., "Arm Circlforward/backward)")
        // This is harder to fix automatically - leave for manual review

        // Fix missing commas between array elements (common in LLM output)
        // Pattern: } \n { without comma
        repaired = repaired.replacingOccurrences(of: "}\n      {", with: "},\n      {")
        repaired = repaired.replacingOccurrences(of: "}\n    {", with: "},\n    {")
        repaired = repaired.replacingOccurrences(of: "}\n  {", with: "},\n  {")
        repaired = repaired.replacingOccurrences(of: "}\n{", with: "},\n{")

        // Handle truncated JSON (response cut off mid-generation)
        // 1. Remove incomplete field at end (e.g., `"sessionNumber": 1, "` without field name)
        // Pattern: incomplete string key at end
        if repaired.hasSuffix("\"") || repaired.hasSuffix(", \"") {
            // Remove incomplete field starting with the last comma
            if let lastCommaIndex = repaired.lastIndex(of: ",") {
                let prefix = String(repaired[..<lastCommaIndex])
                // Check if the truncated part starts an incomplete field
                let suffix = String(repaired[lastCommaIndex...])
                if suffix.contains("\"") && !suffix.contains(":") {
                    repaired = prefix
                }
            }
        }

        // 2. Remove incomplete value at end (e.g., `"focus": "` without closing quote)
        // Find last incomplete string value
        let lastQuotePattern = #"[a-zA-Z]+\": \"[^\"]*$"#
        if let regex = try? NSRegularExpression(pattern: lastQuotePattern, options: []) {
            let range = NSRange(repaired.startIndex..., in: repaired)
            if let match = regex.firstMatch(in: repaired, options: [], range: range) {
                // Truncate the incomplete string value and replace with empty string
                let matchRange = Range(match.range, in: repaired)!
                let keyMatch = String(repaired[matchRange])
                if let colonIndex = keyMatch.firstIndex(of: ":") {
                    let keyPart = String(keyMatch[..<colonIndex])
                    repaired = repaired.replacingOccurrences(of: keyMatch, with: keyPart + ": \"\"")
                }
            }
        }

        // 3. Balance brackets (arrays) - count open/close brackets
        let openBrackets = repaired.filter { $0 == "[" }.count
        let closeBrackets = repaired.filter { $0 == "]" }.count
        if openBrackets > closeBrackets {
            // Add missing closing brackets
            repaired += String(repeating: "]", count: openBrackets - closeBrackets)
        }

        // 4. Balance braces (objects) - count open/close braces
        let openBraces = repaired.filter { $0 == "{" }.count
        let closeBraces = repaired.filter { $0 == "}" }.count
        if openBraces > closeBraces {
            // Add missing closing braces
            repaired += String(repeating: "}", count: openBraces - closeBraces)
        }

        // 5. Handle trailing commas before closing brackets/braces
        repaired = repaired.replacingOccurrences(of: ",]", with: "]")
        repaired = repaired.replacingOccurrences(of: ",}", with: "}")

        // 6. Add missing "notes" field if not present (required by WeeklyTrainingPlan)
        if !repaired.contains("\"notes\":") {
            // Find the last closing brace of the root object and add notes before it
            // Pattern: find position to insert
            if let lastBraceIndex = repaired.lastIndex(of: "}") {
                let insertPosition = repaired.index(before: lastBraceIndex)
                repaired = String(repaired[..<insertPosition]) + ",\n  \"notes\": \"\"\n}"
            }
        }

        return repaired
    }

    private func loadSamplePlan() {
        // Load sample plan from file for UI testing
        let samplePath = "/Users/zhongmingyu/Documents/Developer/SwimNote/sample_training_plan.json"

        guard let data = FileManager.default.contents(atPath: samplePath) else {
            errorMessage = "Could not load sample plan file"
            return
        }

        do {
            let rawString = String(data: data, encoding: .utf8) ?? ""
            generatedPlan = rawString
            var plan = try parsePlanJSON(rawString)
            plan = enrichPlanWithComputedFields(plan: plan, sessionsPerWeek: sessionsPerWeek, poolType: poolType, profile: appModel.activeProfile)
            parsedPlan = plan
            errorMessage = nil
            savedStatus = nil // Reset save status

            // Expand first session by default
            expandedSessions.insert(1)
        } catch {
            errorMessage = "Failed to parse sample plan: \(error.localizedDescription)"
        }
    }

    /// Populate computed fields that shouldn't come from LLM
    private func enrichPlanWithComputedFields(
        plan: WeeklyTrainingPlan,
        sessionsPerWeek: Int,
        poolType: PoolType,
        profile: UserProfile?
    ) -> WeeklyTrainingPlan {
        var enriched = plan

        // Set week starting date
        enriched.weekStartingDate = weekStartingDate

        // Build swimmer summary from profile
        if let profile = profile {
            let pbs = profile.personalBests
            let pbText = pbs.isEmpty ? "No PBs recorded" :
                "PBs: Free \(pbs.freestyle50m ?? 0)s, Back \(pbs.backstroke50m ?? 0)s"
            enriched.overview.swimmerSummary = """
            \(profile.name), Age \(profile.age), \(profile.skillLevel.rawValue.capitalized) level.
            Target: \(sessionsPerWeek) sessions/week.
            Strokes: \(profile.preferredStrokes.map { $0.rawValue.capitalized }.joined(separator: ", "))
            \(pbText)
            """
        }

        // Set session count from settings
        enriched.overview.sessionCount = sessionsPerWeek

        // Set pool type from user selection
        enriched.overview.poolType = poolType.shortLabel

        // Store raw pool type for proper distance display when loading saved plans
        enriched.poolTypeRaw = poolType.rawValue

        // Fix segment distances - calculate from actual set descriptions
        enriched.detailedSessions = enriched.detailedSessions.map { session in
            var fixedSession = session
            fixedSession.warmUp = fixSegmentDistance(session.warmUp, poolType: poolType)
            fixedSession.drillSet = fixSegmentDistance(session.drillSet, poolType: poolType)
            fixedSession.mainSet = fixSegmentDistance(session.mainSet, poolType: poolType)
            if let secondary = session.secondarySet {
                fixedSession.secondarySet = fixSegmentDistance(secondary, poolType: poolType)
            }
            fixedSession.coolDown = fixSegmentDistance(session.coolDown, poolType: poolType)
            return fixedSession
        }

        // Calculate total distance from detailed sessions (now with corrected distances)
        let totalMeters = enriched.detailedSessions.reduce(0) { sum, session in
            let sessionDistance = sum
                + parseDistance(session.warmUp.distance)
                + parseDistance(session.drillSet.distance)
                + parseDistance(session.mainSet.distance)
                + parseDistance(session.coolDown.distance)
            // Add secondary set distance if present
            if let secondary = session.secondarySet {
                return sessionDistance + parseDistance(secondary.distance)
            }
            return sessionDistance
        }
        // Format total distance with appropriate unit (meters or yards)
        enriched.overview.totalDistance = "~\(poolType.formatDistance(totalMeters))"

        // Assign dates to sessions
        enriched.detailedSessions = assignSessionDates(
            sessions: enriched.detailedSessions,
            weekStarting: weekStartingDate,
            sessionsPerWeek: sessionsPerWeek
        )

        // Assign dates to dry land exercises (spread across rest days)
        enriched.dryLandProgram = assignDryLandDates(
            exercises: enriched.dryLandProgram,
            sessions: enriched.detailedSessions,
            weekStarting: weekStartingDate
        )

        return enriched
    }

    /// Assign dates to dry land exercises on days without pool sessions
    private func assignDryLandDates(
        exercises: [DryLandExercisePlan]?,
        sessions: [DetailedSession],
        weekStarting: Date
    ) -> [DryLandExercisePlan]? {
        guard let exercises = exercises, !exercises.isEmpty else { return exercises }

        var assigned = exercises
        let calendar = Calendar.current

        // Get dates that have pool sessions
        let sessionDates = sessions.compactMap { $0.scheduledDate }.map { DateFormatter.yyyyMMdd.string(from: $0) }

        // Find available days (days without pool sessions) for dry land
        var availableDays: [Date] = []
        for dayOffset in 0..<7 {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStarting) ?? weekStarting
            let dateStr = DateFormatter.yyyyMMdd.string(from: date)
            if !sessionDates.contains(dateStr) {
                availableDays.append(date)
            }
        }

        // Fallback: if no available days, use all days in the week
        if availableDays.isEmpty {
            for dayOffset in 0..<7 {
                availableDays.append(calendar.date(byAdding: .day, value: dayOffset, to: weekStarting) ?? weekStarting)
            }
        }

        // Assign dry land exercises to available days, cycling if needed
        for (index, _) in assigned.enumerated() {
            let dayIndex = index % availableDays.count
            assigned[index].scheduledDate = availableDays[dayIndex]
            assigned[index].isAssigned = true  // Mark as assigned when auto-scheduled
        }

        return assigned
    }

    /// Fix segment distance by computing from structured sets (preferred) or parsing description (fallback)
    private func fixSegmentDistance(_ segment: SessionSegment, poolType: PoolType) -> SessionSegment {
        var fixed = segment

        // Preferred: Use structured sets array for accurate calculation
        if let sets = segment.sets, !sets.isEmpty {
            let calculatedMeters = sets.reduce(0) { $0 + $1.totalDistance }
            // Format distance with appropriate unit (yards or meters)
            fixed.distance = poolType.formatDistance(calculatedMeters)

            // Build description from sets for display
            fixed.description = sets.map { $0.formatted }.joined(separator: "\n")

            // Extract drill names from sets that are drills
            let drillSets = sets.filter { $0.item.lowercased().contains("drill") || $0.notes?.lowercased().contains("drill") ?? false }
            if !drillSets.isEmpty {
                fixed.drills = drillSets.map { $0.item }
            }
        } else {
            // Fallback: Parse description for NxM patterns
            let calculatedMeters = calculateDistanceFromDescription(segment.description)
            let statedDistance = parseDistance(segment.distance)

            if calculatedMeters > 0 && (statedDistance == 0 || abs(calculatedMeters - statedDistance) > 50) {
                fixed.distance = poolType.formatDistance(calculatedMeters)
            } else if statedDistance > 0 {
                // Re-format stated distance with correct unit
                fixed.distance = poolType.formatDistance(statedDistance)
            }
        }

        return fixed
    }

    /// Calculate total distance from set descriptions like "6x50 breaststroke, 4x25 streamline"
    private func calculateDistanceFromDescription(_ description: String) -> Int {
        var totalDistance = 0

        // Pattern: NxM where N is reps, M is distance per rep
        // Examples: "6x50", "4x25", "2x50m", "10x100m breaststroke"
        let pattern = #"(\d+)\s*[x×]\s*(\d+)"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return 0
        }

        let range = NSRange(description.startIndex..., in: description)
        let matches = regex.matches(in: description, options: [], range: range)

        for match in matches {
            // Extract reps and distance per rep
            if let repsRange = Range(match.range(at: 1), in: description),
               let distanceRange = Range(match.range(at: 2), in: description) {
                let repsStr = String(description[repsRange])
                let distStr = String(description[distanceRange])

                if let reps = Int(repsStr), let distance = Int(distStr) {
                    totalDistance += reps * distance
                }
            }
        }

        return totalDistance
    }

    /// Parse distance string like "400m" or "~1500m" into meters
    private func parseDistance(_ distance: String) -> Int {
        let digits = distance.filter { $0.isNumber }
        return Int(digits) ?? 0
    }

    /// Update a session's scheduled date and mark as assigned
    private func updateSessionDate(sessionNumber: Int, date: Date) {
        guard var plan = parsedPlan else { return }
        for i in plan.detailedSessions.indices {
            if plan.detailedSessions[i].sessionNumber == sessionNumber {
                plan.detailedSessions[i].scheduledDate = date
                plan.detailedSessions[i].isAssigned = true  // Mark as assigned when user picks a date
            }
        }
        parsedPlan = plan
    }

    /// Update a dry land exercise's scheduled date and mark as assigned
    private func updateDryLandDate(exerciseId: String, date: Date) {
        guard var plan = parsedPlan,
              var dryLand = plan.dryLandProgram else { return }
        for i in dryLand.indices {
            if dryLand[i].id == exerciseId {
                dryLand[i].scheduledDate = date
                dryLand[i].isAssigned = true  // Mark as assigned when user picks a date
            }
        }
        plan.dryLandProgram = dryLand
        parsedPlan = plan
    }

    /// Assign dates to sessions based on sessionsPerWeek
    private func assignSessionDates(
        sessions: [DetailedSession],
        weekStarting: Date,
        sessionsPerWeek: Int
    ) -> [DetailedSession] {
        var assigned = sessions
        let calendar = Calendar.current

        // Distribution: spread sessions evenly across the week
        // 3 sessions: Mon, Wed, Fri
        // 4 sessions: Mon, Tue, Thu, Fri
        // 5 sessions: Mon, Tue, Wed, Thu, Fri
        // 6 sessions: Mon, Tue, Wed, Thu, Fri, Sat
        let dayOffsets = dayOffsetsForSessions(count: sessionsPerWeek)

        for (index, _) in assigned.enumerated() {
            if index < dayOffsets.count {
                assigned[index].scheduledDate = calendar.date(byAdding: .day, value: dayOffsets[index], to: weekStarting)
                assigned[index].isAssigned = true  // Mark as assigned when auto-scheduled
            } else {
                // Fallback: assign to consecutive days
                assigned[index].scheduledDate = calendar.date(byAdding: .day, value: index, to: weekStarting)
                assigned[index].isAssigned = true
            }
        }

        return assigned
    }

    /// Get day offsets for even session distribution
    private func dayOffsetsForSessions(count: Int) -> [Int] {
        switch count {
        case 1: return [0] // Monday only
        case 2: return [0, 2] // Mon, Wed
        case 3: return [0, 2, 4] // Mon, Wed, Fri
        case 4: return [0, 1, 3, 4] // Mon, Tue, Thu, Fri
        case 5: return [0, 1, 2, 3, 4] // Mon-Fri
        case 6: return [0, 1, 2, 3, 4, 5] // Mon-Sat
        case 7: return [0, 1, 2, 3, 4, 5, 6] // All week
        default: return Array(0..<count)
        }
    }
}

// MARK: - Collapsible Settings Card

private struct CollapsibleSettingsCard: View {
    let isExpanded: Bool
    @Binding var poolType: PoolType
    @Binding var sessionsPerWeek: Int
    @Binding var planType: PlanType
    @Binding var includeDryLand: Bool
    @Binding var weekStartingDate: Date
    let isGenerating: Bool
    let onToggle: () -> Void
    let onGenerate: () -> Void
    let onLoadSample: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header - compact, info-dense
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    onToggle()
                }
            } label: {
                HStack(spacing: 10) {
                    // Chevron left
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(PoolTheme.mid)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))

                    Text("Plan Generator")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(PoolTheme.deep)

                    // Compact summary pills
                    HStack(spacing: 6) {
                        PoolPill(poolType.shortLabel)
                        SessionsPill(count: sessionsPerWeek)
                    }

                    Spacer()

                    // Action hint when collapsed
                    if !isExpanded {
                        Text("Tap to configure")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(PoolTheme.smoke.opacity(0.7))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expandable content
            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    // Settings Grid
                    VStack(spacing: 12) {
                        // Row 1: Pool (full width)
                        HStack {
                            Text("Pool")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(PoolTheme.smoke)
                                .tracking(0.5)

                            Spacer()

                            // Segmented buttons
                            HStack(spacing: 2) {
                                ForEach([PoolType.shortCourse, PoolType.shortCourseYards, PoolType.longCourse, PoolType.longCourseYards], id: \.self) { type in
                                    Button {
                                        poolType = type
                                    } label: {
                                        Text(type.shortLabel)
                                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 5)
                                            .background(poolType == type ? PoolTheme.mid : Color.clear)
                                            .foregroundStyle(poolType == type ? .white : PoolTheme.deep)
                                            .cornerRadius(5)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(2)
                            .background(PoolTheme.surface)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(PoolTheme.border.opacity(0.5), lineWidth: 0.5)
                            )
                        }

                        Divider()
                            .background(PoolTheme.border)

                        // Row 2: Sessions (full width)
                        HStack {
                            Text("Sessions")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(PoolTheme.smoke)
                                .tracking(0.5)

                            Spacer()

                            HStack(spacing: 4) {
                                ForEach([2, 3, 4, 5, 6], id: \.self) { count in
                                    Button {
                                        sessionsPerWeek = count
                                    } label: {
                                        Text("\(count)")
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .frame(width: 28, height: 26)
                                            .background(sessionsPerWeek == count ? PoolTheme.mid : PoolTheme.surface)
                                            .foregroundStyle(sessionsPerWeek == count ? .white : PoolTheme.deep)
                                            .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Divider()
                            .background(PoolTheme.border)

                        // Row 3: Type (full width)
                        HStack {
                            Text("Type")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(PoolTheme.smoke)
                                .tracking(0.5)

                            Spacer()

                            Menu {
                                ForEach(PlanType.allCases) { type in
                                    Button {
                                        planType = type
                                    } label: {
                                        Label(type.rawValue, systemImage: type.icon)
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: planType.icon)
                                        .font(.system(size: 11, weight: .semibold))
                                    Text(planType.rawValue)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 9, weight: .bold))
                                }
                                .foregroundStyle(PoolTheme.mid)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(PoolTheme.light.opacity(0.25))
                                .cornerRadius(8)
                            }
                        }

                        // Type description
                        Text(planType.description)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(PoolTheme.smoke.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, -4)

                        Divider()
                            .background(PoolTheme.border)

                        // Row 4: Dry Land + Week
                        HStack {
                            Text("Dry Land")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(PoolTheme.smoke)
                                .tracking(0.5)

                            Toggle("", isOn: $includeDryLand)
                                .tint(PoolTheme.mid)
                                .labelsHidden()
                                .scaleEffect(0.85)

                            Spacer()

                            Text("Week")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(PoolTheme.smoke)
                                .tracking(0.5)

                            DatePicker("", selection: $weekStartingDate, displayedComponents: .date)
                                .labelsHidden()
                                .scaleEffect(0.75)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(PoolTheme.surface.opacity(0.5))
                    .cornerRadius(10)

                    // Generate Section
                    VStack(spacing: 6) {
                        // Primary button
                        Button {
                            onGenerate()
                        } label: {
                            HStack(spacing: 8) {
                                if isGenerating {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.9)
                                } else {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                Text(isGenerating ? "Generating..." : "Generate Training Plan")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [PoolTheme.mid, PoolTheme.mid.opacity(0.85)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isGenerating)
                        .animation(.easeInOut(duration: 0.15), value: isGenerating)

                        // Debug link
                        Button {
                            onLoadSample()
                        } label: {
                            Text("Load Sample Plan")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(PoolTheme.smoke)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(PoolTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(PoolTheme.border, lineWidth: 1)
        )
        .shadow(color: PoolTheme.shadow, radius: 8, x: 0, y: 4)
    }
}

// MARK: - Compact Pills

private struct PoolPill: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(PoolTheme.mid)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(PoolTheme.light.opacity(0.25))
            .cornerRadius(5)
    }
}

private struct SessionsPill: View {
    let count: Int
    init(count: Int) { self.count = count }

    var body: some View {
        Text("\(count)×")
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(PoolTheme.mid)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(PoolTheme.light.opacity(0.25))
            .cornerRadius(5)
    }
}

/// Get next Monday from today
func nextMonday() -> Date {
    let calendar = Calendar.current
    let today = Date()
    let weekday = calendar.component(.weekday, from: today)

    // weekday: 1=Sunday, 2=Monday, ...
    let daysUntilMonday = weekday == 2 ? 0 : (9 - weekday) // If today is Monday, use today; else find next Monday
    return calendar.date(byAdding: .day, value: daysUntilMonday, to: today) ?? today
}

#Preview("Planning") {
    PlanningView(appModel: {
        let model = SwimNoteAppModel.bootstrap()
        model.activeProfile = UserProfile(
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
        return model
    }())
}
