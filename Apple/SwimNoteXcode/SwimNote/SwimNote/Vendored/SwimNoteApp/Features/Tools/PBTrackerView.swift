import SwiftUI

struct PBTrackerView: View {
    @Bindable var appModel: SwimNoteAppModel
    @State private var showingAddResult = false
    @State private var selectedStroke: StrokeID?
    @State private var selectedDistance: Int?

    private var pbHistory: PBHistory {
        appModel.activeProfile?.pbHistory ?? PBHistory()
    }

    private let strokes: [(StrokeID, String)] = [
        (.freestyle, "Freestyle"),
        (.backstroke, "Backstroke"),
        (.breaststroke, "Breaststroke"),
        (.butterfly, "Butterfly")
    ]

    private let distances = [50, 100, 200, 400, 800, 1500]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Current Bests Section
                currentBestsSection

                // Add Result Button
                addResultSection

                // History Section
                historySection
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
        .navigationTitle("Personal Bests")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddResult = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddResult) {
            if let profile = appModel.activeProfile {
                PBResultInputView(appModel: appModel, profile: profile)
            }
        }
    }

    private var currentBestsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Bests")
                .font(.title3.bold())

            if pbHistory.isEmpty {
                ContentUnavailableView(
                    "No Times Recorded",
                    systemImage: "medal",
                    description: Text("Add your first meet result to start tracking personal bests.")
                )
            } else {
                let bests = pbHistory.currentBests()
                ForEach(bests) { result in
                    PBResultRow(result: result, showTrend: true)
                }
            }
        }
        .poolCard()
    }

    private var addResultSection: some View {
        Button {
            showingAddResult = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(PoolTheme.mid)
                Text("Add Meet Result")
                    .font(.headline)
                    .foregroundStyle(PoolTheme.deep)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(PoolTheme.smoke)
            }
            .padding(.vertical, 8)
        }
        .poolCard()
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("History")
                .font(.title3.bold())

            if pbHistory.results.isEmpty {
                Text("No meet results yet.")
                    .foregroundStyle(PoolTheme.smoke)
            } else {
                // Filter picker
                HStack(spacing: 12) {
                    Picker("Stroke", selection: $selectedStroke) {
                        Text("All").tag(nil as StrokeID?)
                        ForEach(strokes, id: \.0) { strokeId, strokeName in
                            Text(strokeName).tag(strokeId as StrokeID?)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Distance", selection: $selectedDistance) {
                        Text("All").tag(nil as Int?)
                        ForEach(distances, id: \.self) { dist in
                            Text("\(dist)m").tag(dist as Int?)
                        }
                    }
                    .pickerStyle(.menu)
                }

                ForEach(filteredResults) { result in
                    PBResultRow(result: result)
                    if result.id != filteredResults.last?.id {
                        Divider()
                    }
                }
            }
        }
        .poolCard()
    }

    private var filteredResults: [PBResult] {
        var results = pbHistory.results
        if let stroke = selectedStroke {
            results = results.filter { $0.strokeId == stroke }
        }
        if let distance = selectedDistance {
            results = results.filter { $0.distance == distance }
        }
        return results
    }
}

// MARK: - PB Result Row

struct PBResultRow: View {
    let result: PBResult
    var showTrend: Bool = false

    private var trend: PBTrend? {
        nil  // Would need history context to compute
    }

    var body: some View {
        HStack(spacing: 12) {
            // Stroke icon
            Image(systemName: strokeIcon(result.strokeId))
                .font(.title2)
                .foregroundStyle(PoolTheme.mid)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.eventLabel)
                    .font(.headline)
                    .foregroundStyle(PoolTheme.deep)

                Text(formatDate(result.date))
                    .font(.caption)
                    .foregroundStyle(PoolTheme.smoke)

                if let meetName = result.meetName {
                    Text(meetName)
                        .font(.caption2)
                        .foregroundStyle(PoolTheme.smoke.opacity(0.8))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(result.formattedTime)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(PoolTheme.deep)

                Text(result.courseType.shortLabel)
                    .font(.caption)
                    .foregroundStyle(PoolTheme.mid)
            }
        }
        .padding(.vertical, 4)
    }

    private func strokeIcon(_ stroke: StrokeID) -> String {
        switch stroke {
        case .freestyle: "figure.pool.swim"
        case .backstroke: "figure.pool.swim"
        case .breaststroke: "figure.pool.swim"
        case .butterfly: "figure.pool.swim"
        case .im: "figure.pool.swim"
        case .master: "figure.pool.swim"
        }
    }

    private func formatDate(_ isoDate: String) -> String {
        guard let date = DateFormatter.yyyyMMdd.date(from: isoDate) else { return isoDate }
        return DateFormatter.mediumDate.string(from: date)
    }
}

// MARK: - Previews

@MainActor
private func previewPBTrackerWithResults() -> some View {
    let model = SwimNoteAppModel.bootstrap()
    model.profileStore.activeProfile = UserProfile(
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
        pbHistory: PBHistory(results: [
            PBResult(date: "2024-04-15", strokeId: .freestyle, distance: 50, time: 32.5, meetName: "LSC Championship", courseType: .shortCourse),
            PBResult(date: "2024-03-01", strokeId: .freestyle, distance: 50, time: 34.2, meetName: "Sectional Meet", courseType: .shortCourse),
            PBResult(date: "2024-02-15", strokeId: .freestyle, distance: 100, time: 68.5, courseType: .shortCourse),
            PBResult(date: "2024-01-10", strokeId: .backstroke, distance: 50, time: 36.8, courseType: .shortCourse)
        ]),
        trainingGoals: [],
        createdAt: "2024-01-01T00:00:00Z",
        updatedAt: "2024-01-01T00:00:00Z"
    )
    return PBTrackerView(appModel: model)
}

#Preview("PB Tracker - Empty") {
    PBTrackerView(appModel: SwimNoteAppModel.bootstrap())
}

#Preview("PB Tracker - With Results") {
    previewPBTrackerWithResults()
}