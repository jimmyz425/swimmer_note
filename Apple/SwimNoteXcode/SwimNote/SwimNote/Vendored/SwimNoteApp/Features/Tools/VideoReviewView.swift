import SwiftUI
import AVKit
import UniformTypeIdentifiers

struct VideoReviewView: View {
    @Bindable var appModel: SwimNoteAppModel
    @State private var selectedVideoURL: URL?
    @State private var player: AVPlayer?
    @State private var isImporterPresented = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection

                videoSection

                importButtonSection

                savedAnalysisSection
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
        .navigationTitle("Video Review")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isImporterPresented = true
                } label: {
                    Image(systemName: "video.badge.plus")
                }
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

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Analyze swim technique through video")
                .font(.headline)
                .foregroundStyle(PoolTheme.mid)

            Text("Import footage to review stroke mechanics, kick rate, and body position.")
                .font(.subheadline)
                .foregroundStyle(PoolTheme.smoke)
        }
    }

    private var videoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Video")
                .font(.title3.bold())

            if let player {
                VideoPlayer(player: player)
                    .frame(minHeight: 280)
                    .cornerRadius(12)
            } else {
                ContentUnavailableView(
                    "No Video Loaded",
                    systemImage: "video",
                    description: Text("Import a video to start analyzing technique.")
                )
            }
        }
        .poolCard()
    }

    private var importButtonSection: some View {
        Button {
            isImporterPresented = true
        } label: {
            HStack {
                Image(systemName: "video.badge.plus")
                Text("Import New Video")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(PoolTheme.mid)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var savedAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Saved Analysis")
                .font(.title3.bold())

            if appModel.videoRecords.isEmpty {
                ContentUnavailableView(
                    "No Saved Analysis",
                    systemImage: "folder",
                    description: Text("Imported videos will appear here with analysis metrics.")
                )
            } else {
                ForEach(appModel.videoRecords) { record in
                    HStack(spacing: 12) {
                        Image(systemName: "video.fill")
                            .font(.title2)
                            .foregroundStyle(PoolTheme.mid)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.videoFilename)
                                .font(.headline)
                                .foregroundStyle(PoolTheme.deep)

                            Text(formatDate(record.createdAt))
                                .font(.caption)
                                .foregroundStyle(PoolTheme.smoke)

                            HStack(spacing: 8) {
                                Label("\(record.metrics.kickRatePerMinute, specifier: "%.0f") kicks/min", systemImage: "figure.pool.swim")
                                Label("\(record.metrics.strokeRatePerMinute, specifier: "%.0f") strokes/min", systemImage: "hand.wave")
                            }
                            .font(.subheadline)
                            .foregroundStyle(PoolTheme.mid)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 8)

                    if record.id != appModel.videoRecords.last?.id {
                        Divider()
                    }
                }
            }
        }
        .poolCard()
    }

    private func formatDate(_ isoDate: String) -> String {
        guard let date = DateFormatter.yyyyMMdd.date(from: String(isoDate.prefix(10))) else { return isoDate }
        return DateFormatter.mediumDate.string(from: date)
    }

    private func addImportedVideoRecord(_ url: URL) {
        let record = NativeVideoAnalysisService().makeRecord(
            videoURL: url,
            strokeId: .freestyle,
            frames: []
        )
        appModel.videoRecords.insert(record, at: 0)
    }
}

#Preview("Video Review - Empty") {
    NavigationStack {
        VideoReviewView(appModel: SwimNoteAppModel.bootstrap())
    }
}

#Preview("Video Review - With Records") {
    let model = SwimNoteAppModel.bootstrap()
    model.videoRecords = [
        VideoAnalysisRecord(
            id: "record-1",
            videoFilename: "freestyle_session_01.mov",
            strokeId: .freestyle,
            createdAt: "2024-01-15T10:00:00Z",
            metrics: PoseAnalysisMetrics(
                strokeRatePerMinute: 30.0,
                strokeRateHz: 0.5,
                kickRatePerMinute: 45.0,
                kickRateHz: 0.75,
                kickRateConfidence: 0.8,
                bodyAngleAverage: 15.0,
                bodyAngleMin: 10.0,
                bodyAngleMax: 20.0,
                armEntryAngleAverage: 45.0,
                elbowHeightAverage: 0.8
            ),
            frames: []
        )
    ]
    return NavigationStack {
        VideoReviewView(appModel: model)
    }
}