import SwiftUI
import AVKit
import UniformTypeIdentifiers
import SwimNoteCore

struct VideoToolsView: View {
    @Bindable var appModel: SwimNoteAppModel
    @State private var selectedVideoURL: URL?
    @State private var player: AVPlayer?
    @State private var isImporterPresented = false

    var body: some View {
        NavigationStack {
            List {
                Section("Video Review") {
                    if let player {
                        VideoPlayer(player: player)
                            .frame(minHeight: 240)
                    } else {
                        ContentUnavailableView("Import a Video", systemImage: "video.badge.plus", description: Text("Use Photos or Files in the app target to analyze swim footage."))
                    }
                }

                Section("Saved Analysis") {
                    if appModel.videoRecords.isEmpty {
                        Text("No analysis records yet.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(appModel.videoRecords) { record in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.videoFilename)
                                .font(.headline)
                            Text("Kick rate: \(record.metrics.kickRatePerMinute, specifier: "%.1f") / min")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Video Tools")
            .toolbar {
                Button("Import Video") {
                    isImporterPresented = true
                }
                Button("Demo Analysis") {
                    addDemoAnalysis()
                }
            }
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: [.movie, .video],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    selectedVideoURL = url
                    player = AVPlayer(url: url)
                    addImportedVideoRecord(url)
                }
            }
        }
    }

    private func addImportedVideoRecord(_ url: URL) {
        let record = NativeVideoAnalysisService().makeRecord(
            videoURL: url,
            strokeId: .freestyle,
            frames: []
        )
        appModel.videoRecords.insert(record, at: 0)
    }

    private func addDemoAnalysis() {
        let frame = PoseFrame(
            timestamp: 0,
            landmarks: Array(repeating: PoseLandmark(x: 0.5, y: 0.5, z: 0, visibility: 1), count: PoseLandmarkIndex.count)
        )
        let record = NativeVideoAnalysisService().makeRecord(
            videoURL: URL(fileURLWithPath: "sample.mov"),
            strokeId: .freestyle,
            frames: [frame]
        )
        appModel.videoRecords.insert(record, at: 0)
    }
}
