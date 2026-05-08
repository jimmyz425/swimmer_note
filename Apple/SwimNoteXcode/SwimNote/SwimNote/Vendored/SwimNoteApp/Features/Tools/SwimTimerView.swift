import SwiftUI

/// Timer mode enum
enum TimerMode: String, CaseIterable {
    case stopwatch = "Stopwatch"
    case interval = "Interval"
}

/// Swim timer with stopwatch and interval modes
/// Large touch-friendly controls for poolside use
struct SwimTimerView: View {
    @Bindable var appModel: SwimNoteAppModel
    @State private var mode: TimerMode = .stopwatch
    @State private var stopwatchEngine = TimerEngine()
    @State private var intervalEngine = IntervalEngine()
    @State private var showingSaveSheet = false
    @State private var showingSaveSuccess = false
    @State private var showingHistory = false
    @State private var showingIntervalConfig = false

    private let strokes: [(StrokeID, String)] = [
        (.freestyle, "Freestyle"),
        (.backstroke, "Backstroke"),
        (.breaststroke, "Breaststroke"),
        (.butterfly, "Butterfly"),
        (.im, "IM")
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Fixed mode selector at top
            modeSelector
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(PoolTheme.surface)

            ScrollView {
                VStack(spacing: 24) {
                    if mode == .stopwatch {
                        stopwatchView
                    } else {
                        intervalView
                    }
                }
                .padding()
            }
        }
        .background(
            LinearGradient(
                colors: [PoolTheme.surface, PoolTheme.light.opacity(0.3)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .navigationTitle("Swim Timer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // History button
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showingHistory = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
            }

            // Save button (stopwatch) or Config button (interval)
            ToolbarItem(placement: .primaryAction) {
                if mode == .stopwatch {
                    if !stopwatchEngine.isRunning && stopwatchEngine.elapsedTime > 0 {
                        Button {
                            showingSaveSheet = true
                        } label: {
                            Image(systemName: "square.and.arrow.down")
                        }
                    }
                } else {
                    if !intervalEngine.isRunning {
                        Button {
                            showingIntervalConfig = true
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingSaveSheet) {
            saveSessionSheet
        }
        .sheet(isPresented: $showingHistory) {
            TimerHistoryView(appModel: appModel)
        }
        .sheet(isPresented: $showingIntervalConfig) {
            IntervalConfigSheet(engine: intervalEngine)
        }
        .alert("Session Saved", isPresented: $showingSaveSuccess) {
            Button("OK") { }
        } message: {
            Text("Timer session saved to your history.")
        }
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        HStack(spacing: 0) {
            ForEach(TimerMode.allCases, id: \.self) { timerMode in
                Button {
                    mode = timerMode
                } label: {
                    Text(timerMode.rawValue)
                        .font(.headline)
                        .foregroundStyle(mode == timerMode ? .white : PoolTheme.deep)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(mode == timerMode ? PoolTheme.mid : .clear)
                }
                .buttonStyle(.plain)
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Stopwatch View

    private var stopwatchView: some View {
        VStack(spacing: 24) {
            stopwatchHeaderSection
            stopwatchDisplaySection
            stopwatchControlSection
            strokeCounterSection
            stopwatchSplitsSection
        }
    }

    private var stopwatchHeaderSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(stopwatchEngine.splitCount) splits recorded")
                    .font(.caption)
                    .foregroundStyle(PoolTheme.smoke)

                if stopwatchEngine.totalStrokes > 0 {
                    Text("\(stopwatchEngine.totalStrokes) strokes")
                        .font(.caption)
                        .foregroundStyle(PoolTheme.smoke)
                }
            }

            Spacer()

            if stopwatchEngine.splitCount > 0 {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(stopwatchEngine.splitCount)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(PoolTheme.mid)
                        .clipShape(Capsule())

                    if stopwatchEngine.averageStrokeRate > 0 {
                        Text("\(stopwatchEngine.formatStrokeRate(stopwatchEngine.averageStrokeRate)) spm")
                            .font(.caption)
                            .foregroundStyle(PoolTheme.mid)
                    }
                }
            }
        }
    }

    private var stopwatchDisplaySection: some View {
        VStack(spacing: 12) {
            Text(stopwatchEngine.displayTime)
                .font(.system(size: 80, weight: .black, design: .monospaced))
                .foregroundStyle(PoolTheme.deep)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            if stopwatchEngine.isRunning || !stopwatchEngine.splits.isEmpty {
                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text("LAP")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(PoolTheme.smoke)

                        Text(stopwatchEngine.displayLapTime)
                            .font(.system(size: 28, weight: .medium, design: .monospaced))
                            .foregroundStyle(PoolTheme.mid)
                    }

                    if stopwatchEngine.currentStrokeCount > 0 {
                        VStack(spacing: 4) {
                            Text("STR")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(PoolTheme.smoke)

                            Text("\(stopwatchEngine.currentStrokeCount)")
                                .font(.system(size: 28, weight: .medium, design: .monospaced))
                                .foregroundStyle(PoolTheme.gold)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 20)
    }

    private var stopwatchControlSection: some View {
        HStack(spacing: 16) {
            LargeTimerButton(
                title: stopwatchEngine.isRunning ? "STOP" : "START",
                icon: stopwatchEngine.isRunning ? "stop.fill" : "play.fill",
                color: stopwatchEngine.isRunning ? .red : PoolTheme.mid
            ) {
                if stopwatchEngine.isRunning {
                    stopwatchEngine.stop()
                } else {
                    stopwatchEngine.start()
                }
            }

            if stopwatchEngine.isRunning {
                LargeTimerButton(
                    title: "SPLIT",
                    icon: "flag.fill",
                    color: PoolTheme.gold
                ) {
                    stopwatchEngine.recordSplit()
                }
            } else if !stopwatchEngine.splits.isEmpty {
                LargeTimerButton(
                    title: "CONT.",
                    icon: "play.fill",
                    color: PoolTheme.mid
                ) {
                    stopwatchEngine.start()
                }
            }

            LargeTimerButton(
                title: "RESET",
                icon: "arrow.counterclockwise",
                color: PoolTheme.smoke.opacity(0.8)
            ) {
                stopwatchEngine.reset()
            }
        }
    }

    // MARK: - Stroke Counter

    private var strokeCounterSection: some View {
        VStack(spacing: 12) {
            // Instructions
            if stopwatchEngine.isRunning {
                Text("Tap to count strokes")
                    .font(.caption)
                    .foregroundStyle(PoolTheme.smoke)
            }

            // Large stroke counter tap zone
            Button {
                stopwatchEngine.recordStroke()
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(stopwatchEngine.isRunning ? PoolTheme.mid : PoolTheme.smoke)

                    if stopwatchEngine.currentStrokeCount > 0 {
                        Text("\(stopwatchEngine.currentStrokeCount)")
                            .font(.system(size: 48, weight: .black, design: .monospaced))
                            .foregroundStyle(stopwatchEngine.isRunning ? PoolTheme.deep : PoolTheme.smoke)
                    } else {
                        Text("STROKE")
                            .font(.headline)
                            .foregroundStyle(stopwatchEngine.isRunning ? PoolTheme.deep : PoolTheme.smoke)
                    }

                    if stopwatchEngine.currentStrokeRate > 0 && stopwatchEngine.isRunning {
                        Text("\(stopwatchEngine.formatStrokeRate(stopwatchEngine.currentStrokeRate)) strokes/min")
                            .font(.caption)
                            .foregroundStyle(PoolTheme.gold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(stopwatchEngine.isRunning ? PoolTheme.light.opacity(0.3) : PoolTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(!stopwatchEngine.isRunning)
        }
        .poolCard()
    }

    private var stopwatchSplitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if stopwatchEngine.splits.isEmpty {
                ContentUnavailableView(
                    "No Splits",
                    systemImage: "flag",
                    description: Text("Tap SPLIT while timing to record lap times.")
                )
                .frame(height: 150)
            } else {
                Text("Split History")
                    .font(.headline)
                    .foregroundStyle(PoolTheme.smoke)

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(stopwatchEngine.splits.reversed()) { split in
                            SplitRow(engine: stopwatchEngine, split: split)
                        }
                    }
                }
            }
        }
        .poolCard()
    }

    // MARK: - Interval View

    private var intervalView: some View {
        VStack(spacing: 24) {
            intervalHeaderSection
            intervalDisplaySection
            intervalProgressSection
            intervalControlSection
        }
    }

    private var intervalHeaderSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(intervalEngine.displayPhase)
                    .font(.headline)
                    .foregroundStyle(intervalEngine.phaseColor)

                if intervalEngine.isRunning && !intervalEngine.isCountingDown {
                    Text("Round \(intervalEngine.currentRound) of \(intervalEngine.totalRounds)")
                        .font(.caption)
                        .foregroundStyle(PoolTheme.smoke)
                }
            }

            Spacer()

            if intervalEngine.currentRound > 0 {
                Text("\(intervalEngine.currentRound)/\(intervalEngine.totalRounds)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(PoolTheme.mid)
                    .clipShape(Capsule())
            }
        }
    }

    private var intervalDisplaySection: some View {
        VStack(spacing: 12) {
            Text(intervalEngine.displayTime)
                .font(.system(size: 80, weight: .black, design: .monospaced))
                .foregroundStyle(intervalEngine.isCountingDown ? .orange : intervalEngine.phaseColor)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            if intervalEngine.isRunning || intervalEngine.totalElapsedTime > 0 {
                HStack(spacing: 8) {
                    Text("TOTAL")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(PoolTheme.smoke)

                    Text(intervalEngine.displayTotalTime)
                        .font(.system(size: 24, weight: .medium, design: .monospaced))
                        .foregroundStyle(PoolTheme.mid)
                }
            }
        }
        .padding(.vertical, 20)
    }

    private var intervalProgressSection: some View {
        VStack(spacing: 8) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(PoolTheme.light.opacity(0.3))

                    RoundedRectangle(cornerRadius: 8)
                        .fill(intervalEngine.phaseColor)
                        .frame(width: geometry.size.width * intervalEngine.progress)
                }
            }
            .frame(height: 12)

            // Interval info
            HStack {
                Text("Work: \(Int(intervalEngine.workDuration))s")
                    .font(.caption)
                    .foregroundStyle(.red)

                Spacer()

                Text("Rest: \(Int(intervalEngine.restDuration))s")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .poolCard()
    }

    private var intervalControlSection: some View {
        HStack(spacing: 16) {
            if intervalEngine.isRunning {
                if intervalEngine.isPaused {
                    LargeTimerButton(
                        title: "RESUME",
                        icon: "play.fill",
                        color: PoolTheme.mid
                    ) {
                        intervalEngine.resume()
                    }
                } else {
                    LargeTimerButton(
                        title: "PAUSE",
                        icon: "pause.fill",
                        color: .orange
                    ) {
                        intervalEngine.pause()
                    }
                }

                LargeTimerButton(
                    title: "STOP",
                    icon: "stop.fill",
                    color: .red
                ) {
                    intervalEngine.stop()
                }
            } else {
                LargeTimerButton(
                    title: "START",
                    icon: "play.fill",
                    color: PoolTheme.mid
                ) {
                    intervalEngine.start()
                }

                LargeTimerButton(
                    title: "RESET",
                    icon: "arrow.counterclockwise",
                    color: PoolTheme.smoke.opacity(0.8)
                ) {
                    intervalEngine.stop()
                }
            }
        }
    }

    // MARK: - Save Session Sheet

    private var saveSessionSheet: some View {
        SaveTimerSessionSheet(
            engine: stopwatchEngine,
            strokes: strokes,
            onSave: { stroke, poolLength, distanceUnit, distance, notes in
                saveSession(
                    stroke: stroke,
                    poolLength: poolLength,
                    distanceUnit: distanceUnit,
                    distance: distance,
                    notes: notes
                )
            },
            onCancel: { showingSaveSheet = false }
        )
    }

    private func saveSession(
        stroke: StrokeID,
        poolLength: Int,
        distanceUnit: DistanceUnit,
        distance: Int,
        notes: String?
    ) {
        guard let profile = appModel.activeProfile else { return }

        let session = TimerSession(
            userId: profile.id,
            strokeId: stroke,
            poolLength: poolLength,
            distanceUnit: distanceUnit,
            totalDistance: distance,
            splits: stopwatchEngine.splits,
            totalTime: stopwatchEngine.elapsedTime,
            notes: notes
        )

        Task {
            try? await appModel.saveTimerSession(session)
            showingSaveSheet = false
            showingSaveSuccess = true
            stopwatchEngine.reset()
        }
    }
}

// MARK: - Interval Configuration Sheet

struct IntervalConfigSheet: View {
    @Bindable var engine: IntervalEngine
    @Environment(\.dismiss) private var dismiss

    @State private var workDuration: Int = 30
    @State private var restDuration: Int = 10
    @State private var reps: Int = 8

    var body: some View {
        VStack(spacing: 0) {
            // Fixed header with buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundStyle(PoolTheme.mid)

                Spacer()

                Text("Interval Setup")
                    .font(.headline)

                Spacer()

                Button("Apply") {
                    engine.workDuration = Double(workDuration)
                    engine.restDuration = Double(restDuration)
                    engine.repetitions = reps
                    dismiss()
                }
                .foregroundStyle(PoolTheme.mid)
            }
            .padding()
            .background(PoolTheme.surface)

            ScrollView {
                VStack(spacing: 16) {
                    // Work Duration
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Work Duration")
                            .font(.subheadline)
                            .foregroundStyle(PoolTheme.smoke)

                        HStack {
                            Button {
                                workDuration = max(5, workDuration - 5)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(PoolTheme.mid)
                            }

                            Text("\(workDuration) sec")
                                .font(.title.bold())
                                .foregroundStyle(PoolTheme.deep)
                                .frame(minWidth: 80)

                            Button {
                                workDuration = min(300, workDuration + 5)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(PoolTheme.mid)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Rest Duration
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rest Duration")
                            .font(.subheadline)
                            .foregroundStyle(PoolTheme.smoke)

                        HStack {
                            Button {
                                restDuration = max(5, restDuration - 5)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(PoolTheme.mid)
                            }

                            Text("\(restDuration) sec")
                                .font(.title.bold())
                                .foregroundStyle(PoolTheme.deep)
                                .frame(minWidth: 80)

                            Button {
                                restDuration = min(120, restDuration + 5)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(PoolTheme.mid)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Repetitions
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Repetitions")
                            .font(.subheadline)
                            .foregroundStyle(PoolTheme.smoke)

                        HStack {
                            Button {
                                reps = max(1, reps - 1)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(PoolTheme.mid)
                            }

                            Text("\(reps) rounds")
                                .font(.title.bold())
                                .foregroundStyle(PoolTheme.deep)
                                .frame(minWidth: 80)

                            Button {
                                reps = min(20, reps + 1)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(PoolTheme.mid)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Summary
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Summary")
                            .font(.subheadline)
                            .foregroundStyle(PoolTheme.smoke)

                        let totalWork = Double(workDuration) * Double(reps)
                        let totalRest = Double(restDuration) * Double(reps)
                        let totalTime = totalWork + totalRest

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Work: \(formatDuration(totalWork))")
                                Text("Rest: \(formatDuration(totalRest))")
                            }
                            Spacer()
                            Text("Total: \(formatDuration(totalTime))")
                                .font(.headline)
                                .foregroundStyle(PoolTheme.mid)
                        }
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
        }
        .background(PoolTheme.surface)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if mins > 0 {
            return "\(mins)m \(secs)s"
        }
        return "\(secs)s"
    }
}

// MARK: - Save Timer Session Sheet

struct SaveTimerSessionSheet: View {
    let engine: TimerEngine
    let strokes: [(StrokeID, String)]
    let onSave: (StrokeID, Int, DistanceUnit, Int, String?) -> Void
    let onCancel: () -> Void

    @State private var stroke: StrokeID = .freestyle
    @State private var poolLength: Int = 25
    @State private var distanceUnit: DistanceUnit = .meters
    @State private var totalDistance: String = ""
    @State private var notes: String = ""
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case distance
        case notes
    }

    private var averagePace: String {
        let distance = Int(totalDistance) ?? (engine.splitCount * poolLength)
        guard distance > 0 else { return "--" }
        let pace = engine.elapsedTime / (Double(distance) / 100.0)
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return "\(minutes):\(String(format: "%02d", seconds)) / 100\(distanceUnit == .meters ? "m" : "yd")"
    }

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .foregroundStyle(PoolTheme.mid)

                Spacer()

                Text("Save Session")
                    .font(.headline)

                Spacer()

                Button("Save") {
                    if let distance = Int(totalDistance) {
                        onSave(stroke, poolLength, distanceUnit, distance, notes.isEmpty ? nil : notes)
                    }
                }
                .foregroundStyle(PoolTheme.mid)
                .disabled(totalDistance.isEmpty || Int(totalDistance) == nil)
            }
            .padding(.horizontal)
            .padding(.top)

            ScrollView {
                VStack(spacing: 16) {
                    // Stroke
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Stroke")
                            .font(.subheadline)
                            .foregroundStyle(PoolTheme.smoke)

                        HStack {
                            Button {
                                // Cycle through strokes
                                let currentIndex = strokes.firstIndex(where: { $0.0 == stroke }) ?? 0
                                let nextIndex = (currentIndex + 1) % strokes.count
                                stroke = strokes[nextIndex].0
                            } label: {
                                HStack(spacing: 8) {
                                    Text(strokes.first(where: { $0.0 == stroke })?.1 ?? "Freestyle")
                                        .font(.headline)
                                        .foregroundStyle(PoolTheme.deep)

                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption)
                                        .foregroundStyle(PoolTheme.smoke)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)

                            Spacer()
                        }
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Pool
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pool")
                            .font(.subheadline)
                            .foregroundStyle(PoolTheme.smoke)

                        HStack {
                            Text("Length")
                            Spacer()
                            HStack(spacing: 8) {
                                Button {
                                    poolLength = 25
                                } label: {
                                    Text("25")
                                        .foregroundStyle(poolLength == 25 ? .white : PoolTheme.deep)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(poolLength == 25 ? PoolTheme.mid : .clear)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)

                                Button {
                                    poolLength = 50
                                } label: {
                                    Text("50")
                                        .foregroundStyle(poolLength == 50 ? .white : PoolTheme.deep)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(poolLength == 50 ? PoolTheme.mid : .clear)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }

                            Button {
                                distanceUnit = distanceUnit == .meters ? .yards : .meters
                            } label: {
                                Text(distanceUnit == .meters ? "m" : "yd")
                                    .foregroundStyle(PoolTheme.mid)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(PoolTheme.light.opacity(0.5))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Distance
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Total Distance")
                            .font(.subheadline)
                            .foregroundStyle(PoolTheme.smoke)

                        TextField("Distance (\(distanceUnit == .meters ? "meters" : "yards"))", text: $totalDistance)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .distance)
                            .textFieldStyle(.roundedBorder)

                        Text("\(engine.splitCount) laps = \(engine.splitCount * poolLength) \(distanceUnit == .meters ? "m" : "yd")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Summary
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Session Summary")
                            .font(.subheadline)
                            .foregroundStyle(PoolTheme.smoke)

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Time: \(engine.displayTime)")
                                Text("Splits: \(engine.splitCount)")
                                if engine.totalStrokes > 0 {
                                    Text("Strokes: \(engine.totalStrokes)")
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Avg: \(averagePace)")
                                    .font(.headline)
                                    .foregroundStyle(PoolTheme.mid)
                                if engine.averageStrokeRate > 0 {
                                    Text("\(engine.formatStrokeRate(engine.averageStrokeRate)) spm")
                                        .font(.caption)
                                        .foregroundStyle(PoolTheme.gold)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Split details with stroke metrics
                    if !engine.splits.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Split Details")
                                .font(.subheadline)
                                .foregroundStyle(PoolTheme.smoke)

                            ForEach(engine.splits.reversed()) { split in
                                HStack(spacing: 8) {
                                    Text("#\(split.splitNumber)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 24, height: 24)
                                        .background(PoolTheme.mid)
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(engine.formatTime(split.lapTime))
                                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                                            .foregroundStyle(PoolTheme.deep)

                                        if split.strokeCount > 0 {
                                            HStack(spacing: 6) {
                                                Text("\(split.strokeCount) str")
                                                    .font(.caption2)
                                                    .foregroundStyle(PoolTheme.gold)

                                                Text("\(engine.formatStrokeRate(split.strokeRate)) spm")
                                                    .font(.caption2)
                                                    .foregroundStyle(PoolTheme.smoke)

                                                // Show estimated stroke length based on pool length
                                                Text("\(engine.formatStrokeLength(split.strokeLength(poolLength: poolLength))) m/st")
                                                    .font(.caption2)
                                                    .foregroundStyle(PoolTheme.smoke)
                                            }
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(PoolTheme.surface.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.subheadline)
                            .foregroundStyle(PoolTheme.smoke)

                        TextEditor(text: $notes)
                            .frame(minHeight: 60)
                            .focused($focusedField, equals: .notes)
                            .scrollContentBackground(.hidden)
                            .background(PoolTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
        }
        .background(PoolTheme.surface)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Split Row Component

struct SplitRow: View {
    let engine: TimerEngine
    let split: TimerSplit
    var poolLength: Int? = nil  // Optional: for stroke length calculation

    var body: some View {
        HStack(spacing: 12) {
            // Split number
            Text("#\(split.splitNumber)")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(PoolTheme.mid)
                .clipShape(Circle())

            // Time info
            VStack(alignment: .leading, spacing: 2) {
                Text(engine.formatTime(split.cumulativeTime))
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .foregroundStyle(PoolTheme.deep)

                HStack(spacing: 8) {
                    // Lap time
                    HStack(spacing: 4) {
                        Text("Lap:")
                            .font(.caption)
                            .foregroundStyle(PoolTheme.smoke)
                        Text(engine.formatTime(split.lapTime))
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(PoolTheme.mid)
                    }

                    // Stroke count and rate
                    if split.strokeCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "figure.pool.swim")
                                .font(.caption)
                                .foregroundStyle(PoolTheme.gold)
                            Text("\(split.strokeCount)")
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundStyle(PoolTheme.gold)

                            if split.strokeRate > 0 {
                                Text("@\(engine.formatStrokeRate(split.strokeRate))spm")
                                    .font(.caption)
                                    .foregroundStyle(PoolTheme.smoke)
                            }

                            // Stroke length if pool length provided
                            if let poolLength = poolLength, split.strokeCount > 0 {
                                Text("\(engine.formatStrokeLength(split.strokeLength(poolLength: poolLength)))m/st")
                                    .font(.caption)
                                    .foregroundStyle(PoolTheme.smoke)
                            }
                        }
                    }
                }
            }

            Spacer()

            // Best lap indicator
            if isBestLap {
                Image(systemName: "star.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(PoolTheme.gold)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(PoolTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var isBestLap: Bool {
        guard engine.splits.count > 1 else { return false }
        let minLapTime = engine.splits.map { $0.lapTime }.min()
        return split.lapTime == minLapTime
    }
}

// MARK: - Timer History View

struct TimerHistoryView: View {
    @Bindable var appModel: SwimNoteAppModel
    @Environment(\.dismiss) private var dismiss

    private var sortedSessions: [TimerSession] {
        appModel.timerSessions.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                Text("Timer History")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .foregroundStyle(PoolTheme.mid)
            }
            .padding()

            if sortedSessions.isEmpty {
                ContentUnavailableView(
                    "No Sessions",
                    systemImage: "timer",
                    description: Text("Saved timer sessions will appear here.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(sortedSessions) { session in
                            TimerSessionHistoryRow(session: session)
                                .padding(.horizontal)
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding()
                }
            }
        }
        .background(PoolTheme.surface)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Timer Session History Row

struct TimerSessionHistoryRow: View {
    let session: TimerSession
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack {
                Text(session.strokeId.rawValue.capitalized)
                    .font(.headline)
                    .foregroundStyle(PoolTheme.deep)

                Spacer()

                Text(formatTime(session.totalTime))
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundStyle(PoolTheme.mid)
            }

            // Summary stats
            HStack(spacing: 16) {
                Label {
                    Text("\(session.totalDistance) \(session.distanceUnit == .meters ? "m" : "yd")")
                } icon: {
                    Image(systemName: "ruler")
                }
                .font(.caption)
                .foregroundStyle(PoolTheme.smoke)

                Label {
                    Text("\(session.lapCount) laps")
                } icon: {
                    Image(systemName: "flag")
                }
                .font(.caption)
                .foregroundStyle(PoolTheme.smoke)

                if session.averagePace > 0 {
                    Label {
                        Text(session.formattedAveragePace + "/100" + (session.distanceUnit == .meters ? "m" : "yd"))
                    } icon: {
                        Image(systemName: "speedometer")
                    }
                    .font(.caption)
                    .foregroundStyle(PoolTheme.smoke)
                }

                if session.totalStrokes > 0 {
                    Label {
                        Text("\(session.totalStrokes) strokes")
                    } icon: {
                        Image(systemName: "figure.pool.swim")
                    }
                    .font(.caption)
                    .foregroundStyle(PoolTheme.gold)
                }
            }

            // Stroke metrics row
            if session.totalStrokes > 0 {
                HStack(spacing: 12) {
                    Text("\(String(format: "%.0f", session.averageStrokeRate)) spm")
                        .font(.caption)
                        .foregroundStyle(PoolTheme.mid)

                    Text("\(String(format: "%.2f", session.averageStrokeLength)) m/stroke")
                        .font(.caption)
                        .foregroundStyle(PoolTheme.mid)

                    Spacer()

                    // Expand button if there are splits with strokes
                    if session.splits.contains(where: { $0.strokeCount > 0 }) {
                        Button {
                            withAnimation {
                                isExpanded.toggle()
                            }
                        } label: {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.caption)
                                .foregroundStyle(PoolTheme.mid)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Pool info and date
            Text("\(session.poolLengthLabel) pool • \(session.date)")
                .font(.caption2)
                .foregroundStyle(PoolTheme.smoke)

            // Notes
            if let notes = session.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(PoolTheme.smoke)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Expanded splits with per-lap stroke metrics
            if isExpanded && !session.splits.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Split Details")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(PoolTheme.smoke)
                        .padding(.top, 4)

                    ForEach(session.splits) { split in
                        HStack(spacing: 8) {
                            Text("#\(split.splitNumber)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(PoolTheme.mid)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(formatTime(split.lapTime))
                                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                                    .foregroundStyle(PoolTheme.deep)

                                if split.strokeCount > 0 {
                                    HStack(spacing: 6) {
                                        Text("\(split.strokeCount) str")
                                            .font(.caption2)
                                            .foregroundStyle(PoolTheme.gold)

                                        Text("\(String(format: "%.0f", split.strokeRate)) spm")
                                            .font(.caption2)
                                            .foregroundStyle(PoolTheme.smoke)

                                        Text("\(String(format: "%.2f", split.strokeLength(poolLength: session.poolLength))) m/st")
                                            .font(.caption2)
                                            .foregroundStyle(PoolTheme.smoke)
                                    }
                                }
                            }

                            Spacer()

                            // Best lap indicator
                            if isBestLap(session: session, split: split) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(PoolTheme.gold)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(PoolTheme.surface.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
    }

    private func isBestLap(session: TimerSession, split: TimerSplit) -> Bool {
        guard session.splits.count > 1 else { return false }
        let minLapTime = session.splits.map { $0.lapTime }.min()
        return split.lapTime == minLapTime
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let hundredths = Int((time * 100).truncatingRemainder(dividingBy: 100))
        if minutes > 0 {
            return String(format: "%02d:%02d.%02d", minutes, seconds, hundredths)
        }
        return String(format: "%02d.%02d", seconds, hundredths)
    }
}

// MARK: - Previews

#Preview("Timer - Stopwatch") {
    NavigationStack {
        SwimTimerView(appModel: SwimNoteAppModel.bootstrap())
    }
}

#Preview("Timer - Interval Mode") {
    NavigationStack {
        SwimTimerView(appModel: SwimNoteAppModel.bootstrap())
    }
}