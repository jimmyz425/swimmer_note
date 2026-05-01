import SwiftUI

struct IntervalCalculatorView: View {
    let cssTest: CSSTestResult

    @State private var selectedZone: TrainingZone = .lactateThreshold
    @State private var intervalDistance: Int = 100
    @State private var numberOfReps: Int = 8
    @State private var restSeconds: Int = 15
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    cssInfoSection

                    zonePacesSection

                    intervalCalculatorSection

                    sampleSetsSection
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
            .navigationTitle("Interval Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var cssInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current CSS")
                .font(.title3.bold())

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CSS Pace")
                        .font(.caption)
                        .foregroundStyle(PoolTheme.smoke)
                    Text(cssTest.formattedPace)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(PoolTheme.mid)
                    Text("per 100m")
                        .font(.caption2)
                        .foregroundStyle(PoolTheme.smoke)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Speed")
                        .font(.caption)
                        .foregroundStyle(PoolTheme.smoke)
                    Text("\(cssTest.cssMetersPerSecond, specifier: "%.2f") m/s")
                        .font(.headline)
                        .foregroundStyle(PoolTheme.deep)
                }
            }

            Text("From \(cssTest.testType.displayName) on \(formatDate(cssTest.date))")
                .font(.caption)
                .foregroundStyle(PoolTheme.smoke)
        }
        .poolCard()
    }

    private var zonePacesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Training Zone Paces")
                .font(.title3.bold())

            ForEach(TrainingZone.allCases, id: \.self) { zone in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(zone.name)
                            .font(.headline)
                            .foregroundStyle(zone == selectedZone ? PoolTheme.mid : PoolTheme.deep)
                        Text(zone.description)
                            .font(.caption)
                            .foregroundStyle(PoolTheme.smoke)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatPace(cssTest.trainingPace(zone: zone)))
                            .font(.title3.bold())
                            .foregroundStyle(zone == selectedZone ? PoolTheme.mid : PoolTheme.deep)
                        Text("/100m")
                            .font(.caption2)
                            .foregroundStyle(PoolTheme.smoke)
                    }
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedZone = zone
                }

                if zone != .sprint {
                    Divider()
                }
            }

            Text("Tap a zone to calculate intervals")
                .font(.caption)
                .foregroundStyle(PoolTheme.smoke)
        }
        .poolCard()
    }

    private var intervalCalculatorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Interval Calculator")
                .font(.title3.bold())

            HStack {
                Text("Zone:")
                    .font(.subheadline.bold())
                Spacer()
                Text(selectedZone.name)
                    .font(.headline)
                    .foregroundStyle(PoolTheme.mid)
            }

            Divider()

            // Distance picker
            HStack {
                Text("Interval Distance:")
                    .font(.subheadline)
                Spacer()
                Picker("", selection: $intervalDistance) {
                    Text("25m").tag(25)
                    Text("50m").tag(50)
                    Text("100m").tag(100)
                    Text("200m").tag(200)
                    Text("400m").tag(400)
                }
                .pickerStyle(.menu)
            }

            // Reps
            HStack {
                Text("Number of Reps:")
                    .font(.subheadline)
                Spacer()
                Stepper("\(numberOfReps) reps", value: $numberOfReps, in: 1...20)
            }

            // Rest
            HStack {
                Text("Rest per rep:")
                    .font(.subheadline)
                Spacer()
                Picker("", selection: $restSeconds) {
                    Text("5s").tag(5)
                    Text("10s").tag(10)
                    Text("15s").tag(15)
                    Text("20s").tag(20)
                    Text("30s").tag(30)
                    Text("45s").tag(45)
                    Text("60s").tag(60)
                }
                .pickerStyle(.menu)
            }

            Divider()

            // Calculated results
            VStack(alignment: .leading, spacing: 12) {
                Text("Calculated Set")
                    .font(.headline)
                    .foregroundStyle(PoolTheme.deep)

                let targetPacePer100m = cssTest.trainingPace(zone: selectedZone)
                let targetTimePerRep = targetPacePer100m * (Double(intervalDistance) / 100.0)
                let sendOff = targetTimePerRep + Double(restSeconds)
                let totalTime = sendOff * Double(numberOfReps)
                let totalDistance = intervalDistance * numberOfReps

                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Target Time:")
                                .font(.caption)
                            Text(formatPace(targetTimePerRep))
                                .font(.headline)
                                .foregroundStyle(PoolTheme.mid)
                            Text("per \(intervalDistance)m")
                                .font(.caption2)
                                .foregroundStyle(PoolTheme.smoke)
                        }

                        HStack {
                            Text("Send-off:")
                                .font(.caption)
                            Text(formatPace(sendOff))
                                .font(.headline)
                                .foregroundStyle(PoolTheme.mid)
                        }

                        HStack {
                            Text("Total Distance:")
                                .font(.caption)
                            Text("\(totalDistance)m")
                                .font(.headline)
                                .foregroundStyle(PoolTheme.deep)
                        }

                        HStack {
                            Text("Total Time:")
                                .font(.caption)
                            Text(formatTotalTime(totalTime))
                                .font(.headline)
                                .foregroundStyle(PoolTheme.deep)
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(PoolTheme.light.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Set description
                Text("\(numberOfReps) x \(intervalDistance)m on \(formatPace(sendOff)) at \(selectedZone.name) pace")
                    .font(.subheadline.bold())
                    .foregroundStyle(PoolTheme.deep)
            }
        }
        .poolCard()
    }

    private var sampleSetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sample Sets for Your CSS")
                .font(.title3.bold())

            ForEach(sampleSets, id: \.description) { set in
                VStack(alignment: .leading, spacing: 8) {
                    Text(set.zone.name)
                        .font(.caption.bold())
                        .foregroundStyle(PoolTheme.mid)

                    Text(set.description)
                        .font(.subheadline)
                        .foregroundStyle(PoolTheme.deep)

                    HStack(spacing: 16) {
                        Text("Send-off: \(formatPace(set.sendOff))")
                            .font(.caption)
                        Text("Pace: \(formatPace(set.targetPace))/100m")
                            .font(.caption)
                    }
                    .foregroundStyle(PoolTheme.smoke)
                }
                .padding(.vertical, 8)
                Divider()
            }
        }
        .poolCard()
    }

    private var sampleSets: [SampleSet] {
        let css = cssTest.cssPaceSecondsPer100m

        return [
            SampleSet(
                zone: .aerobicEndurance,
                description: "10 x 100m aerobic set",
                targetPace: css + 7,
                sendOff: css + 7 + 20,
                distance: 100,
                reps: 10
            ),
            SampleSet(
                zone: .lactateThreshold,
                description: "8 x 100m threshold set",
                targetPace: css - 1,
                sendOff: css - 1 + 15,
                distance: 100,
                reps: 8
            ),
            SampleSet(
                zone: .vo2max,
                description: "6 x 100m VO2max set",
                targetPace: css - 4,
                sendOff: css - 4 + 30,
                distance: 100,
                reps: 6
            ),
            SampleSet(
                zone: .lactateThreshold,
                description: "6 x 200m threshold set",
                targetPace: (css - 1) * 2,
                sendOff: (css - 1) * 2 + 20,
                distance: 200,
                reps: 6
            )
        ]
    }

    struct SampleSet {
        let zone: TrainingZone
        let description: String
        let targetPace: TimeInterval
        let sendOff: TimeInterval
        let distance: Int
        let reps: Int
    }

    private func formatDate(_ isoDate: String) -> String {
        guard let date = DateFormatter.yyyyMMdd.date(from: isoDate) else { return isoDate }
        return DateFormatter.mediumDate.string(from: date)
    }

    private func formatPace(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func formatTotalTime(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let mins = totalMinutes % 60
            return String(format: "%dh %dm", hours, mins)
        }
        return String(format: "%dm %ds", totalMinutes, secs)
    }
}

// MARK: - Previews

#Preview("Interval Calculator") {
    IntervalCalculatorView(
        cssTest: CSSTestResult(
            date: "2024-03-01",
            testType: .twoTrial,
            strokeId: .freestyle,
            time200m: 140,
            time400m: 295,
            cssMetersPerSecond: 1.29,
            cssPaceSecondsPer100m: 77.5
        )
    )
}