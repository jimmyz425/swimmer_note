import SwiftUI

private let tierOrder: [String] = ["Beginner", "Intermediate", "Advanced", "Elite"]

private func tierIndex(_ tier: String) -> Int {
    tierOrder.firstIndex(of: tier) ?? Int.max
}

private func sortTierNames(_ tiers: some Sequence<String>) -> [String] {
    tiers.sorted { tierIndex($0) < tierIndex($1) }
}

struct TechniqueTreeView: View {
    @Bindable var appModel: SwimNoteAppModel
    let tree: TechniqueTree

    private var sortedNodes: [TechniqueTreeNode] {
        tree.nodes.sorted { lhs, rhs in
            if lhs.level == rhs.level { return lhs.name < rhs.name }
            return lhs.level < rhs.level
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(sortedNodes) { node in
                    NavigationLink(value: NodeNavigationValue(strokeId: tree.strokeId, nodeId: node.id)) {
                        TechniqueNodeRow(
                            node: node,
                            strokeId: tree.strokeId,
                            userRevisit: appModel.activeProfile?.isRevisitNode(strokeId: tree.strokeId, nodeId: node.id) ?? false
                        )
                    }
                    .buttonStyle(.plain)
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
        .navigationTitle(tree.strokeId.rawValue.capitalized)
    }
}

struct TechniqueNodeRow: View {
    let node: TechniqueTreeNode
    let strokeId: StrokeID
    let userRevisit: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(node.name)
                    .font(.headline)
                    .foregroundStyle(PoolTheme.deep)
                Text("Level \(node.level)")
                    .font(.caption)
                    .foregroundStyle(PoolTheme.smoke)
            }
            Spacer()
            // Revisit indicator — larger and more visible
            Image(systemName: "repeat")
                .font(.system(size: 16))
                .foregroundStyle(userRevisit ? PoolTheme.gold : PoolTheme.smoke.opacity(0.4))
        }
        .poolCard()
    }
}

enum TechniqueDetailTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case keyPoints = "Key Points"
    case mistakes = "Mistakes"
    case drills = "Drills"
    case competitive = "Competitive"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .overview: "doc.text"
        case .keyPoints: "checklist"
        case .mistakes: "exclamationmark.triangle"
        case .drills: "figure.pool.swim"
        case .competitive: "trophy"
        }
    }
}

struct NodeDetailView: View {
    @Bindable var appModel: SwimNoteAppModel
    @Environment(ContentStore.self) private var contentStore
    let tree: TechniqueTree
    let node: TechniqueTreeNode
    @State private var parsedContent: ParsedTechniqueContent?
    @State private var message: String?
    @State private var messageDismissTask: Task<Void, Never>?
    @State private var selectedTierMetric: CompetitiveMetric?
    @State private var selectedTab: TechniqueDetailTab = .overview

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Revisit banner - always visible, prominent card-style treatment
                RevisitBanner(node: node, strokeId: tree.strokeId, appModel: appModel)

                TechniqueTabPicker(selectedTab: $selectedTab)

                if let content = parsedContent {
                    TechniqueTabContent(
                        content: content,
                        selectedTab: selectedTab,
                        tree: tree,
                        onSelectTierMetric: { metric in
                            selectedTierMetric = metric
                        },
                        onAddKeyPoint: { point in
                            Task { await addKeyPointGoal(point) }
                        },
                        onAddMistake: { mistake in
                            Task { await addMistakeGoal(mistake) }
                        }
                    )
                } else if node.sourceFile != nil {
                    ProgressView("Loading content...")
                        .padding()
                } else {
                    Text("No detailed content available for this technique.")
                        .foregroundStyle(PoolTheme.smoke)
                        .poolCard()
                        .padding()
                }

