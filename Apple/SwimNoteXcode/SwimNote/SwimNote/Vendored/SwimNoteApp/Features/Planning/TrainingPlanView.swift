import SwiftUI

// MARK: - Training Plan Card (Compact, Clickable)

struct TrainingPlanCard: View {
    let plan: TrainingPlan
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(PoolTheme.mid)
                    Text(plan.date)
                        .font(.headline)
                        .foregroundStyle(PoolTheme.deep)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(PoolTheme.light)
                }

                // Summary
                HStack(spacing: 8) {
                    Text("\(plan.sessions.count) sessions")
                        .font(.subheadline)
                        .foregroundStyle(PoolTheme.smoke)

                    if let firstSession = plan.sessions.first {
                        Text("•")
                            .foregroundStyle(PoolTheme.light)
                        Text(firstSession.focus)
                            .font(.subheadline)
                            .foregroundStyle(PoolTheme.mid)
                            .lineLimit(1)
                    }
                }

                // Dry land indicator
                if let dryLand = plan.dryLandTraining, !dryLand.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.caption)
                        Text("+ Dry land")
                            .font(.caption)
                    }
                    .foregroundStyle(PoolTheme.light)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .poolCard()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Training Plan View (Full Detail, Editable)

struct TrainingPlanView: View {
    @Bindable var appModel: SwimNoteAppModel
    @State private var plan: TrainingPlan
    @State private var isEditing: Bool = false
    @State private var isModifying: Bool = false
    @State private var modifyError: String?
    @Environment(\.dismiss) private var dismiss

    private let llmClient = OpenAIClient()
    private let credentialStore: any SecureCredentialStore = {
        #if canImport(Security)
        KeychainCredentialStore()
        #else
        InMemoryCredentialStore()
        #endif
    }()

