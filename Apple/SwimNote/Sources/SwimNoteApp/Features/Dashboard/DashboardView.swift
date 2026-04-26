import SwiftUI
import SwimNoteCore

struct DashboardView: View {
    @Bindable var appModel: SwimNoteAppModel
    @State private var note = TrainingNote.empty(date: "")
    @State private var isLoading = true
    @State private var saveMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    strokeGrid
                    DailyNoteEditor(note: $note, strokes: appModel.strokes, techniques: appModel.techniques) {
                        Task {
                            try? await appModel.save(note)
                            saveMessage = "Saved"
                        }
                    }
                    .poolCard()
                }
                .padding()
            }
            .background(
                LinearGradient(colors: [PoolTheme.surface, PoolTheme.light.opacity(0.5)], startPoint: .top, endPoint: .bottom)
            )
            .navigationTitle("Today's Training")
            .task {
                note = await appModel.noteForToday()
                isLoading = false
            }
            .overlay {
                if isLoading {
                    ProgressView("Loading session...")
                }
            }
            .toolbar {
                if let saveMessage {
                    Text(saveMessage)
                        .foregroundStyle(PoolTheme.mid)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TODAY'S TRAINING")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(PoolTheme.deep)
            Text(note.date.isEmpty ? "Loading" : note.date)
                .font(.headline)
                .foregroundStyle(PoolTheme.mid)
        }
    }

    private var strokeGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
            ForEach(appModel.strokes) { stroke in
                Button {
                    appModel.selectedStroke = stroke.id
                    appModel.selectedTab = .trees
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: "water.waves")
                            .font(.title2)
                        Text(stroke.name)
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .poolCard()
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct DailyNoteEditor: View {
    @Binding var note: TrainingNote
    let strokes: [Stroke]
    let techniques: [Technique]
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Today's Session")
                .font(.title3.bold())

            TextField("What happened during training?", text: $note.notes, axis: .vertical)
                .lineLimit(4...8)
                .textFieldStyle(.roundedBorder)

            GoalListEditor(goals: $note.goals)

            Button(action: addManualGoal) {
                Label("Add General Goal", systemImage: "plus.circle")
            }

            Button("Save Session", action: onSave)
                .buttonStyle(.borderedProminent)
        }
    }

    private func addManualGoal() {
        let now = ISO8601DateFormatter().string(from: Date())
        note.goals.append(
            Goal(
                id: UUID().uuidString,
                type: .general,
                description: "New training focus",
                status: .planned,
                createdAt: now,
                updatedAt: now
            )
        )
    }
}

struct GoalListEditor: View {
    @Binding var goals: [Goal]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Goals")
                .font(.headline)

            if goals.isEmpty {
                Text("No goals yet. Add one from a technique tree or create a general focus.")
                    .foregroundStyle(.secondary)
            }

            ForEach($goals) { $goal in
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Goal", text: $goal.description)
                        .textFieldStyle(.roundedBorder)
                    Picker("Status", selection: $goal.status) {
                        Text("Planned").tag(GoalStatus.planned)
                        Text("In Progress").tag(GoalStatus.inProgress)
                        Text("Achieved").tag(GoalStatus.achieved)
                        Text("Unable").tag(GoalStatus.unableToAchieve)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.vertical, 6)
            }
        }
    }
}
