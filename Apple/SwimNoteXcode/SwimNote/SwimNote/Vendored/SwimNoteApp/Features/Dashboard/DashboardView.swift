import SwiftUI

struct DashboardView: View {
    @Bindable var appModel: SwimNoteAppModel
    @Environment(ContentStore.self) private var contentStore
    @State private var note: TrainingNote?
    @State private var isLoading = true
    @State private var navigationPath = NavigationPath()
    @State private var showingProfileMenu = false
    @State private var showingUserSelection = false
    @State private var showingEditProfile = false
    @State private var selectedPlan: TrainingPlan?
    @State private var selectedSession: DetailedSession?
    @State private var selectedStrokeTab: StrokeID? = .freestyle
    @State private var showingGoalNotes: Goal?
    @State private var goalNotesText = ""
    @State private var expandedGoals: Set<String> = []
    @State private var showingAddGeneralGoal = false
    @State private var newGeneralGoalText = ""
    @State private var showingSessionNotes = false
    @State private var sessionNotesText = ""
    @State private var isStrokeTechniqueExpanded = false
    @State private var strokeTechniqueContent: StrokeQuickReferenceContent?
    @State private var generatingCuesGoalId: String?

    private var todayPlan: TrainingPlan? {
        appModel.planForDate(SwimNoteDateFormatting.todayShort())
    }

    private var todaySessions: [DetailedSession] {
        let todayStr = SwimNoteDateFormatting.todayShort()
        // Use cached lookup from appModel
        return appModel.sessionsForDate(todayStr)
    }

    private var todayDryLandExercises: [DryLandExercisePlan] {
        let todayStr = SwimNoteDateFormatting.todayShort()
        var exercises: [DryLandExercisePlan] = []
        var seenIds: Set<String> = []
        for plan in appModel.weeklyPlans {
            guard let dryLand = plan.dryLandProgram else { continue }
            for exercise in dryLand {
                if let date = exercise.scheduledDate {
                    let exerciseDateStr = SwimNoteDateFormatting.shortDateString(from: date)
                    if exerciseDateStr == todayStr && !seenIds.contains(exercise.id) {
                        seenIds.insert(exercise.id)
                        exercises.append(exercise)
                    }
                }
            }
        }
        return exercises
    }

    private var todayTrainingCompletionStat: String {
        var total = 0
        var completed = 0

        for session in todaySessions {
            total += 1
            if session.isCompleted { completed += 1 }
        }

        for exercise in todayDryLandExercises {
            total += 1
            if exercise.isCompleted { completed += 1 }
        }

        return total > 0 ? "\(completed)/\(total)" : ""
    }