                if let message {
                    Text(message)
                        .foregroundStyle(PoolTheme.deep)
                        .padding()
                }
            }
        }
        .background(
            LinearGradient(
                colors: [PoolTheme.surface, PoolTheme.light.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .navigationTitle(node.name)
        .task {
            if let sourceFile = node.sourceFile {
                parsedContent = contentStore.parsedTechnique(filename: sourceFile)
            }
        }
        .sheet(item: $selectedTierMetric) { metric in
            TierSelectionSheet(
                metric: metric,
                strokeId: tree.strokeId,
                techniqueNodeId: node.id,
                onAdd: { tier in
                    await addCompetitiveMetricGoal(metric, tier: tier)
                    selectedTierMetric = nil
                }
            )
        }
    }

    @MainActor
    private func showMessage(_ text: String) {
        messageDismissTask?.cancel()
        message = text
        messageDismissTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            message = nil
        }
    }

    @MainActor
    private func addKeyPointGoal(_ keyPoint: String) async {
        guard var note = await appModel.noteForToday() else {
            showMessage("No active profile")
            return
        }
        let description = keyPoint
        if note.goals.contains(where: { $0.description == description && $0.techniqueNodeId == node.id }) {
            showMessage("Already added this key point")
            return
        }
        note.goals.append(Goal.fromKeyPoint(
            keyPoint: keyPoint,
            techniqueNodeId: node.id,
            strokeId: tree.strokeId
        ))
        await appModel.saveNote(note)
        showMessage("Added \(tree.name) - \(node.name) key point")
    }

    @MainActor
    private func addMistakeGoal(_ mistake: String) async {
        guard var note = await appModel.noteForToday() else {
            showMessage("No active profile")
            return
        }
        let description = "Avoid: \(mistake)"
        if note.goals.contains(where: { $0.description == description && $0.techniqueNodeId == node.id }) {
            showMessage("Already added this mistake")
            return
        }
        note.goals.append(Goal.fromMistake(
            mistake: mistake,
            techniqueNodeId: node.id,
            strokeId: tree.strokeId
        ))
        await appModel.saveNote(note)
        showMessage("Added \(tree.name) - \(node.name) mistake avoidance")
    }

    @MainActor
    private func addCompetitiveMetricGoal(_ metric: CompetitiveMetric, tier: String) async {
        guard var note = await appModel.noteForToday() else {
            showMessage("No active profile")
            return
        }
        // Check if this metric was already added
        if note.goals.contains(where: { $0.description.hasPrefix(metric.name) && $0.techniqueNodeId == node.id }) {
            showMessage("Already added this metric")
            return
        }
        note.goals.append(Goal.fromCompetitiveMetric(
            metric: metric,
            selectedTier: tier,
            techniqueNodeId: node.id,
            strokeId: tree.strokeId
        ))
        await appModel.saveNote(note)
        showMessage("Added \(tree.name) - \(node.name) competitive metric")
    }
}

struct TechniqueTabPicker: View {
    @Binding var selectedTab: TechniqueDetailTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TechniqueDetailTab.allCases) { tab in
                TabButton(tab: tab, isSelected: selectedTab == tab, onSelect: {
                    selectedTab = tab
                })
            }
        }
        .background(PoolTheme.surface)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(PoolTheme.light),
            alignment: .bottom
        )
    }
}

struct TabButton: View {
    let tab: TechniqueDetailTab
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: PoolTheme.fontSizeSubheadline))
                Text(tab.rawValue)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(isSelected ? PoolTheme.mid : PoolTheme.deep.opacity(0.6))
            .background(isSelected ? PoolTheme.mid.opacity(0.15) : Color.clear)
            .contentShape(Rectangle())
            .overlay(
                Rectangle()
                    .frame(height: 2)
                    .foregroundStyle(isSelected ? PoolTheme.mid : Color.clear),
                alignment: .bottom
            )
        }
        .buttonStyle(.plain)
    }
}

struct RevisitBanner: View {
    let node: TechniqueTreeNode
    let strokeId: StrokeID
    @Bindable var appModel: SwimNoteAppModel
    @State private var message: String?

