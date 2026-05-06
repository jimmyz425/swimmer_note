import SwiftUI

struct TechniqueMeasurementView: View {
    @Bindable var appModel: SwimNoteAppModel
    @State private var showingAddMeasurement = false
    @State private var selectedStroke: StrokeID?
    @State private var selectedDate: String?
    @State private var selectedDrillContext: String?

    private var measurements: [TechniqueMeasurement] {
        appModel.measurements
    }

    private let strokes: [(StrokeID, String)] = [
        (.freestyle, "Freestyle"),
        (.backstroke, "Backstroke"),
        (.breaststroke, "Breaststroke"),
        (.butterfly, "Butterfly")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection

                filterSection

                measurementsSection

                comparisonSection
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
        .navigationTitle("Technique Measurements")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddMeasurement = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddMeasurement) {
            if let profile = appModel.activeProfile {
                TechniqueMeasurementInputView(appModel: appModel, profile: profile)
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Track technique efficiency")
                .font(.headline)
                .foregroundStyle(PoolTheme.mid)

            if measurements.isEmpty {
                Text("No measurements recorded yet.")
                    .font(.subheadline)
                    .foregroundStyle(PoolTheme.smoke)
            } else {
                Text("\(measurements.count) measurements across \(uniqueDates.count) sessions")
                    .font(.subheadline)
                    .foregroundStyle(PoolTheme.smoke)
            }
        }
    }

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filters")
                .font(.title3.bold())

            HStack(spacing: 12) {
                Picker("Stroke", selection: $selectedStroke) {
                    Text("All Strokes").tag(nil as StrokeID?)
                    ForEach(strokes, id: \.0) { strokeId, strokeName in
                        Text(strokeName).tag(strokeId as StrokeID?)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)

                Picker("Date", selection: $selectedDate) {
                    Text("All Dates").tag(nil as String?)
                    ForEach(uniqueDates, id: \.self) { date in
                        Text(formatDate(date)).tag(date as String?)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
            }
        }
        .poolCard()
    }

    private var measurementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Measurements")
                .font(.title3.bold())

            if filteredMeasurements.isEmpty {
                ContentUnavailableView(
                    "No Measurements",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Record technique measurements to track progression.")
                )
            } else {
                ForEach(filteredMeasurements) { measurement in
                    MeasurementRow(measurement: measurement)
                    if measurement.id != filteredMeasurements.last?.id {
                        Divider()
                    }
                }
            }
        }
        .poolCard()
    }

    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Before/After Comparison")
                .font(.title3.bold())

            if pairedMeasurements.isEmpty {
                Text("Record 'before' and 'after' measurements with the same drill context to see improvement.")
                    .font(.subheadline)
                    .foregroundStyle(PoolTheme.smoke)
            } else {
                ForEach(pairedMeasurements, id: \.before.id) { pair in
                    ComparisonRow(before: pair.before, after: pair.after)
                    if pair.before.id != pairedMeasurements.last?.before.id {
                        Divider()
                    }
                }
            }
        }
        .poolCard()
    }

    // MARK: - Computed Properties

    private var filteredMeasurements: [TechniqueMeasurement] {
        var result = measurements
        if let stroke = selectedStroke {
            result = result.filter { $0.strokeId == stroke }
        }
        if let date = selectedDate {
            result = result.filter { $0.date == date }
        }
        return result.sorted { $0.timestamp > $1.timestamp }
    }

    private var uniqueDates: [String] {
        let dates = Set(measurements.map { $0.date })
        return dates.sorted(by: >)
    }

    private var uniqueDrillContexts: [String] {
        let contexts = measurements.compactMap { $0.drillContext }
        return Array(Set(contexts)).sorted()
    }

    /// Pair measurements with same drill context on same date
    private var pairedMeasurements: [(before: TechniqueMeasurement, after: TechniqueMeasurement)] {
        var pairs: [(before: TechniqueMeasurement, after: TechniqueMeasurement)] = []

        // Group by date and drill context using a string key
        let grouped = Dictionary(grouping: measurements, by: { m -> String in
            "\(m.date)_\(m.drillContext ?? "")"
        })

        for (_, measurementsInGroup) in grouped {
            // Find before/after pairs within same date+context
            let beforeMeasurements = measurementsInGroup.filter { $0.drillContext?.contains("before") == true }
            let afterMeasurements = measurementsInGroup.filter { $0.drillContext?.contains("after") == true }

            // Match by stroke
            for before in beforeMeasurements {
                if let after = afterMeasurements.first(where: { $0.strokeId == before.strokeId }) {
                    pairs.append((before, after))
                }
            }
        }

        return pairs.sorted { $0.before.timestamp > $1.before.timestamp }
    }

    // MARK: - Helpers

    private func formatDate(_ isoDate: String) -> String {
        guard let date = DateFormatter.yyyyMMdd.date(from: isoDate) else { return isoDate }
        return DateFormatter.mediumDate.string(from: date)
    }
}

