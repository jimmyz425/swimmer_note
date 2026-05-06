import SwiftUI

struct CSSToolsView: View {
    @Bindable var appModel: SwimNoteAppModel
    @State private var showingCSSEditor = false
    @State private var showingIntervalCalculator = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection

                currentCSSSection

                toolsSection

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
        .navigationTitle("CSS Tools")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCSSEditor = true
                } label: {
                    Image(systemName: "plus")
                }
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

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Critical Swim Speed analysis for training pace calculation")
                .font(.headline)
                .foregroundStyle(PoolTheme.mid)

            Text("CSS represents your aerobic threshold pace - ideal for endurance training.")
                .font(.subheadline)
                .foregroundStyle(PoolTheme.smoke)
        }
    }

    private var currentCSSSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current CSS")
                .font(.title3.bold())

            if let css = appModel.activeProfile?.cssHistory?.latestTest {
                HStack(spacing: 16) {
                    Image(systemName: "speedometer")
                        .font(.title)
                        .foregroundStyle(PoolTheme.mid)
                        .frame(width: 44)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(formatPace(css.cssPaceSecondsPer100m))
                            .font(.title2.bold())
                            .foregroundStyle(PoolTheme.deep)

                        Text("\(css.cssMetersPerSecond, specifier: "%.2f") m/s")
                            .font(.subheadline)
                            .foregroundStyle(PoolTheme.smoke)

                        Text(formatDate(css.date))
                            .font(.caption)
                            .foregroundStyle(PoolTheme.smoke)
                    }

                    Spacer()
                }
                .padding(.vertical, 8)
            } else {
                ContentUnavailableView(
                    "No CSS Test",
                    systemImage: "speedometer",
                    description: Text("Take a CSS test to calculate training intervals.")
                )
            }
        }
        .poolCard()
    }

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tools")
                .font(.title3.bold())

            // Interval Calculator
            Button {
                showingIntervalCalculator = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "function")
                        .font(.title2)
                        .foregroundStyle(PoolTheme.mid)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Interval Calculator")
                            .font(.headline)
                            .foregroundStyle(PoolTheme.deep)

                        Text("Calculate training paces from CSS")
                            .font(.subheadline)
                            .foregroundStyle(PoolTheme.smoke)
                    }

                    Spacer()

                    if appModel.activeProfile?.cssHistory?.latestTest != nil {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(PoolTheme.smoke)
                    } else {
                        Text("Need CSS")
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
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle")
                        .font(.title2)
                        .foregroundStyle(PoolTheme.mid)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Record New CSS Test")
                            .font(.headline)
                            .foregroundStyle(PoolTheme.deep)

                        Text("Perform 200m + 400m time trials")
                            .font(.subheadline)
                            .foregroundStyle(PoolTheme.smoke)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(PoolTheme.smoke)
                }
                .padding(.vertical, 8)
            }
        }
        .poolCard()
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progression History")
                .font(.title3.bold())

            if let cssHistory = appModel.activeProfile?.cssHistory, !cssHistory.tests.isEmpty {
                // Chart Link
                NavigationLink {
                    CSSProgressionChartView(cssHistory: cssHistory)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.title2)
                            .foregroundStyle(PoolTheme.mid)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("View Progression Chart")
                                .font(.headline)
                                .foregroundStyle(PoolTheme.deep)

                            Text("\(cssHistory.tests.count) tests recorded")
                                .font(.subheadline)
                                .foregroundStyle(PoolTheme.smoke)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundStyle(PoolTheme.smoke)
                    }
                    .padding(.vertical, 8)
                }

                Divider()

                // Recent tests list
                let recentTests = cssHistory.tests.sorted(by: { $0.date > $1.date })
                ForEach(recentTests.prefix(3).map { $0 }, id: \.id) { test in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(formatDate(test.date))
                                .font(.headline)
                                .foregroundStyle(PoolTheme.deep)

                            Text(formatPace(test.cssPaceSecondsPer100m))
                                .font(.subheadline)
                                .foregroundStyle(PoolTheme.mid)
                        }

                        Spacer()

                        Text(test.strokeId.rawValue.capitalized)
                            .font(.caption)
                            .foregroundStyle(PoolTheme.smoke)
                    }
                    .padding(.vertical, 4)

                    if test.id != recentTests.prefix(3).last?.id {
                        Divider()
                    }
                }
            } else {
                ContentUnavailableView(
                    "No History",
                    systemImage: "clock",
                    description: Text("Record CSS tests to track your aerobic fitness progression.")
                )
            }
        }
        .poolCard()
    }

    private func formatDate(_ isoDate: String) -> String {
        guard let date = DateFormatter.yyyyMMdd.date(from: isoDate) else { return isoDate }
        return DateFormatter.mediumDate.string(from: date)
    }

    private func formatPace(_ secondsPer100m: TimeInterval) -> String {
        let minutes = Int(secondsPer100m) / 60
        let seconds = Int(secondsPer100m) % 60
        return "\(minutes):\(String(format: "%02d", seconds)) / 100m"
    }
}

#Preview("CSS Tools - Empty") {
    NavigationStack {
        CSSToolsView(appModel: SwimNoteAppModel.bootstrap())
    }
}

#Preview("CSS Tools - With CSS") {
    let model = SwimNoteAppModel.bootstrap()
    model.activeProfile = UserProfile(
        id: "preview-user",
        name: "Alex",
        birthday: "1995-06-15",
        sex: .male,
        skillLevel: .intermediate,
        weeklySessionTarget: 3,
        preferredStrokes: [.freestyle],
        personalBests: PersonalBests.empty(),
        trainingGoals: [],
        createdAt: "2024-01-01T00:00:00Z",
        updatedAt: "2024-01-01T00:00:00Z"
    )
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
            )
        ]
    )
    return NavigationStack {
        CSSToolsView(appModel: model)
    }
}