    private var userRevisit: Bool {
        appModel.activeProfile?.isRevisitNode(strokeId: strokeId, nodeId: node.id) ?? false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(userRevisit ? PoolTheme.gold : PoolTheme.mid)

                VStack(alignment: .leading, spacing: 2) {
                    Text(userRevisit ? "Revisit Focus" : "Mark for Revisit")
                        .font(.subheadline.bold())
                        .foregroundStyle(userRevisit ? PoolTheme.gold : PoolTheme.deep)

                    Text(userRevisit
                         ? "You'll see this technique in your fundamentals review sessions."
                         : "Tag this technique to practice regularly as a fundamental.")
                        .font(.caption)
                        .foregroundStyle(PoolTheme.smoke)
                        .lineLimit(2)
                }

                Spacer()

                Button {
                    toggleRevisit()
                } label: {
                    Image(systemName: userRevisit ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(userRevisit ? PoolTheme.gold : PoolTheme.mid)
                }
                .buttonStyle(.plain)
            }

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(PoolTheme.mid)
                    .transition(.opacity)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(userRevisit ? PoolTheme.gold.opacity(0.1) : PoolTheme.mid.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(userRevisit ? PoolTheme.gold.opacity(0.3) : PoolTheme.mid.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal)
        .padding(.top, 8)
    }

    @MainActor
    private func toggleRevisit() {
        guard let profile = appModel.activeProfile else {
            showMessage("No active profile")
            return
        }
        let updated = profile.togglingRevisit(strokeId: strokeId, nodeId: node.id)
        Task {
            try? await appModel.updateProfile(updated)
            showMessage(userRevisit ? "Removed from revisit" : "Marked for revisit")
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            withAnimation { message = nil }
        }
    }

    @MainActor
    private func showMessage(_ text: String) {
        withAnimation { message = text }
    }
}

struct TechniqueTabContent: View {
    let content: ParsedTechniqueContent
    let selectedTab: TechniqueDetailTab
    let tree: TechniqueTree
    let onSelectTierMetric: (CompetitiveMetric) -> Void
    let onAddKeyPoint: (String) -> Void
    let onAddMistake: (String) -> Void

    var body: some View {
        switch selectedTab {
        case .overview:
            OverviewContent(content: content, tree: tree)
        case .keyPoints:
            KeyPointsContent(content: content, onAdd: onAddKeyPoint)
        case .mistakes:
            MistakesContent(content: content, onAdd: onAddMistake)
        case .drills:
            DrillsContent(content: content)
        case .competitive:
            CompetitiveContent(content: content, onSelectMetric: onSelectTierMetric)
        }
    }
}

struct OverviewContent: View {
    let content: ParsedTechniqueContent
    let tree: TechniqueTree

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !content.overview.isEmpty {
                Text(content.overview)
                    .font(.body)
                    .foregroundStyle(PoolTheme.deep)
            }

            if !content.difficulty.isEmpty {
                DifficultyBadge(difficulty: content.difficulty)
            }

            if !content.relatedTechniques.isEmpty {
                RelatedTechniquesList(techniques: content.relatedTechniques, tree: tree)
            }
        }
        .poolCard()
    }
}

struct DifficultyBadge: View {
    let difficulty: String

    private var color: Color {
        let lower = difficulty.lowercased()
        if lower.contains("easiest") || lower.contains("foundation") {
            return .green
        } else if lower.contains("moderate") {
            return .orange
        } else if lower.contains("hard") || lower.contains("difficult") {
            return .red
        }
        return PoolTheme.mid
    }

    var body: some View {
        Label("Difficulty: \(difficulty)", systemImage: "star.leadinghalf.filled")
            .foregroundStyle(color)
    }
}

struct RelatedTechniquesList: View {
    let techniques: [String]
    let tree: TechniqueTree

    private var nodeLookup: [String: TechniqueTreeNode] {
        Dictionary(uniqueKeysWithValues: tree.nodes.compactMap { node in
            (node.name.lowercased(), node)
        })
    }

