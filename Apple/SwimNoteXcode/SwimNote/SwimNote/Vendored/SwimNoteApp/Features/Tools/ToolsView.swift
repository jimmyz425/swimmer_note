import SwiftUI
import AVKit
import UniformTypeIdentifiers

struct ToolsView: View {
    @Bindable var appModel: SwimNoteAppModel
    @State private var selectedVideoURL: URL?
    @State private var player: AVPlayer?
    @State private var isImporterPresented = false
    @State private var showingProfileMenu = false
    @State private var showingUserSelection = false
    @State private var showingEditProfile = false
    @State private var showingCSSEditor = false
    @State private var showingIntervalCalculator = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection

                    videoSection

                    savedAnalysisSection

                    cssToolsSection
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
            .sheet(isPresented: $showingUserSelection) {
                UserSelectionView(appModel: appModel)
            }
            .sheet(isPresented: $showingEditProfile) {
                if let profile = appModel.activeProfile {
                    PersonalBestsEditor(appModel: appModel, profile: profile)
                }
            }
            .sheet(isPresented: $showingCSSEditor) {
                if let profile = appModel.activeProfile {
                    CSSTestInputView(appModel: appModel, profile: profile)
                }
            }
            .sheet(isPresented: $showingIntervalCalculator) {
                if let css = appModel.activeProfile?.cssHistory?.latestTest {
                    IntervalCalculatorView(cssTest: css)
                }
            }
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("TOOLS")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(PoolTheme.deep)
                Text("Video analysis & CSS tracking")
                    .font(.headline)
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

    private var videoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Video Review")
                .font(.title3.bold())

            if let player {
                VideoPlayer(player: player)
                    .frame(minHeight: 240)
                    .cornerRadius(12)
            } else {
                ContentUnavailableView(
                    "Import a Video",
                    systemImage: "video.badge.plus",
                    description: Text("Import swim footage to analyze technique.")
                )
            }
        }
        .poolCard()
    }

    private var savedAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Saved Video Analysis")
                .font(.title3.bold())

            if appModel.videoRecords.isEmpty {
                Text("No analysis records yet.")
                    .foregroundStyle(PoolTheme.smoke)
            } else {
                ForEach(appModel.videoRecords) { record in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.videoFilename)
                                .font(.headline)
                                .foregroundStyle(PoolTheme.deep)
                            Text("Kick rate: \(record.metrics.kickRatePerMinute, specifier: "%.1f") / min")
                                .font(.subheadline)
                                .foregroundStyle(PoolTheme.smoke)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    Divider()
                }
            }
        }
        .poolCard()
    }

    private var cssToolsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CSS Tools")
                .font(.title3.bold())

            // CSS Progression
            NavigationLink {
                if let cssHistory = appModel.activeProfile?.cssHistory {
                    CSSProgressionChartView(cssHistory: cssHistory)
                } else {
                    ContentUnavailableView(
                        "No CSS History",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Take a CSS test to start tracking your progression.")
                    )
                }
            } label: {
                HStack {
                    Image(systemName: "chart.xyaxis.line")
                        .foregroundStyle(PoolTheme.mid)
                    Text("CSS Progression Chart")
                        .foregroundStyle(PoolTheme.deep)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(PoolTheme.smoke)
                }
                .padding(.vertical, 8)
            }

            Divider()

            // Interval Calculator
            Button {
                showingIntervalCalculator = true
            } label: {
                HStack {
                    Image(systemName: "speedometer")
                        .foregroundStyle(PoolTheme.mid)
                    Text("Interval Calculator")
                        .foregroundStyle(PoolTheme.deep)
                    Spacer()
                    if appModel.activeProfile?.cssHistory?.latestTest != nil {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(PoolTheme.smoke)
                    } else {
                        Text("Need CSS test")
                            .font(.caption)
                            .foregroundStyle(PoolTheme.smoke)
                    }
                }
                .padding(.vertical, 8)
            }
            .disabled(appModel.activeProfile?.cssHistory?.latestTest == nil)

            Divider()

            // New Test Button
            Button {
                showingCSSEditor = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(PoolTheme.mid)
                    Text("Record New CSS Test")
                        .foregroundStyle(PoolTheme.deep)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(PoolTheme.smoke)
                }
                .padding(.vertical, 8)
            }
        }
        .poolCard()
    }

    private func formatDate(_ isoDate: String) -> String {
        guard let date = DateFormatter.yyyyMMdd.date(from: isoDate) else { return isoDate }
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

// MARK: - Previews

private func makePreviewModel(withCSS: Bool = false, withRecords: Bool = false) -> SwimNoteAppModel {
    let model = SwimNoteAppModel.bootstrap()
    model.activeProfile = UserProfile(
        id: "preview-user",
        name: "Alex",
        birthday: "1995-06-15",
        sex: .male,
        skillLevel: .intermediate,
        weeklySessionTarget: 3,
        preferredStrokes: [.freestyle],
        mainStroke: .freestyle,
        distancePreference: .mid,
        personalBests: PersonalBests(freestyle50m: 32.5),
        trainingGoals: [],
        createdAt: "2024-01-01T00:00:00Z",
        updatedAt: "2024-01-01T00:00:00Z"
    )
    if withCSS {
        model.activeProfile?.cssHistory = CSSHistory(
            tests: [
                CSSTestResult(
                    date: "2024-04-15",
                    testType: .twoTrial,
                    strokeId: .freestyle,
                    time200m: 135,
                    time400m: 285,
                    cssMetersPerSecond: 1.33,
                    cssPaceSecondsPer100m: 75.2
                ),
                CSSTestResult(
                    date: "2024-03-01",
                    testType: .twoTrial,
                    strokeId: .freestyle,
                    time200m: 140,
                    time400m: 295,
                    cssMetersPerSecond: 1.29,
                    cssPaceSecondsPer100m: 77.5
                ),
                CSSTestResult(
                    date: "2024-02-01",
                    testType: .twoTrial,
                    strokeId: .freestyle,
                    time200m: 145,
                    time400m: 305,
                    cssMetersPerSecond: 1.23,
                    cssPaceSecondsPer100m: 81.3
                ),
                CSSTestResult(
                    date: "2024-01-15",
                    testType: .twoTrial,
                    strokeId: .freestyle,
                    time200m: 148,
                    time400m: 312,
                    cssMetersPerSecond: 1.19,
                    cssPaceSecondsPer100m: 84.0
                ),
                CSSTestResult(
                    date: "2023-12-01",
                    testType: .twoTrial,
                    strokeId: .freestyle,
                    time200m: 152,
                    time400m: 320,
                    cssMetersPerSecond: 1.15,
                    cssPaceSecondsPer100m: 87.0
                )
            ]
        )
    }
    if withRecords {
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
    }
    return model
}

#Preview("Tools - Empty") {
    ToolsView(appModel: makePreviewModel())
}

#Preview("Tools - With CSS") {
    ToolsView(appModel: makePreviewModel(withCSS: true))
}

#Preview("Tools - Full") {
    ToolsView(appModel: makePreviewModel(withCSS: true, withRecords: true))
}
