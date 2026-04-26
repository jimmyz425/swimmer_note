import SwiftUI
import SwimNoteCore

struct HistoryView: View {
    @Bindable var appModel: SwimNoteAppModel

    var body: some View {
        NavigationStack {
            List(appModel.notes, id: \.date) { note in
                NavigationLink {
                    NoteDetailView(note: note)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.date)
                            .font(.headline)
                        Text(note.notes.isEmpty ? "\(note.goals.count) goals" : note.notes)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            .overlay {
                if appModel.notes.isEmpty {
                    ContentUnavailableView("No Notes", systemImage: "calendar.badge.exclamationmark", description: Text("Saved sessions will appear here."))
                }
            }
            .navigationTitle("History")
            .task {
                await appModel.reloadNotes()
            }
        }
    }
}

struct NoteDetailView: View {
    let note: TrainingNote

    var body: some View {
        List {
            Section("Session Notes") {
                Text(note.notes.isEmpty ? "No written notes." : note.notes)
            }

            Section("Goals") {
                ForEach(note.goals) { goal in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(goal.description)
                        Text(goal.status.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(note.date)
    }
}
