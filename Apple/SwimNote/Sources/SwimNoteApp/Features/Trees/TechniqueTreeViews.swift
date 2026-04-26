import SwiftUI
import SwimNoteCore

struct TechniqueHomeView: View {
    @Bindable var appModel: SwimNoteAppModel

    var body: some View {
        NavigationSplitView {
            List(appModel.strokes, selection: $appModel.selectedStroke) { stroke in
                Label(stroke.name, systemImage: "water.waves")
                    .tag(stroke.id)
            }
            .navigationTitle("Strokes")
        } detail: {
            if let selectedStroke = appModel.selectedStroke,
               let tree = appModel.tree(for: selectedStroke) {
                TechniqueTreeView(appModel: appModel, tree: tree)
            } else {
                ContentUnavailableView("Choose a Stroke", systemImage: "point.3.connected.trianglepath.dotted")
            }
        }
    }
}

struct TechniqueTreeView: View {
    @Bindable var appModel: SwimNoteAppModel
    let tree: TechniqueTree
    @State private var selectedNode: TechniqueTreeNode?

    var sortedNodes: [TechniqueTreeNode] {
        tree.nodes.sorted { lhs, rhs in
            if lhs.level == rhs.level { return lhs.name < rhs.name }
            return lhs.level < rhs.level
        }
    }

    var body: some View {
        List(selection: $selectedNode) {
            ForEach(sortedNodes) { node in
                NavigationLink(value: node) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(node.name)
                            .font(.headline)
                        Text("Level \(node.level)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(tree.name)
        .navigationDestination(for: TechniqueTreeNode.self) { node in
            NodeDetailView(appModel: appModel, tree: tree, node: node)
        }
    }
}

struct NodeDetailView: View {
    @Bindable var appModel: SwimNoteAppModel
    let tree: TechniqueTree
    let node: TechniqueTreeNode
    @State private var message: String?

    var markdown: String {
        guard let sourceFile = node.sourceFile else { return "" }
        return appModel.markdown(filename: sourceFile)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(node.name)
                    .font(.largeTitle.bold())
                Text(node.description)
                    .font(.body)

                if node.revisit {
                    Label("Practice regularly", systemImage: "repeat")
                        .foregroundStyle(PoolTheme.gold)
                }

                if !markdown.isEmpty {
                    Text(markdown)
                        .font(.callout)
                        .textSelection(.enabled)
                }

                Button {
                    Task { await addGoal() }
                } label: {
                    Label("Add to Today's Goals", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)

                if let message {
                    Text(message)
                        .foregroundStyle(PoolTheme.mid)
                }
            }
            .padding()
        }
    }

    @MainActor
    private func addGoal() async {
        var note = await appModel.noteForToday()
        note.goals.append(Goal.fromTechniqueNode(node, strokeId: tree.strokeId))
        try? await appModel.save(note)
        message = "Added to today"
    }
}
