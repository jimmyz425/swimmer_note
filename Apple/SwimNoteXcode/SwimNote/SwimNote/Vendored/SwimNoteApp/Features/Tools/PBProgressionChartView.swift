import SwiftUI
import Charts

struct PBProgressionChartView: View {
    let pbHistory: PBHistory

    @State private var selectedStroke: StrokeID?
    @State private var selectedDistance: Int?

    private let strokes: [(StrokeID, String)] = [
        (.freestyle, "Freestyle"),
        (.backstroke, "Backstroke"),
        (.breaststroke, "Breaststroke"),
        (.butterfly, "Butterfly")
    ]

    private let distances = [50, 100, 200, 400, 800, 1500]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Filter controls
                    filterSection

                    // Chart
                    chartSection

                    // Summary stats
                    summarySection
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
            .navigationTitle("PB Progression")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filter by Event")
                .font(.headline)

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
        }
        .poolCard()
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time Progression")
                .font(.headline)

            if filteredResults.isEmpty {
                ContentUnavailableView(
                    "No Data",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Add meet results for this event to see progression.")
                )
            } else {
                Chart(filteredResults) { result in
                    LineMark(
                        x: .value("Date", formatDateForChart(result.date)),
                        y: .value("Time", result.time)
                    )
                    .foregroundStyle(by: .value("Event", result.eventLabel))
                    .symbol(by: .value("Event", result.eventLabel))

                    PointMark(
                        x: .value("Date", formatDateForChart(result.date)),
                        y: .value("Time", result.time)
                    )
                    .foregroundStyle(by: .value("Event", result.eventLabel))
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 6))
                }
                .chartYScale(domain: .automatic)
                .frame(height: 300)
            }
        }
        .poolCard()
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.headline)

            if filteredResults.isEmpty {
                Text("No results to summarize.")
                    .foregroundStyle(PoolTheme.smoke)
            } else {
                ForEach(currentBestsByEvent) { summary in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(summary.eventLabel)
                                .font(.subheadline.bold())
                            Text("\(summary.totalResults) results")
                                .font(.caption)
                                .foregroundStyle(PoolTheme.smoke)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text(summary.bestTime.formattedTime)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(PoolTheme.deep)

                            if summary.improvement != nil {
                                Text(summary.improvement! > 0 ? "-\(formatTime(summary.improvement!))" : "No change")
                                    .font(.caption)
                                    .foregroundStyle(summary.improvement! > 0 ? .green : PoolTheme.smoke)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    Divider()
                }
            }
        }
        .poolCard()
    }

    private var filteredResults: [PBResult] {
        var results = pbHistory.results.sorted { $0.date < $1.date }  // Chronological order for chart
        if let stroke = selectedStroke {
            results = results.filter { $0.strokeId == stroke }
        }
        if let distance = selectedDistance {
            results = results.filter { $0.distance == distance }
        }
        return results
    }

    private var currentBestsByEvent: [PBSummary] {
        let events = Dictionary(grouping: filteredResults, by: { "\($0.strokeId.rawValue)-\($0.distance)" })
        return events.map { key, results in
            let sortedByTime = results.sorted { $0.time < $1.time }
            let best = sortedByTime.first!
            let improvement = sortedByTime.count >= 2 ? sortedByTime.last!.time - best.time : nil
            return PBSummary(
                eventLabel: "\(best.strokeId.rawValue.capitalized) \(best.distance)m",
                bestTime: best,
                totalResults: results.count,
                improvement: improvement
            )
        }.sorted { $0.eventLabel < $1.eventLabel }
    }

    private func formatDateForChart(_ isoDate: String) -> String {
        guard let date = DateFormatter.yyyyMMdd.date(from: isoDate) else { return isoDate }
        return DateFormatter.mediumDate.string(from: date)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let hundredths = Int((time * 100).truncatingRemainder(dividingBy: 100))
        if minutes > 0 {
            return String(format: "%d:%02d.%02d", minutes, seconds, hundredths)
        } else {
            return String(format: "%02d.%02d", seconds, hundredths)
        }
    }
}

// MARK: - PB Summary

struct PBSummary: Identifiable {
    let id = UUID()
    let eventLabel: String
    let bestTime: PBResult
    let totalResults: Int
    let improvement: TimeInterval?
}

// MARK: - Previews

#Preview("PB Progression - Empty") {
    PBProgressionChartView(pbHistory: PBHistory())
}

#Preview("PB Progression - With Data") {
    PBProgressionChartView(
        pbHistory: PBHistory(results: [
            PBResult(date: "2024-04-15", strokeId: .freestyle, distance: 50, time: 32.5, courseType: .shortCourse),
            PBResult(date: "2024-03-01", strokeId: .freestyle, distance: 50, time: 34.2, courseType: .shortCourse),
            PBResult(date: "2024-02-15", strokeId: .freestyle, distance: 50, time: 35.8, courseType: .shortCourse),
            PBResult(date: "2024-01-10", strokeId: .freestyle, distance: 100, time: 68.5, courseType: .shortCourse),
            PBResult(date: "2024-02-20", strokeId: .freestyle, distance: 100, time: 65.3, courseType: .shortCourse),
            PBResult(date: "2024-03-10", strokeId: .backstroke, distance: 50, time: 36.8, courseType: .shortCourse),
            PBResult(date: "2024-04-05", strokeId: .backstroke, distance: 50, time: 35.2, courseType: .shortCourse)
        ])
    )
}