// MARK: - Measurement Row

struct MeasurementRow: View {
    let measurement: TechniqueMeasurement

    var body: some View {
        HStack(spacing: 12) {
            // Stroke icon
            Image(systemName: "figure.pool.swim")
                .font(.title2)
                .foregroundStyle(PoolTheme.mid)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(measurement.strokeId.rawValue.capitalized) - \(measurement.poolLengthLabel)")
                    .font(.headline)
                    .foregroundStyle(PoolTheme.deep)

                HStack(spacing: 8) {
                    Text("\(measurement.strokeCount) strokes")
                    Text("•")
                    Text(measurement.formattedLapTime)
                }
                .font(.subheadline)
                .foregroundStyle(PoolTheme.smoke)

                if let drillContext = measurement.drillContext {
                    Text(drillContext)
                        .font(.caption)
                        .foregroundStyle(PoolTheme.mid)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Zone \(measurement.effortZone)")
                    .font(.caption)
                    .foregroundStyle(PoolTheme.mid)

                if measurement.handPosition != nil {
                    Text(measurement.handPosition!.rawValue.capitalized)
                        .font(.caption2)
                        .foregroundStyle(PoolTheme.smoke)
                }

                if measurement.kickPerStroke != nil {
                    Text(measurement.kickDisplay)
                        .font(.caption2)
                        .foregroundStyle(PoolTheme.smoke)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Comparison Row

struct ComparisonRow: View {
    let before: TechniqueMeasurement
    let after: TechniqueMeasurement

    private var strokeCountChange: Int {
        before.strokeCount - after.strokeCount  // Positive = fewer strokes after = improvement
    }

    private var timeChange: TimeInterval {
        before.lapTime - after.lapTime  // Positive = faster after = improvement
    }

    private var speedChange: Double {
        after.speed - before.speed  // Positive = faster speed = improvement
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Drill context header
            if let drillContext = before.drillContext {
                Text(drillContext.replacingOccurrences(of: "before ", with: ""))
                    .font(.headline)
                    .foregroundStyle(PoolTheme.deep)
            }

            HStack(spacing: 16) {
                // Before column
                VStack(alignment: .leading, spacing: 4) {
                    Text("Before")
                        .font(.caption)
                        .foregroundStyle(PoolTheme.smoke)
                    Text("\(before.strokeCount) strokes")
                    Text(before.formattedLapTime)
                }
                .font(.subheadline)

                Spacer()

                // Improvement indicators
                VStack(alignment: .trailing, spacing: 4) {
                    if strokeCountChange > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down")
                            Text("-\(strokeCountChange)")
                        }
                        .foregroundStyle(.green)
                    } else if strokeCountChange < 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up")
                            Text("+\(abs(strokeCountChange))")
                        }
                        .foregroundStyle(.orange)
                    }

                    if timeChange > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down")
                            Text("-\(Int(timeChange * 100) / 100, specifier: "%.1f")s")
                        }
                        .foregroundStyle(.green)
                    } else if timeChange < 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up")
                            Text("+\(abs(Int(timeChange * 100) / 100), specifier: "%.1f")s")
                        }
                        .foregroundStyle(.orange)
                    }
                }
                .font(.subheadline)

                Spacer()

                // After column
                VStack(alignment: .trailing, spacing: 4) {
                    Text("After")
                        .font(.caption)
                        .foregroundStyle(PoolTheme.smoke)
                    Text("\(after.strokeCount) strokes")
                    Text(after.formattedLapTime)
                }
                .font(.subheadline)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Previews

#Preview("Measurements - Empty") {
    NavigationStack {
        TechniqueMeasurementView(appModel: SwimNoteAppModel.bootstrap())
    }
}

#Preview("Measurements - With Data") {
    let model = SwimNoteAppModel.bootstrap()
    model.measurements = [
        TechniqueMeasurement(
            userId: "preview-user",
            date: "2024-05-05",
            strokeId: .freestyle,
            poolLength: 25,
            distanceUnit: .meters,
            strokeCount: 18,
            lapTime: 22.5,
            glideTime: 3.2,
            handPosition: .palm,
            kickPerStroke: 6,
            effortZone: 3,
            drillContext: "before catch drill"
        ),
        TechniqueMeasurement(
            userId: "preview-user",
            date: "2024-05-05",
            strokeId: .freestyle,
            poolLength: 25,
            distanceUnit: .meters,
            strokeCount: 15,
            lapTime: 21.8,
            glideTime: 3.5,
            handPosition: .palm,
            kickPerStroke: 6,
            effortZone: 3,
            drillContext: "after catch drill"
        ),
        TechniqueMeasurement(
            userId: "preview-user",
            date: "2024-05-05",
            strokeId: .backstroke,
            poolLength: 25,
            distanceUnit: .meters,
            strokeCount: 20,
            lapTime: 25.0,
            effortZone: 2
        )
    ]
    return NavigationStack {
        TechniqueMeasurementView(appModel: model)
    }
}