    private func findNode(named techniqueName: String) -> TechniqueTreeNode? {
        nodeLookup[techniqueName.lowercased()]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Related Techniques")
                .font(.headline)
                .foregroundStyle(PoolTheme.deep)
            ForEach(techniques, id: \.self) { technique in
                if let relatedNode = findNode(named: technique) {
                    NavigationLink(value: NodeNavigationValue(strokeId: tree.strokeId, nodeId: relatedNode.id)) {
                        Text(technique)
                            .font(.subheadline)
                            .foregroundStyle(PoolTheme.mid)
                    }
                } else {
                    Text(technique)
                        .font(.subheadline)
                        .foregroundStyle(PoolTheme.smoke)
                }
            }
        }
    }
}

struct KeyPointsContent: View {
    let content: ParsedTechniqueContent
    let onAdd: (String) -> Void

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            if content.keyPoints.isEmpty {
                Text("No key points available")
                    .foregroundStyle(PoolTheme.smoke)
            } else {
                ForEach(content.keyPoints, id: \.self) { point in
                    KeyPointRow(point: point, onAdd: { onAdd(point) })
                }
            }
        }
        .poolCard()
    }
}

struct KeyPointRow: View {
    let point: String
    let onAdd: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(point)
                .font(.body)
                .foregroundStyle(PoolTheme.deep)
            Spacer()
            Button(action: onAdd) {
                Image(systemName: "plus.circle")
                    .foregroundStyle(PoolTheme.mid)
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 8)
        Divider()
    }
}

struct MistakesContent: View {
    let content: ParsedTechniqueContent
    let onAdd: (String) -> Void

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            if content.commonMistakes.isEmpty {
                Text("No common mistakes listed")
                    .foregroundStyle(PoolTheme.smoke)
            } else {
                ForEach(content.commonMistakes, id: \.self) { mistake in
                    MistakeRow(mistake: mistake, onAdd: { onAdd(mistake) })
                }
            }
        }
        .poolCard()
    }
}

struct MistakeRow: View {
    let mistake: String
    let onAdd: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
            Text(mistake)
                .font(.body)
                .foregroundStyle(PoolTheme.deep)
            Spacer()
            Button(action: onAdd) {
                Image(systemName: "plus.circle")
                    .foregroundStyle(PoolTheme.mid)
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 8)
        Divider()
    }
}

struct DrillsContent: View {
    let content: ParsedTechniqueContent

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            if content.specificDrills.isEmpty {
                Text("No drills available")
                    .foregroundStyle(PoolTheme.smoke)
            } else {
                ForEach(content.specificDrills, id: \.name) { drill in
                    DrillRow(drill: drill)
                }
            }
        }
        .poolCard()
    }
}

struct DrillRow: View {
    let drill: SpecificDrill

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(drill.name)
                .font(.headline)
                .foregroundStyle(PoolTheme.deep)
            Text(drill.description)
                .font(.body)
                .foregroundStyle(PoolTheme.smoke)
        }
        .padding(.vertical, 8)
        Divider()
    }
}

struct CompetitiveContent: View {
    let content: ParsedTechniqueContent
    let onSelectMetric: (CompetitiveMetric) -> Void

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            if content.competitiveMetrics.isEmpty {
                Text("No competitive metrics available")
                    .foregroundStyle(PoolTheme.smoke)
            } else {
                ForEach(content.competitiveMetrics, id: \.id) { metric in
                    CompetitiveMetricRow(metric: metric, onSelect: { onSelectMetric(metric) })
                }
            }
        }
        .poolCard()
    }
}

struct CompetitiveMetricRow: View {
    let metric: CompetitiveMetric
    let onSelect: () -> Void

