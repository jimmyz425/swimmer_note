import SwiftUI
import Charts

struct CSSProgressionChartView: View {
    let cssHistory: CSSHistory

    @State private var selectedTimeRange: TimeRange = .all

    enum TimeRange: String, CaseIterable {
        case all = "All"
        case sixMonths = "6 Months"
        case threeMonths = "3 Months"
        case oneMonth = "1 Month"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    summarySection

                    chartSection

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
            .navigationTitle("CSS Progression")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var filteredTests: [CSSTestResult] {
        let tests = cssHistory.tests.sorted { $0.date < $1.date }  // Chronological order

        let now = Date()
        let cutoff: Date?

        switch selectedTimeRange {
        case .all: cutoff = nil
        case .sixMonths: cutoff = Calendar.current.date(byAdding: .month, value: -6, to: now)
        case .threeMonths: cutoff = Calendar.current.date(byAdding: .month, value: -3, to: now)
        case .oneMonth: cutoff = Calendar.current.date(byAdding: .month, value: -1, to: now)
        }

        if let cutoff {
            return tests.filter { test in
                guard let testDate = DateFormatter.yyyyMMdd.date(from: test.date) else { return true }
                return testDate >= cutoff
            }
        }
        return tests
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.title3.bold())

            if let latest = cssHistory.latestTest, let trend = cssHistory.trend {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current CSS")
                            .font(.caption)
                            .foregroundStyle(PoolTheme.smoke)
                        Text(latest.formattedPace)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(PoolTheme.mid)
                        Text("per 100m")
                            .font(.caption2)
                            .foregroundStyle(PoolTheme.smoke)
                    }

                    Spacer()

                    VStack(alignment: .center, spacing: 8) {
                        Image(systemName: trend.symbol)
                            .font(.title)
                            .foregroundStyle(trendColor(trend))
                        Text(trend.rawValue.capitalized)
                            .font(.caption.bold())
                            .foregroundStyle(trendColor(trend))
                    }

                    if cssHistory.tests.count >= 2 {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Change")
                                .font(.caption)
                                .foregroundStyle(PoolTheme.smoke)
                            let change = cssHistory.tests[1].cssPaceSecondsPer100m - latest.cssPaceSecondsPer100m
                            Text(change > 0 ? "-\(formatTime(change))" : "+\(formatTime(abs(change)))")
                                .font(.title2.bold())
                                .foregroundStyle(change > 0 ? .green : .orange)
                            Text(change > 0 ? "improved" : "slower")
                                .font(.caption2)
                                .foregroundStyle(PoolTheme.smoke)
                        }
                    }
                }
            }
        }
        .poolCard()
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("CSS Over Time")
                    .font(.title3.bold())
                Spacer()
                Picker("Range", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.menu)
            }

            if filteredTests.isEmpty {
                ContentUnavailableView(
                    "No Tests in Range",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Select a different time range or add more tests.")
                )
                .frame(height: 200)
            } else {
                Chart(filteredTests) { test in
                    LineMark(
                        x: .value("Date", formatDateForChart(test.date)),
                        y: .value("Pace", test.cssPaceSecondsPer100m)
                    )
                    .foregroundStyle(PoolTheme.mid)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", formatDateForChart(test.date)),
                        y: .value("Pace", test.cssPaceSecondsPer100m)
                    )
                    .foregroundStyle(PoolTheme.mid)
                    .symbolSize(60)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let pace = value.as(TimeInterval.self) {
                                Text(formatPace(pace))
                            }
                        }
                    }
                }
                .chartYAxisLabel("Pace (per 100m)")
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .frame(height: 250)
            }

            // Zone reference lines
            if let latest = cssHistory.latestTest {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Training Zone Paces")
                        .font(.caption.bold())
                        .foregroundStyle(PoolTheme.smoke)

                    ForEach(TrainingZone.allCases.filter { $0 != .sprint }, id: \.self) { zone in
                        HStack {
                            Text(zone.name)
                                .font(.caption)
                            Spacer()
                            Text(formatPace(latest.trainingPace(zone: zone)))
                                .font(.caption.bold())
                                .foregroundStyle(PoolTheme.deep)
                            Text("/100m")
                                .font(.caption2)
                                .foregroundStyle(PoolTheme.smoke)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .poolCard()
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test History")
                .font(.title3.bold())

            if cssHistory.tests.isEmpty {
                Text("No tests recorded yet.")
                    .foregroundStyle(PoolTheme.smoke)
            } else {
                ForEach(cssHistory.tests) { test in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(formatDate(test.date))
                                .font(.headline)
                                .foregroundStyle(PoolTheme.deep)
                            Text(test.testType.displayName)
                                .font(.caption)
                                .foregroundStyle(PoolTheme.smoke)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text(test.formattedPace)
                                .font(.title3.bold())
                                .foregroundStyle(PoolTheme.mid)
                            Text("per 100m")
                                .font(.caption2)
                                .foregroundStyle(PoolTheme.smoke)
                        }
                    }
                    .padding(.vertical, 8)
                    Divider()
                }
            }
        }
        .poolCard()
    }

    private func trendColor(_ trend: CSSPaceTrend) -> Color {
        switch trend {
        case .improving: .green
        case .stable: .blue
        case .declining: .orange
        }
    }

    private func formatDate(_ isoDate: String) -> String {
        guard let date = DateFormatter.yyyyMMdd.date(from: isoDate) else { return isoDate }
        return DateFormatter.mediumDate.string(from: date)
    }

    private func formatDateForChart(_ isoDate: String) -> String {
        guard let date = DateFormatter.yyyyMMdd.date(from: isoDate) else { return isoDate }
        return DateFormatter.shortMonthDay.string(from: date)
    }

    private func formatPace(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return String(format: "%.0fs", seconds)
        }
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%dm %ds", minutes, secs)
    }
}

// MARK: - Previews

#Preview("CSS Progression - With Data") {
    CSSProgressionChartView(
        cssHistory: CSSHistory(
            tests: [
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
                    date: "2024-01-01",
                    testType: .twoTrial,
                    strokeId: .freestyle,
                    time200m: 150,
                    time400m: 315,
                    cssMetersPerSecond: 1.18,
                    cssPaceSecondsPer100m: 84.7
                )
            ]
        )
    )
}

#Preview("CSS Progression - Empty") {
    CSSProgressionChartView(cssHistory: CSSHistory())
}