    private var goalsForSelectedStroke: [Goal] {
        guard let note else { return [] }
        if selectedStrokeTab == nil {
            // General tab: goals with no strokeId
            return note.goals.filter { $0.strokeId == nil }
        }
        return note.goals.filter { $0.strokeId == selectedStrokeTab }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 1. Title Header
                    header

                    // 2. Session Notes Card (with 4 stroke tabs)
                    sessionNotesCard

                    // 3. Training Plan Card
                    trainingPlanSection
                }
                .padding()
            }
            .background(
                LinearGradient(colors: [PoolTheme.surface, PoolTheme.light.opacity(0.5)], startPoint: .top, endPoint: .bottom)
            )
            .task {
                note = await appModel.noteForToday()
                isLoading = false
            }
            .onChange(of: appModel.activeProfile?.id) { _, _ in
                Task {
                    note = await appModel.noteForToday()
                }
                // Reset UI state for new profile
                selectedPlan = nil
                selectedSession = nil
                expandedGoals = []
                showingGoalNotes = nil
                goalNotesText = ""
                showingSessionNotes = false
                sessionNotesText = ""
            }
            .overlay {
                if isLoading {
                    ProgressView("Loading...")
                }
            }
            .navigationDestination(for: StrokeNavigationValue.self) { value in
                if let tree = contentStore.tree(for: value.strokeId) {
                    TechniqueTreeView(appModel: appModel, tree: tree)
                }
            }
            .navigationDestination(for: NodeNavigationValue.self) { value in
                if let tree = contentStore.tree(for: value.strokeId),
                   let node = tree.nodes.first(where: { $0.id == value.nodeId }) {
                    NodeDetailView(appModel: appModel, tree: tree, node: node)
                }
            }
            .sheet(isPresented: $showingUserSelection) {
                UserSelectionView(appModel: appModel)
            }
            .sheet(isPresented: $showingEditProfile) {
                if let profile = appModel.activeProfile {
                    PersonalBestsEditor(appModel: appModel, profile: profile)
                }
            }
            .sheet(item: $selectedPlan) { plan in
                NavigationStack {
                    TrainingPlanView(appModel: appModel, plan: plan)
                }
                .presentationDetents([.large])
            }
            .sheet(item: $selectedSession) { session in
                NavigationStack {
                    ScrollView {
                        SessionCard(
                            session: session,
                            isExpanded: true,
                            onToggleExpand: {},
                            onDateChange: nil,
                            showDatePicker: false,
                            poolType: nil
                        )
                        .padding()
                    }
                    .navigationTitle("Today's Session")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { selectedSession = nil }
                        }
                    }
                }
            }
            .sheet(item: $showingGoalNotes) { goal in
                goalNotesSheet(goal)
            }
            .sheet(isPresented: $showingAddGeneralGoal) {
                addGeneralGoalSheet
            }
            .sheet(isPresented: $showingSessionNotes) {
                sessionNotesSheet
            }
        }
    }

    // MARK: - 1. Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TODAY")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(PoolTheme.deep)

                Text(formattedTodayDate)
                    .font(.subheadline)
                    .foregroundStyle(PoolTheme.mid)
            }

            Spacer()

            if let profile = appModel.activeProfile {
                Button {
                    showingProfileMenu = true
                } label: {
                    ProfileIconView(profile: profile, size: 40)
                }
                .buttonStyle(.plain)
                .confirmationDialog("Profile Options", isPresented: $showingProfileMenu) {
                    Button("Switch User") { showingUserSelection = true }
                    Button("Edit Profile") { showingEditProfile = true }
                    Button("Cancel", role: .cancel) { }
                }
            }
        }
    }

    private var formattedTodayDate: String {
        DateFormatter.displayDate.string(from: Date())
    }

    // MARK: - 2. Session Notes Card (with Stroke Tabs)

    private var sessionNotesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Card header
            HStack {
                Image(systemName: "note.text")
                    .font(.title3)
                    .foregroundStyle(PoolTheme.mid)

                Text("Session Notes")
                    .font(.headline.bold())
                    .foregroundStyle(PoolTheme.deep)

                Spacer()
            }

            // 4 Stroke Tabs
            strokeTabs

            // Collapsible stroke technique quick reference
            strokeTechniqueQuickRef

            // Focus Areas for selected stroke
            focusAreasContent

            // Session Notes text field (overall notes)
            overallNotesField
        }
        .poolCard()
    }

    private var strokeTabs: some View {
        HStack(spacing: 8) {
            // General tab for goals with no stroke
            generalTabButton

            ForEach([StrokeID.freestyle, .backstroke, .breaststroke, .butterfly], id: \.self) { stroke in
                strokeTabButton(stroke)
            }
        }
    }

    private var generalTabButton: some View {
        Button {
            selectedStrokeTab = nil
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 18))
                    .frame(width: 28, height: 28)

                Text("General")
                    .font(.caption.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(selectedStrokeTab == nil ? PoolTheme.mid : PoolTheme.light.opacity(0.3))
            .foregroundStyle(selectedStrokeTab == nil ? .white : PoolTheme.deep)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func strokeTabButton(_ stroke: StrokeID) -> some View {
        Button {
            selectedStrokeTab = stroke
        } label: {
            VStack(spacing: 4) {
                Image(strokeIconName(stroke))
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)

                Text(strokeName(stroke))
                    .font(.caption.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(selectedStrokeTab == stroke ? PoolTheme.mid : PoolTheme.light.opacity(0.3))
            .foregroundStyle(selectedStrokeTab == stroke ? .white : PoolTheme.deep)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func strokeIconName(_ stroke: StrokeID) -> String {
        switch stroke {
        case .freestyle: "FreestyleIcon"
        case .backstroke: "BackstrokeIcon"
        case .breaststroke: "BreaststrokeIcon"
        case .butterfly: "ButterflyIcon"
        default: "FreestyleIcon"
        }
    }

    private func strokeName(_ stroke: StrokeID) -> String {
        switch stroke {
        case .freestyle: "Free"
        case .backstroke: "Back"
        case .breaststroke: "Breast"
        case .butterfly: "Fly"
        default: stroke.rawValue.capitalized
        }
    }

    // MARK: - Stroke Technique Quick Reference

    private var strokeTechniqueQuickRef: some View {
        Group {
            if selectedStrokeTab != nil {
                VStack(alignment: .leading, spacing: 8) {
                    // Collapsible header - always visible when stroke selected
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isStrokeTechniqueExpanded.toggle()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "lightbulb")
                                .font(.caption)
                                .foregroundStyle(PoolTheme.mid)

                            Text("Technique Quick Reference")
                                .font(.caption.bold())
                                .foregroundStyle(PoolTheme.smoke)

                            Spacer()

                            Image(systemName: isStrokeTechniqueExpanded ? "chevron.down" : "chevron.right")
                                .font(.caption)
                                .foregroundStyle(PoolTheme.mid)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // Expandable content - only when expanded AND content loaded
                    if isStrokeTechniqueExpanded, let content = strokeTechniqueContent {
                        VStack(alignment: .leading, spacing: 12) {
                            // Mental cues (if available)
                            if !content.mentalCues.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Mental Cues")
                                        .font(.caption2.bold())
                                        .foregroundStyle(PoolTheme.smoke.opacity(0.7))

                                    ForEach(content.mentalCues, id: \.self) { cue in
                                        Text(cue)
                                            .font(.caption2)
                                            .foregroundStyle(PoolTheme.deep)
                                    }
                                }
                            }

                            // Image references
                            if !content.imageReferences.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Key Positions")
                                        .font(.caption2.bold())
                                        .foregroundStyle(PoolTheme.smoke.opacity(0.7))

                                    ForEach(content.imageReferences, id: \.title) { ref in
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(ref.title)
                                                .font(.caption2.bold())
                                                .foregroundStyle(PoolTheme.mid)

                                            ForEach(ref.cues, id: \.self) { cue in
                                                Text(cue)
                                                    .font(.caption2)
                                                    .foregroundStyle(PoolTheme.deep.opacity(0.8))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.vertical, 8)
                .background(PoolTheme.light.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .task(id: selectedStrokeTab) {
            // Load content whenever stroke tab changes - task is on Group, not inside conditional
            loadStrokeTechniqueContent()
        }
    }

    private func loadStrokeTechniqueContent() {
        guard let stroke = selectedStrokeTab else {
            strokeTechniqueContent = nil
            return
        }

        // Load preprocessed JSON file
        guard let url = Bundle.main.url(forResource: "stroke-quick-reference", withExtension: "json", subdirectory: "swimming-strokes") ??
                      Bundle.main.url(forResource: "stroke-quick-reference", withExtension: "json", subdirectory: "Resources/swimming-strokes") ??
                      Bundle.main.url(forResource: "stroke-quick-reference", withExtension: "json") else {
            #if DEBUG
            print("🔧 stroke-quick-reference.json not found in bundle")
            #endif
            strokeTechniqueContent = nil
            return
        }

        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strokes = json["strokes"] as? [String: Any],
              let strokeData = strokes[stroke.rawValue.lowercased()] as? [String: Any] else {
            #if DEBUG
            print("🔧 Failed to parse stroke-quick-reference.json for \(stroke.rawValue)")
            #endif
            strokeTechniqueContent = nil
            return
        }

        let mentalCues = (strokeData["mentalCues"] as? [String] ?? [])
        let imageRefs = (strokeData["imageReferences"] as? [[String: Any]] ?? []).map { refDict in
            ImageReference(
                title: refDict["title"] as? String ?? "",
                cues: refDict["cues"] as? [String] ?? []
            )
        }

        #if DEBUG
        print("🔧 Loaded stroke quick reference for \(stroke.rawValue): \(mentalCues.count) cues, \(imageRefs.count) refs")
        #endif

        strokeTechniqueContent = StrokeQuickReferenceContent(mentalCues: mentalCues, imageReferences: imageRefs)
    }

    // MARK: - Focus Areas Content

    private var focusAreasContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Text("Focus Areas")
                    .font(.subheadline.bold())
                    .foregroundStyle(PoolTheme.smoke)

                Spacer()

                Button {
                    if let strokeId = selectedStrokeTab {
                        // Navigate to technique tree for stroke-specific goals
                        navigationPath.append(StrokeNavigationValue(strokeId: strokeId))
                    } else {
                        // Show manual entry sheet for general goals
                        showingAddGeneralGoal = true
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                        .foregroundStyle(PoolTheme.mid)
                }
                .buttonStyle(.plain)
            }

            // Focus areas list or empty state
            if goalsForSelectedStroke.isEmpty {
                emptyFocusState
            } else {
                VStack(spacing: 8) {
                    ForEach(goalsForSelectedStroke) { goal in
                        SwipeToDeleteRow(onDelete: { deleteGoal(goal) }) {
                            CollapsibleGoalRow(
                                goal: goal,
                                isExpanded: expandedGoals.contains(goal.id),
                                onToggleExpand: { toggleGoalExpand(goal.id) },
                                onUpdateStatus: { updateGoalStatus(goal, newStatus: $0) },
                                onDelete: { deleteGoal(goal) },
                                onEditNotes: { showGoalNotes(goal) },
                                onGenerateCues: { Task { await generateFocusCues(for: goal) } }
                            )
                        }
                    }
                }
            }
        }
    }

    private func toggleGoalExpand(_ goalId: String) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if expandedGoals.contains(goalId) {
                expandedGoals.remove(goalId)
            } else {
                expandedGoals.insert(goalId)
            }
        }
    }

    private func showGoalNotes(_ goal: Goal) {
        goalNotesText = goal.notes ?? ""
        showingGoalNotes = goal
    }

    private var emptyFocusState: some View {
        VStack(alignment: .leading, spacing: 4) {
            if selectedStrokeTab == nil {
                Text("No general focus areas")
                    .font(.subheadline)
                    .foregroundStyle(PoolTheme.smoke)
                Text("Tap + to add a focus area")
                    .font(.caption)
                    .foregroundStyle(PoolTheme.smoke.opacity(0.7))
            } else {
                Text("No focus areas for \(selectedStrokeTab?.rawValue.capitalized ?? "General")")
                    .font(.subheadline)
                    .foregroundStyle(PoolTheme.smoke)
                Text("Tap + to browse technique tree")
                    .font(.caption)
                    .foregroundStyle(PoolTheme.smoke.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    // MARK: - Goal Actions

    private func updateGoalStatus(_ goal: Goal, newStatus: GoalStatus) {
        guard var updatedNote = note, let index = updatedNote.goals.firstIndex(where: { $0.id == goal.id }) else { return }
        updatedNote.goals[index].status = newStatus
        updatedNote.goals[index].updatedAt = SwimNoteDateFormatting.string(from: Date())
        note = updatedNote
        Task { await appModel.saveNote(updatedNote) }
    }

    private func deleteGoal(_ goal: Goal) {
        guard var updatedNote = note else { return }
        updatedNote.goals.removeAll { $0.id == goal.id }
        note = updatedNote
        Task { await appModel.saveNote(updatedNote) }
    }

    private func generateFocusCues(for goal: Goal) async {
        guard generatingCuesGoalId == nil else { return }
        generatingCuesGoalId = goal.id

        let cues = await appModel.generateFocusCues(for: goal, stroke: selectedStrokeTab)

        guard var updatedNote = note,
              let index = updatedNote.goals.firstIndex(where: { $0.id == goal.id }),
              let cues = cues, !cues.isEmpty else {
            generatingCuesGoalId = nil
            return
        }

        updatedNote.goals[index].suggestedCues = cues
        updatedNote.goals[index].updatedAt = SwimNoteDateFormatting.string(from: Date())
        note = updatedNote
        generatingCuesGoalId = nil

        // Competitive goals render cues only in the expanded section — open the row so new cues are visible.
        if updatedNote.goals[index].competitiveMetricSnapshot != nil {
            _ = withAnimation(.easeInOut(duration: 0.25)) {
                expandedGoals.insert(goal.id)
            }
        }

        Task { await appModel.saveNote(updatedNote) }
    }

    // MARK: - Session Actions

    private func toggleSessionCompletion(sessionId: String) {
        // Update ALL copies of this session across ALL plans
        var updatedPlans = appModel.weeklyPlans

        for planIndex in updatedPlans.indices {
            var updatedSessions = updatedPlans[planIndex].detailedSessions
            for sessionIndex in updatedSessions.indices {
                if updatedSessions[sessionIndex].id == sessionId {
                    updatedSessions[sessionIndex].isCompleted.toggle()
                }
            }
            updatedPlans[planIndex].detailedSessions = updatedSessions
        }

        appModel.weeklyPlans = updatedPlans

        Task {
            for plan in updatedPlans {
                try? await appModel.saveWeeklyPlan(plan)
            }
        }
    }

    private func toggleDryLandCompletion(exerciseId: String) {
        // Update ALL copies of this exercise across ALL plans
        var updatedPlans = appModel.weeklyPlans

        for planIndex in updatedPlans.indices {
            guard var dryLand = updatedPlans[planIndex].dryLandProgram else { continue }
            for exerciseIndex in dryLand.indices {
                if dryLand[exerciseIndex].id == exerciseId {
                    dryLand[exerciseIndex].isCompleted.toggle()
                }
            }
            updatedPlans[planIndex].dryLandProgram = dryLand
        }

        appModel.weeklyPlans = updatedPlans

        Task {
            for plan in updatedPlans {
                try? await appModel.saveWeeklyPlan(plan)
            }
        }
    }

    // MARK: - Overall Notes Field

    private var overallNotesField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session Notes")
                .font(.subheadline.bold())
                .foregroundStyle(PoolTheme.smoke)

            Button {
                sessionNotesText = note?.notes ?? ""
                showingSessionNotes = true
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "note.text")
                        .font(.title3)
                        .foregroundStyle(PoolTheme.mid)

                    if let notes = note?.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.subheadline)
                            .foregroundStyle(PoolTheme.deep)
                            .lineLimit(2...4)
                    } else {
                        Text("Tap to add session notes...")
                            .font(.subheadline)
                            .foregroundStyle(PoolTheme.smoke)
                    }

                    Spacer()

                    Image(systemName: "pencil.circle")
                        .font(.title3)
                        .foregroundStyle(PoolTheme.light)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(PoolTheme.light.opacity(0.08))
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Sheets

    private func goalNotesSheet(_ goal: Goal) -> some View {
        NavigationStack {
            Form {
                Section("Notes for this focus") {
                    TextField("Add coaching tips, observations...", text: $goalNotesText, axis: .vertical)
                        .lineLimit(3...6)
                        .submitLabel(.done)
                }
            }
            .navigationTitle(goal.description)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingGoalNotes = nil
                        goalNotesText = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard var updatedNote = note, let index = updatedNote.goals.firstIndex(where: { $0.id == goal.id }) else { return }
                        updatedNote.goals[index].notes = goalNotesText.isEmpty ? nil : goalNotesText
                        updatedNote.goals[index].updatedAt = SwimNoteDateFormatting.string(from: Date())
                        note = updatedNote
                        Task { await appModel.saveNote(updatedNote) }
                        showingGoalNotes = nil
                        goalNotesText = ""
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var sessionNotesSheet: some View {
        NavigationStack {
            Form {
                Section("Session Notes") {
                    TextField("How did the session feel? Overall observations...", text: $sessionNotesText, axis: .vertical)
                        .lineLimit(3...8)
                        .submitLabel(.done)
                }
            }
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingSessionNotes = false
                        sessionNotesText = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard var updatedNote = note else { return }
                        updatedNote.notes = sessionNotesText
                        note = updatedNote
                        Task { await appModel.saveNote(updatedNote) }
                        showingSessionNotes = false
                        sessionNotesText = ""
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var addGeneralGoalSheet: some View {
        NavigationStack {
            Form {
                Section("Add Focus Area") {
                    TextField("What are you working on?", text: $newGeneralGoalText, axis: .vertical)
                        .lineLimit(2...4)
                        .submitLabel(.done)
                }
            }
            .navigationTitle("General Focus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingAddGeneralGoal = false
                        newGeneralGoalText = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addGeneralGoal()
                    }
                    .disabled(newGeneralGoalText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func addGeneralGoal() {
        guard var updatedNote = note else { return }
        let trimmedText = newGeneralGoalText.trimmingCharacters(in: .whitespaces)
        guard !trimmedText.isEmpty else { return }

        let now = SwimNoteDateFormatting.string(from: Date())
        let newGoal = Goal(
            id: "goal_\(Int(Date().timeIntervalSince1970 * 1000))_\(UUID().uuidString.prefix(8))",
            type: .general,
            strokeId: nil,
            description: trimmedText,
            status: .planned,
            createdAt: now,
            updatedAt: now
        )

        updatedNote.goals.append(newGoal)
        note = updatedNote
        Task { await appModel.saveNote(updatedNote) }

        showingAddGeneralGoal = false
        newGeneralGoalText = ""
    }

    // MARK: - 3. Training Plan Card

    private var trainingPlanSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Image(systemName: "figure.pool.swim")
                    .font(.title3)
                    .foregroundStyle(PoolTheme.mid)

                Text("Today's Training")
                    .font(.headline.bold())
                    .foregroundStyle(PoolTheme.deep)

                Spacer()

                if !todayTrainingCompletionStat.isEmpty {
                    Text(todayTrainingCompletionStat)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(PoolTheme.smoke)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(PoolTheme.light.opacity(0.2))
                        )
                }
            }

            // Priority: show today's sessions from weekly plan (supports multiple sessions per day)
            if !todaySessions.isEmpty {
                ForEach(todaySessions) { session in
                    SwipeToToggleCompleteRow(
                        isAssigned: session.isAssigned,
                        isCompleted: session.isCompleted,
                        onToggle: { toggleSessionCompletion(sessionId: session.id) }
                    ) {
                        SessionCard(
                            session: session,
                            isExpanded: false,
                            onToggleExpand: { selectedSession = session },
                            onDateChange: nil,
                            showDatePicker: false,
                            poolType: nil,
                            onDelete: nil,
                            onComplete: nil
                        )
                    }
                }
            } else if let plan = todayPlan {
                // Legacy: show old TrainingPlan format
                TrainingPlanCard(plan: plan, onTap: { selectedPlan = plan })
            } else {
                Button {
                    appModel.selectedTab = .plan
                } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .foregroundStyle(PoolTheme.light)

                            Text("No training plan today")
                                .font(.subheadline)
                                .foregroundStyle(PoolTheme.smoke)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundStyle(PoolTheme.light)
                        }

                        Text("Generate a plan in the Plan tab")
                            .font(.caption)
                            .foregroundStyle(PoolTheme.mid)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .poolCard()
                }
                .buttonStyle(.plain)
            }

            // Dry Land section (if there are exercises for today)
            if !todayDryLandExercises.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.title3)
                            .foregroundStyle(.orange)
                        Text("Dry Land Training")
                            .font(.headline.bold())
                            .foregroundStyle(PoolTheme.deep)
                        Spacer()
                    }

                    ForEach(todayDryLandExercises) { exercise in
                        SwipeToToggleCompleteRow(
                            isAssigned: exercise.isAssigned,
                            isCompleted: exercise.isCompleted,
                            onToggle: { toggleDryLandCompletion(exerciseId: exercise.id) }
                        ) {
                            DryLandExerciseRow(exercise: exercise)
                        }
                    }
                }
                .poolCard()
            }
        }
    }
}

// MARK: - Previews

private func makePreviewModelWithSession() -> SwimNoteAppModel {
    let model = SwimNoteAppModel.bootstrap()

    let profile = UserProfile(
        id: "preview-user",
        name: "Alex Swimmer",
        birthday: "1995-06-15",
        sex: .male,
        skillLevel: .intermediate,
        weeklySessionTarget: 3,
        preferredStrokes: [.freestyle, .backstroke],
        personalBests: PersonalBests(freestyle50m: 32.5, backstroke50m: 35.0),
        trainingGoals: [],
        createdAt: "2024-01-01T00:00:00Z",
        updatedAt: "2024-01-01T00:00:00Z"
    )
    model.profileStore.activeProfile = profile
    model.loadBundledContent()

    // Add a training session for today with action buttons visible
    let todaySession = DetailedSession(
        id: "session-1",
        sessionNumber: 1,
        focus: "Freestyle Sprint Focus",
        warmUp: SessionSegment(distance: "400m", description: "Easy swim, build"),
        drillSet: SessionSegment(distance: "200m", description: "6-1-6 drill"),
        mainSet: SessionSegment(distance: "800m", description: "4x200 threshold"),
        coolDown: SessionSegment(distance: "200m", description: "Easy choice"),
        techniqueFocus: "High elbow catch",
        techniqueFileRef: nil,
        addressesGoal: nil,
        sessionType: "Sprint",
        progressionRationale: nil,
        sessionNotes: nil,
        scheduledDate: Date(),
        isCompleted: false,
        isAssigned: true  // Assigned to today, so swipe is enabled
    )

    let weeklyPlan = WeeklyTrainingPlan(
        overview: PlanOverview(
            weekFocus: "Freestyle speed work",
            technicalObjective: "High elbow catch",
            physicalObjective: "Build threshold pace",
            swimmerSummary: "Alex Swimmer, Intermediate",
            sessionCount: 1,
            poolType: "25m",
            totalDistance: "~1600m"
        ),
        schedule: [],
        detailedSessions: [todaySession],
        dryLandProgram: [
            DryLandExercisePlan(
                exercise: "Push-ups",
                setsReps: "3x15",
                focus: "Core strength",
                techniqueSupport: "Improves streamline hold",
                scheduledDate: Date(),
                isAssigned: true,  // Assigned to today, so swipe is enabled
                isCompleted: false
            ),
            DryLandExercisePlan(
                exercise: "Plank Hold",
                setsReps: "3x30s",
                focus: "Core stability",
                techniqueSupport: "Body position maintenance",
                scheduledDate: Date(),
                isAssigned: true,
                isCompleted: false
            )
        ],
        weeklyGoals: nil,
        techniqueProgressPlan: nil,
        notes: "",
        weekStartingDate: Date()
    )
    model.weeklyPlans = [weeklyPlan]

    let note = TrainingNote(
        userId: "preview-user",
        date: SwimNoteDateFormatting.todayShort(),
        strokeFocus: [.freestyle, .backstroke],
        techniqueFocus: [],
        goals: [
            Goal(id: "g0", type: .general, strokeId: nil, description: "Improve overall endurance", status: .inProgress, createdAt: "2024-01-01T00:00:00Z", updatedAt: "2024-01-01T00:00:00Z"),
            Goal(id: "g1", type: .technique, strokeId: .freestyle, description: "High elbow catch", status: .inProgress, createdAt: "2024-01-01T00:00:00Z", updatedAt: "2024-01-01T00:00:00Z"),
            Goal(id: "g2", type: .technique, strokeId: .freestyle, description: "Body rotation", status: .planned, createdAt: "2024-01-01T00:00:00Z", updatedAt: "2024-01-01T00:00:00Z"),
            Goal(id: "g3", type: .technique, strokeId: .backstroke, description: "Steady kick rhythm", status: .achieved, notes: "Good progress!", createdAt: "2024-01-01T00:00:00Z", updatedAt: "2024-01-01T00:00:00Z")
        ],
        notes: "Good session overall",
        createdAt: "2024-01-01T00:00:00Z",
        updatedAt: "2024-01-01T00:00:00Z"
    )
    model.notes = [note]

    return model
}

private func makeEmptyPreviewModel() -> SwimNoteAppModel {
    let model = SwimNoteAppModel.bootstrap()

    let profile = UserProfile(
        id: "preview-user",
        name: "New Swimmer",
        birthday: "2000-01-01",
        sex: .female,
        skillLevel: .beginner,
        weeklySessionTarget: 2,
        preferredStrokes: [],
        personalBests: .empty(),
        trainingGoals: [],
        createdAt: "2024-01-01T00:00:00Z",
        updatedAt: "2024-01-01T00:00:00Z"
    )
    model.profileStore.activeProfile = profile
    model.loadBundledContent()

    return model
}

// MARK: - Stroke Quick Reference Content

struct StrokeQuickReferenceContent {
    let mentalCues: [String]
    let imageReferences: [ImageReference]
}

struct ImageReference {
    let title: String
    let cues: [String]
}

#Preview("Dashboard - With Goals and Session") {
    let model = makePreviewModelWithSession()
    DashboardView(appModel: model)
        .environment(model.contentStore)
}

#Preview("Dashboard - Empty") {
    let model = makeEmptyPreviewModel()
    DashboardView(appModel: model)
        .environment(model.contentStore)
}