    private var sortedTiers: [(String, String)] {
        sortTierNames(metric.tieredTargets.keys).compactMap { tier in
            metric.tieredTargets[tier].map { (tier, $0) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(metric.name)
                .font(.headline)
                .foregroundStyle(PoolTheme.deep)

            Text("Self-Check: \(metric.selfCheck)")
                .font(.subheadline)
                .foregroundStyle(PoolTheme.smoke)

            if !metric.tieredTargetsTitle.isEmpty {
                Text(metric.tieredTargetsTitle)
                    .font(.subheadline.bold())
                    .foregroundStyle(PoolTheme.mid)
            }

            if !sortedTiers.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(sortedTiers, id: \.0) { tier, target in
                        HStack {
                            Text("\(tier):")
                                .bold()
                                .foregroundStyle(PoolTheme.mid)
                            Text(target)
                                .foregroundStyle(PoolTheme.deep)
                        }
                        .font(.caption)
                    }
                }
            }

            if !metric.competitiveImpact.isEmpty {
                Text("Impact: \(metric.competitiveImpact)")
                    .font(.caption)
                    .foregroundStyle(PoolTheme.smoke)
            }

            Button("Add Competitive Metric", action: onSelect)
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
        Divider()
    }
}

struct TierSelectionSheet: View {
    let metric: CompetitiveMetric
    let strokeId: StrokeID
    let techniqueNodeId: String
    let onAdd: (String) async -> Void

    @State private var selectedTier: String
    @Environment(\.dismiss) private var dismiss

    private let availableTiers: [String]

    init(metric: CompetitiveMetric, strokeId: StrokeID, techniqueNodeId: String, onAdd: @escaping (String) async -> Void) {
        self.metric = metric
        self.strokeId = strokeId
        self.techniqueNodeId = techniqueNodeId
        self.onAdd = onAdd
        let tiers = sortTierNames(metric.tieredTargets.keys)
        self.availableTiers = tiers
        _selectedTier = State(initialValue: tiers.first ?? "Beginner")
    }