    init(appModel: SwimNoteAppModel, plan: TrainingPlan) {
        self.appModel = appModel
        self._plan = State(initialValue: plan)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection

                overviewSection

                sessionsSection

                dryLandSection

                remarksSection

                llmActionsSection
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
        .navigationTitle("Training Plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(isEditing ? "Save" : "Edit") {
                    if isEditing {
                        savePlan()
                    }
                    isEditing.toggle()
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
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

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(PoolTheme.mid)
                    .font(.title2)
                Text(plan.date)
                    .font(.title.bold())
                    .foregroundStyle(PoolTheme.deep)
            }

            Text("\(plan.sessions.count) training sessions planned")
                .font(.subheadline)
                .foregroundStyle(PoolTheme.smoke)
        }
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.headline)
                .foregroundStyle(PoolTheme.mid)

            if isEditing {
                TextField("Overview", text: $plan.overview, axis: .vertical)
                    .lineLimit(3...8)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
            } else {
                Text(plan.overview.isEmpty ? "No overview." : plan.overview)
                    .font(.body)
                    .foregroundStyle(PoolTheme.deep)
            }
        }
        .poolCard()
    }

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Training Schedule")
                .font(.headline)
                .foregroundStyle(PoolTheme.mid)

            // Header row
            HStack(spacing: 0) {
                Text("#")
                    .font(.caption.bold())
                    .frame(width: 40, alignment: .leading)
                Text("Focus")
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Details")
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Goals")
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(PoolTheme.smoke)
            .padding(.horizontal, 8)

            Divider()

            // Session rows
            ForEach(plan.sessions.indices, id: \.self) { index in
                sessionRow(index)
            }

            // Add session button (edit mode)
            if isEditing {
                Button("Add Session", systemImage: "plus") {
                    let newNumber = (plan.sessions.last?.sessionNumber ?? 0) + 1
                    plan.sessions.append(TrainingSession(
                        sessionNumber: newNumber,
                        focus: "",
                        details: "",
                        goals: ""
                    ))
                }
                .buttonStyle(.bordered)
                .tint(PoolTheme.mid)
            }
        }
        .poolCard()
    }

    private func sessionRow(_ index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if isEditing {
                HStack(spacing: 8) {
                    Text("#\(plan.sessions[index].sessionNumber)")
                        .font(.subheadline.bold())
                        .foregroundStyle(PoolTheme.mid)
                        .frame(width: 40)

                    TextField("Focus", text: $plan.sessions[index].focus)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)

                    TextField("Details", text: $plan.sessions[index].details)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)

                    TextField("Goals", text: $plan.sessions[index].goals)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                }

                // Delete button
                Button("Remove", systemImage: "trash") {
                    plan.sessions.remove(at: index)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            } else {
                HStack(spacing: 0) {
                    Text("#\(plan.sessions[index].sessionNumber)")
                        .font(.subheadline.bold())
                        .foregroundStyle(PoolTheme.mid)
                        .frame(width: 40, alignment: .leading)

                    Text(plan.sessions[index].focus)
                        .font(.subheadline)
                        .foregroundStyle(PoolTheme.deep)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(plan.sessions[index].details)
                        .font(.subheadline)
                        .foregroundStyle(PoolTheme.deep)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(2)

                    Text(plan.sessions[index].goals)
                        .font(.subheadline)
                        .foregroundStyle(PoolTheme.deep)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(2)
                }
                .padding(.horizontal, 8)
            }

            if index != plan.sessions.count - 1 {
                Divider()
            }
        }
        .padding(.vertical, 4)
    }

    private var dryLandSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dry Land Training")
                .font(.headline)
                .foregroundStyle(PoolTheme.mid)

            if let dryLand = plan.dryLandTraining, !dryLand.isEmpty {
                ForEach(dryLand.indices, id: \.self) { index in
                    if isEditing {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                TextField("Exercise", text: Binding(
                                    get: { plan.dryLandTraining?[index].name ?? "" },
                                    set: { plan.dryLandTraining?[index].name = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .submitLabel(.done)
                                TextField("Duration", text: Binding(
                                    get: { plan.dryLandTraining?[index].duration ?? "" },
                                    set: { plan.dryLandTraining?[index].duration = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .submitLabel(.done)
                            }
                            TextField("Purpose", text: Binding(
                                get: { plan.dryLandTraining?[index].purpose ?? "" },
                                set: { plan.dryLandTraining?[index].purpose = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.done)

                            Button("Remove", systemImage: "trash") {
                                plan.dryLandTraining?.remove(at: index)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        }
                    } else {
                        HStack(spacing: 12) {
                            Text(dryLand[index].name)
                                .font(.subheadline.bold())
                                .foregroundStyle(PoolTheme.deep)

                            Text(dryLand[index].duration)
                                .font(.caption)
                                .foregroundStyle(PoolTheme.smoke)

                            Text("•")
                                .foregroundStyle(PoolTheme.light)

                            Text(dryLand[index].purpose)
                                .font(.caption)
                                .foregroundStyle(PoolTheme.mid)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if isEditing {
                Button("Add Exercise", systemImage: "plus") {
                    if plan.dryLandTraining == nil {
                        plan.dryLandTraining = []
                    }
                    plan.dryLandTraining?.append(DryLandExercise(
                        name: "",
                        duration: "",
                        purpose: ""
                    ))
                }
                .buttonStyle(.bordered)
                .tint(PoolTheme.mid)
            } else if plan.dryLandTraining?.isEmpty ?? true {
                Text("No dry land training planned")
                    .font(.subheadline)
                    .foregroundStyle(PoolTheme.smoke)
            }
        }
        .poolCard()
    }

    private var remarksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Remarks")
                .font(.headline)
                .foregroundStyle(PoolTheme.mid)

            if isEditing {
                TextField("Remarks", text: $plan.remarks, axis: .vertical)
                    .lineLimit(2...6)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
            } else {
                Text(plan.remarks.isEmpty ? "No remarks." : plan.remarks)
                    .font(.body)
                    .foregroundStyle(PoolTheme.deep)
            }
        }
        .poolCard()
    }

    private var llmActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI Modifications")
                .font(.headline)
                .foregroundStyle(PoolTheme.deep)

            VStack(alignment: .leading, spacing: 12) {
                // Add Drill
                modificationRow(
                    title: "Add Drill",
                    icon: "plus.circle",
                    description: "Add one more training session to the plan",
                    action: { await modifyPlan(action: "addDrill") }
                )

                // Increase Intensity
                modificationRow(
                    title: "More Intensity",
                    icon: "arrow.up.circle",
                    description: "More reps, faster pace, shorter rest intervals",
                    action: { await modifyPlan(action: "increaseIntensity") },
                    tint: .orange
                )

                // Lower Intensity
                modificationRow(
                    title: "Less Intensity",
                    icon: "arrow.down.circle",
                    description: "Fewer reps, slower pace, longer rest intervals",
                    action: { await modifyPlan(action: "lowerIntensity") },
                    tint: .blue
                )

                // Add Dry Land
                modificationRow(
                    title: "Add Dry Land",
                    icon: "figure.strengthtraining.traditional",
                    description: "Add dry land training exercises",
                    action: { await modifyPlan(action: "addDryLand") }
                )

                Divider()

                // Refresh Plan
                HStack {
                    Button {
                        Task { await refreshPlan() }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh Plan")
                                .font(.subheadline.bold())
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isModifying)

                    Spacer()

                    Text("Generate a completely new plan")
                        .font(.caption)
                        .foregroundStyle(PoolTheme.smoke)
                }
            }

            if isModifying {
                HStack {
                    ProgressView()
                    Text("Modifying...")
                        .foregroundStyle(PoolTheme.smoke)
                }
            }

            if let error = modifyError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .poolCard()
    }

    private func modificationRow(
        title: String,
        icon: String,
        description: String,
        action: @escaping () async -> Void,
        tint: Color = PoolTheme.mid
    ) -> some View {
        HStack {
            Button {
                Task { await action() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                    Text(title)
                        .font(.subheadline.bold())
                }
            }
            .buttonStyle(.bordered)
            .tint(tint)
            .disabled(isModifying)

            Spacer()

            Text(description)
                .font(.caption)
                .foregroundStyle(PoolTheme.smoke)
        }
    }

    private func savePlan() {
        // Update in appModel
        if let index = appModel.trainingPlans.firstIndex(where: { $0.id == plan.id }) {
            appModel.trainingPlans[index] = plan
        } else {
            appModel.trainingPlans.append(plan)
        }
        isEditing = false
    }

    private func modifyPlan(action: String) async {
        guard let config = appModel.llmConfiguration else {
            modifyError = "Configure LLM in Settings first"
            return
        }

        guard let apiKey = try? credentialStore.load(account: config.apiKeyReference) else {
            modifyError = "API key not found"
            return
        }

        isModifying = true
        modifyError = nil

        let currentPlanJSON = encodePlanJSON()
        let actionDescription: String
        switch action {
        case "addDrill": actionDescription = "Add one more training drill/session to the plan"
        case "increaseIntensity": actionDescription = "Increase the intensity of the training sessions (more reps, faster pace, shorter rest)"
        case "lowerIntensity": actionDescription = "Lower the intensity of the training sessions (fewer reps, slower pace, longer rest)"
        case "addDryLand": actionDescription = "Add dry land training exercises"
        default: actionDescription = action
        }

        let request = LLMRequest(
            systemRole: "expert_swimming_coach",
            prompt: """
            Current training plan:
            \(currentPlanJSON)

            User request: \(actionDescription)

            Return the modified training plan as JSON in the exact same format. Only change what's requested, keep everything else the same.
            """,
            temperature: 0.3
        )

        do {
            let response = try await llmClient.complete(request, configuration: config, apiKey: apiKey)
            if let newPlan = parsePlanFromLLM(response, date: plan.date, userId: plan.userId) {
                plan = newPlan
                savePlan()
            } else {
                modifyError = "Could not parse LLM response"
            }
        } catch {
            modifyError = "Failed: \(error.localizedDescription)"
        }

        isModifying = false
    }

    private func refreshPlan() async {
        guard let config = appModel.llmConfiguration else {
            modifyError = "Configure LLM in Settings first"
            return
        }

        guard let apiKey = try? credentialStore.load(account: config.apiKeyReference) else {
            modifyError = "API key not found"
            return
        }

        isModifying = true
        modifyError = nil

        let profileContext = buildProfileContext()
        let request = LLMRequest(
            systemRole: "expert_swimming_coach",
            prompt: """
            \(profileContext)

            Generate a training plan for \(plan.date) as JSON with this structure:
            {
              "overview": "Brief description of the day's focus",
              "sessions": [
                {"sessionNumber": 1, "focus": "Focus area", "details": "Specific workout", "goals": "Target outcome"}
              ],
              "dryLandTraining": [
                {"name": "Exercise name", "duration": "Duration", "purpose": "Purpose"}
              ],
              "remarks": "Additional notes"
            }

            Create 3-4 varied sessions. Include dry land training appropriate for the swimmer level.
            """,
            temperature: 0.7
        )

        do {
            let response = try await llmClient.complete(request, configuration: config, apiKey: apiKey)
            if let newPlan = parsePlanFromLLM(response, date: plan.date, userId: plan.userId) {
                plan = newPlan
                savePlan()
            } else {
                modifyError = "Could not parse LLM response"
            }
        } catch {
            modifyError = "Failed: \(error.localizedDescription)"
        }

        isModifying = false
    }

    private func encodePlanJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(plan),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private func buildProfileContext() -> String {
        guard let profile = appModel.activeProfile else { return "" }
        let strokes = profile.preferredStrokes.map { $0.rawValue.capitalized }.joined(separator: ", ")
        return """
        Swimmer profile:
        - Name: \(profile.name)
        - Level: \(profile.skillLevel.rawValue.capitalized)
        - Weekly sessions: \(profile.weeklySessionTarget)
        - Preferred strokes: \(strokes)
        """
    }

    private func parsePlanFromLLM(_ response: String, date: String, userId: String) -> TrainingPlan? {
        // Extract JSON from response (handle markdown code blocks)
        var jsonString = response
        if jsonString.contains("```json") {
            jsonString = jsonString
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
        } else if jsonString.contains("```") {
            jsonString = jsonString
                .replacingOccurrences(of: "```", with: "")
        }

        jsonString = jsonString.trimmingCharacters(in: .whitespaces)

        guard let data = jsonString.data(using: .utf8) else { return nil }

        // Decode into a partial structure
        struct PartialPlan: Codable {
            var overview: String
            var sessions: [PartialSession]
            var dryLandTraining: [PartialDryLand]?
            var remarks: String
        }

        struct PartialSession: Codable {
            var sessionNumber: Int
            var focus: String
            var details: String
            var goals: String
        }

        struct PartialDryLand: Codable {
            var name: String
            var duration: String
            var purpose: String
        }

        guard let partial = try? JSONDecoder().decode(PartialPlan.self, from: data) else { return nil }

        let sessions = partial.sessions.map { s in
            TrainingSession(sessionNumber: s.sessionNumber, focus: s.focus, details: s.details, goals: s.goals)
        }

        let dryLand = partial.dryLandTraining?.map { d in
            DryLandExercise(name: d.name, duration: d.duration, purpose: d.purpose)
        }

        return TrainingPlan(
            id: plan.id,
            userId: userId,
            date: date,
            overview: partial.overview,
            sessions: sessions,
            dryLandTraining: dryLand,
            remarks: partial.remarks,
            createdAt: plan.createdAt,
            updatedAt: SwimNoteDateFormatting.string(from: Date())
        )
    }
}

// MARK: - Convenience init for preview/legacy usage

extension TrainingPlanView {
    init(plan: TrainingPlan) {
        self.init(appModel: SwimNoteAppModel.bootstrap(), plan: plan)
    }
}

// MARK: - Previews

#Preview("Training Plan Card") {
    let plan = TrainingPlan(
        userId: "user-1",
        date: "2024-04-28",
        overview: "Focus on freestyle technique and endurance building.",
        sessions: [
            TrainingSession(sessionNumber: 1, focus: "Freestyle Technique", details: "4x100m high elbow catch", goals: "Reduce stroke count"),
            TrainingSession(sessionNumber: 2, focus: "Endurance", details: "8x200m moderate pace", goals: "Complete under 30 min"),
            TrainingSession(sessionNumber: 3, focus: "Sprint", details: "10x50m all-out", goals: "Hit target pace")
        ],
        dryLandTraining: [
            DryLandExercise(name: "Core plank", duration: "3x30s", purpose: "Stability"),
            DryLandExercise(name: "Stretching", duration: "10 min", purpose: "Recovery")
        ],
        remarks: "Stay hydrated. Focus on recovery between sprint sets."
    )

    TrainingPlanCard(plan: plan, onTap: {})
        .padding()
        .background(PoolTheme.surface)
}

#Preview("Training Plan View") {
    let plan = TrainingPlan(
        userId: "user-1",
        date: "2024-04-28",
        overview: "Today's training focuses on improving freestyle technique with emphasis on high elbow catch.",
        sessions: [
            TrainingSession(sessionNumber: 1, focus: "Freestyle Technique", details: "4x100m focusing on high elbow catch", goals: "Reduce stroke count by 2"),
            TrainingSession(sessionNumber: 2, focus: "Endurance", details: "8x200m at moderate pace", goals: "Complete under 30 min"),
            TrainingSession(sessionNumber: 3, focus: "Sprint Intervals", details: "10x50m all-out with 30s rest", goals: "Maintain sprint pace")
        ],
        dryLandTraining: [
            DryLandExercise(name: "Core plank", duration: "3x30 seconds", purpose: "Stability"),
            DryLandExercise(name: "Stretching", duration: "10 minutes", purpose: "Recovery")
        ],
        remarks: "Stay hydrated throughout."
    )

    NavigationStack {
        TrainingPlanView(plan: plan)
    }
}