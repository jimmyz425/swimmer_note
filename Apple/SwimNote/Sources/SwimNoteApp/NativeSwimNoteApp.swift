import SwiftUI
import SwimNoteCore

@main
struct NativeSwimNoteApp: App {
    @State private var appModel = SwimNoteAppModel.bootstrap()

    var body: some Scene {
        WindowGroup {
            RootView(appModel: appModel)
        }
        #if os(macOS)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Training Note") {
                    appModel.openToday()
                }
                .keyboardShortcut("n")
            }
        }
        #endif
    }
}

@Observable
@MainActor
final class SwimNoteAppModel {
    var strokes: [Stroke] = []
    var techniques: [Technique] = []
    var notes: [TrainingNote] = []
    var selectedTab: AppTab = .dashboard
    var selectedStroke: StrokeID?
    var selectedNoteDate: String?
    var llmConfiguration: LLMConfiguration?
    var videoRecords: [VideoAnalysisRecord] = []

    private let noteRepository: any TrainingNoteRepository
    private let contentLoader: BundleContentLoader
    private let llmConfigurationStore = LLMConfigurationStore()

    init(noteRepository: any TrainingNoteRepository, contentLoader: BundleContentLoader) {
        self.noteRepository = noteRepository
        self.contentLoader = contentLoader
    }

    static func bootstrap() -> SwimNoteAppModel {
        let loader = BundleContentLoader.bundled()
        let notesDirectory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("SwimNote/notes", isDirectory: true)
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("SwimNote/notes", isDirectory: true)
        let model = SwimNoteAppModel(
            noteRepository: JSONTrainingNoteRepository(notesDirectory: notesDirectory),
            contentLoader: loader
        )
        model.loadBundledContent()
        model.llmConfiguration = model.llmConfigurationStore.load()
        return model
    }

    func loadBundledContent() {
        strokes = (try? contentLoader.loadStrokes()) ?? StrokeID.allCases
            .filter { $0 != .master && $0 != .im }
            .map { Stroke(id: $0, name: $0.rawValue.capitalized, aliases: []) }
        techniques = (try? contentLoader.loadTechniques()) ?? []
    }

    @MainActor
    func reloadNotes() async {
        notes = await noteRepository.listNotes()
    }

    func openToday() {
        selectedTab = .dashboard
        selectedNoteDate = Self.todayString()
    }

    func noteForToday() async -> TrainingNote {
        let today = Self.todayString()
        if let note = await noteRepository.note(for: today) {
            return note
        }
        return .empty(date: today)
    }

    @MainActor
    func save(_ note: TrainingNote) async throws {
        try await noteRepository.save(note)
        await reloadNotes()
    }

    func tree(for strokeId: StrokeID) -> TechniqueTree? {
        try? contentLoader.loadTechniqueTree(strokeId: strokeId)
    }

    func markdown(filename: String) -> String {
        (try? contentLoader.loadMarkdown(filename: filename)) ?? ""
    }

    func saveLLMConfiguration(_ configuration: LLMConfiguration) {
        llmConfiguration = configuration
        llmConfigurationStore.save(configuration)
    }

    private static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard = "Today"
    case history = "History"
    case trees = "Technique"
    case video = "Video"
    case settings = "Settings"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .dashboard: "calendar"
        case .history: "clock.arrow.circlepath"
        case .trees: "point.3.connected.trianglepath.dotted"
        case .video: "video"
        case .settings: "gearshape"
        }
    }
}