    var body: some View {
        NavigationStack {
            Form {
                if !metric.tieredTargetsTitle.isEmpty {
                    Section {
                        Text(metric.tieredTargetsTitle)
                            .font(.headline)
                            .foregroundStyle(PoolTheme.mid)
                    }
                }

                Section("Select Target Tier") {
                    ForEach(availableTiers, id: \.self) { tier in
                        TierRow(
                            tier: tier,
                            target: metric.tieredTargets[tier] ?? "",
                            isSelected: selectedTier == tier,
                            onSelect: { selectedTier = tier }
                        )
                    }
                }

                Section("Selected Target") {
                    Text(metric.tieredTargets[selectedTier] ?? "")
                        .font(.body.bold())
                }

                Section("Metric Info") {
                    Text(metric.selfCheck)
                        .foregroundStyle(PoolTheme.deep)
                    Text(metric.competitiveImpact)
                        .foregroundStyle(PoolTheme.smoke)
                }
            }
            .navigationTitle(metric.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add Metric") {
                        Task {
                            await onAdd(selectedTier)
                            dismiss()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}

struct TierRow: View {
    let tier: String
    let target: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Text(tier)
                    .foregroundStyle(PoolTheme.deep)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(PoolTheme.mid)
                }
                Text(target)
                    .foregroundStyle(PoolTheme.smoke)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview("Technique Detail") {
    let model = SwimNoteAppModel.bootstrap()
    return NodeDetailView(
        appModel: model,
        tree: TechniqueTree(
            strokeId: .freestyle,
            name: "Freestyle",
            generatedAt: "2024-01-01",
            customized: false,
            nodes: [
                TechniqueTreeNode(
                    id: "node1",
                    techniqueId: "body_position",
                    level: 1,
                    name: "Body Position",
                    description: "Foundation for freestyle",
                    revisit: true,
                    metrics: nil,
                    prerequisites: [],
                    children: [],
                    sourceFile: "freestyle-01-body-position"
                )
            ],
            rootNodes: ["node1"]
        ),
        node: TechniqueTreeNode(
            id: "node1",
            techniqueId: "body_position",
            level: 1,
            name: "Body Position",
            description: "Foundation for freestyle",
            revisit: true,
            metrics: nil,
            prerequisites: [],
            children: [],
            sourceFile: "freestyle-01-body-position"
        )
    )
    .environment(model.contentStore)
}

// MARK: - Additional Previews

#Preview("Technique Tree") {
    TechniqueTreeView(
        appModel: SwimNoteAppModel.bootstrap(),
        tree: TechniqueTree(
            strokeId: .freestyle,
            name: "Freestyle",
            generatedAt: "2024-01-01",
            customized: false,
            nodes: [
                TechniqueTreeNode(id: "n1", techniqueId: "body_position", level: 1, name: "Body Position", description: "Foundation", revisit: true, metrics: nil, prerequisites: [], children: ["n2"], sourceFile: nil),
                TechniqueTreeNode(id: "n2", techniqueId: "catch", level: 2, name: "High Elbow Catch", description: "Propulsion", revisit: false, metrics: nil, prerequisites: ["n1"], children: [], sourceFile: nil),
                TechniqueTreeNode(id: "n3", techniqueId: "kick", level: 1, name: "Flutter Kick", description: "Rhythm", revisit: false, metrics: nil, prerequisites: [], children: [], sourceFile: nil)
            ],
            rootNodes: ["n1", "n3"]
        )
    )
}

#Preview("Technique Node Row") {
    VStack(spacing: 12) {
        TechniqueNodeRow(
            node: TechniqueTreeNode(id: "n1", techniqueId: "body_position", level: 1, name: "Body Position", description: "Foundation", revisit: true, metrics: nil, prerequisites: [], children: [], sourceFile: nil),
            strokeId: .freestyle,
            userRevisit: false
        )
        TechniqueNodeRow(
            node: TechniqueTreeNode(id: "n2", techniqueId: "catch", level: 2, name: "High Elbow Catch", description: "Propulsion", revisit: false, metrics: nil, prerequisites: [], children: [], sourceFile: nil),
            strokeId: .freestyle,
            userRevisit: true
        )
    }
    .padding()
    .background(PoolTheme.surface)
}

#Preview("Tab Picker") {
    TechniqueTabPicker(selectedTab: Binding.constant(.overview))
        .padding()
        .background(PoolTheme.surface)
}

#Preview("Key Points Content") {
    KeyPointsContent(
        content: ParsedTechniqueContent(
            filename: "test",
            title: "Body Position",
            overview: "",
            difficulty: "Foundation",
            keyPoints: ["Keep head neutral", "Core engaged", "Straight spine alignment"],
            commonMistakes: [],
            specificDrills: [],
            competitiveMetrics: [],
            relatedTechniques: [],
            techniqueTable: [],
            rawContent: ""
        ),
        onAdd: { _ in }
    )
}

#Preview("Mistakes Content") {
    MistakesContent(
        content: ParsedTechniqueContent(
            filename: "test",
            title: "Body Position",
            overview: "",
            difficulty: "",
            keyPoints: [],
            commonMistakes: ["Head too high", "Sinking hips", "Over-rotation"],
            specificDrills: [],
            competitiveMetrics: [],
            relatedTechniques: [],
            techniqueTable: [],
            rawContent: ""
        ),
        onAdd: { _ in }
    )
}

#Preview("Competitive Metric Row") {
    CompetitiveMetricRow(
        metric: CompetitiveMetric(
            name: "Distance Per Stroke",
            selfCheck: "Count strokes per lap",
            tieredTargetsTitle: "Stroke Count Efficiency",
            tieredTargets: ["Beginner": "12 strokes", "Intermediate": "10 strokes", "Elite": "8 strokes"],
            videoChecks: [],
            competitiveImpact: "Improves efficiency"
        ),
        onSelect: {}
    )
    .padding()
    .background(PoolTheme.surface)
}