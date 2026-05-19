import SwiftUI

struct TechniqueMeasurementInputView: View {
    @Bindable var appModel: SwimNoteAppModel
    @State var profile: UserProfile
    @State private var strokeId: StrokeID = .freestyle
    @State private var poolLength: Int = 25
    @State private var distanceUnit: DistanceUnit = .meters
    @State private var strokeCount: String = ""
    @State private var lapTimeSeconds: String = ""
    @State private var lapTimeHundredths: String = ""
    @State private var glideTime: String = ""
    @State private var handPosition: HandPosition? = nil
    @State private var kickPerStroke: Int? = 6
    @State private var effortZone: Int = 2
    @State private var drillContext: String = ""
    @State private var notes: String = ""
    @State private var isSaving: Bool = false
    @Environment(\.dismiss) private var dismiss

    private let strokes: [(StrokeID, String)] = [
        (.freestyle, "Freestyle"),
        (.backstroke, "Backstroke"),
        (.breaststroke, "Breaststroke"),
        (.butterfly, "Butterfly")
    ]

    // Kick options: varies by stroke
    private var kickOptions: [(Int?, String)] {
        switch strokeId {
        case .freestyle, .backstroke:
            return [
                (nil, "No kick"),
                (2, "2-beat"),
                (4, "4-beat"),
                (6, "6-beat")
            ]
        case .breaststroke, .butterfly:
            return [
                (nil, "No kick"),
                (1, "1 per stroke")
            ]
        case .im, .master:
            return [(nil, "N/A")]
        }
    }

    // Default kick for selected stroke
    private var defaultKick: Int? {
        switch strokeId {
        case .freestyle, .backstroke: return 6
        case .breaststroke, .butterfly: return 1
        default: return nil
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Stroke & Pool") {
                    Picker("Stroke", selection: $strokeId) {
                        ForEach(strokes, id: \.0) { strokeId, strokeName in
                            Text(strokeName).tag(strokeId)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text("Pool Length")
                        Spacer()
                        Picker("Length", selection: $poolLength) {
                            Text("25").tag(25)
                            Text("50").tag(50)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 100)
                    }

                    HStack {
                        Text("Unit")
                        Spacer()
                        Picker("Unit", selection: $distanceUnit) {
                            Text("Meters").tag(DistanceUnit.meters)
                            Text("Yards").tag(DistanceUnit.yards)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                    }
                }

                Section("Efficiency Metrics") {
                    // Stroke count
                    HStack {
                        Text("Stroke Count")
                        Spacer()
                        TextField("count", text: $strokeCount)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                            .keyboardType(.numberPad)
                            .submitLabel(.done)
                    }

                    // Lap time
                    HStack(spacing: 8) {
                        Text("Lap Time")
                        Spacer()
                        TextField("SS", text: $lapTimeSeconds)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                            .keyboardType(.numberPad)
                            .submitLabel(.done)
                        Text(".")
                            .foregroundStyle(PoolTheme.smoke)
                        TextField("HH", text: $lapTimeHundredths)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                            .keyboardType(.numberPad)
                            .submitLabel(.done)
                    }

                    // Glide time (optional)
                    HStack {
                        Text("Glide Time")
                        Spacer()
                        TextField("seconds", text: $glideTime)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                            .keyboardType(.decimalPad)
                            .submitLabel(.done)
                    }

                    Text("Glide time: streamline hold after push-off/dive")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Drill Variations") {
                    // Hand position
                    Picker("Hand Position", selection: $handPosition) {
                        Text("Normal (palm)").tag(HandPosition.palm as HandPosition?)
                        Text("Fist drill").tag(HandPosition.fist as HandPosition?)
                        Text("Not specified").tag(nil as HandPosition?)
                    }
                    .pickerStyle(.segmented)

                    // Kick per stroke
                    Picker("Kick Rate", selection: $kickPerStroke) {
                        ForEach(kickOptions, id: \.0) { value, label in
                            Text(label).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: strokeId) { _, _ in
                        // Reset to default kick when stroke changes
                        kickPerStroke = defaultKick
                    }
                }

                Section("Effort Level") {
                    Picker("Zone", selection: $effortZone) {
                        ForEach(0..<7, id: \.self) { zone in
                            HStack {
                                Text(zoneName(zone))
                                Spacer()
                                Text(zoneHeartRate(zone))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(zone)
                        }
                    }
                    .pickerStyle(.menu)

                    Text("Select training zone based on perceived effort")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Context") {
                    TextField("Drill context (e.g., 'before catch drill')", text: $drillContext)
                        .submitLabel(.done)

                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }

                // Calculated efficiency display
                if let parsedData = parsedMetrics {
                    Section("Calculated Efficiency") {
                        HStack {
                            Text("Stroke Rate:")
                            Spacer()
                            Text("\(Int(parsedData.strokeRate)) strokes/min")
                                .font(.headline)
                                .foregroundStyle(PoolTheme.mid)
                        }

                        HStack {
                            Text("Distance/Stroke:")
                            Spacer()
                            Text("\(parsedData.distancePerStroke, specifier: "%.2f") m")
                                .font(.headline)
                                .foregroundStyle(PoolTheme.mid)
                        }

                        HStack {
                            Text("Speed:")
                            Spacer()
                            Text("\(parsedData.speed, specifier: "%.2f") m/s")
                                .font(.headline)
                                .foregroundStyle(PoolTheme.mid)
                        }
                    }
                }
            }
            .navigationTitle("Record Measurement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveMeasurement() }
                        .disabled(parsedMetrics == nil || isSaving)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .disabled(isSaving)
            .overlay {
                if isSaving {
                    ProgressView("Saving...")
                        .padding()
                        .glassBackground(cornerRadius: 12, shadowRadius: 4)
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var parsedMetrics: (strokeRate: Double, distancePerStroke: Double, speed: Double)? {
        let count = Int(strokeCount) ?? 0
        let seconds = Int(lapTimeSeconds) ?? 0
        let hundredths = Int(lapTimeHundredths) ?? 0

        if count == 0 || (seconds == 0 && hundredths == 0) { return nil }

        let lapTime = Double(seconds) + Double(hundredths) / 100.0
        let poolLengthDouble = Double(poolLength)

        let strokeRate = Double(count) / lapTime * 60.0
        let distancePerStroke = poolLengthDouble / Double(count)
        let speed = poolLengthDouble / lapTime

        return (strokeRate, distancePerStroke, speed)
    }

    // MARK: - Helpers

    private func zoneName(_ zone: Int) -> String {
        switch zone {
        case 0: return "Zone 0 - Recovery"
        case 1: return "Zone 1 - Aerobic Base"
        case 2: return "Zone 2 - Aerobic Endurance"
        case 3: return "Zone 3 - Tempo"
        case 4: return "Zone 4 - Lactate Threshold"
        case 5: return "Zone 5 - VO2max"
        case 6: return "Zone 6 - Sprint"
        default: return "Unknown"
        }
    }

    private func zoneHeartRate(_ zone: Int) -> String {
        switch zone {
        case 0: return "<60% HRmax"
        case 1: return "60-75% HRmax"
        case 2: return "75-82% HRmax"
        case 3: return "82-88% HRmax"
        case 4: return "88-92% HRmax"
        case 5: return "92-98% HRmax"
        case 6: return "98-100% HRmax"
        default: return ""
        }
    }

    private func saveMeasurement() {
        guard parsedMetrics != nil else { return }
        isSaving = true

        let count = Int(strokeCount) ?? 0
        let seconds = Int(lapTimeSeconds) ?? 0
        let hundredths = Int(lapTimeHundredths) ?? 0
        let lapTime = Double(seconds) + Double(hundredths) / 100.0
        let glide = Double(glideTime) ?? 0

        let measurement = TechniqueMeasurement(
            userId: profile.id,
            date: SwimNoteDateFormatting.todayShort(),
            strokeId: strokeId,
            poolLength: poolLength,
            distanceUnit: distanceUnit,
            strokeCount: count,
            lapTime: lapTime,
            glideTime: glide > 0 ? glide : nil,
            handPosition: handPosition,
            kickPerStroke: kickPerStroke,
            effortZone: effortZone,
            drillContext: drillContext.isEmpty ? nil : drillContext,
            notes: notes.isEmpty ? nil : notes
        )

        Task {
            try? await appModel.saveMeasurement(measurement)
            isSaving = false
            dismiss()
        }
    }
}

// MARK: - Previews

#Preview("Measurement Input - Empty") {
    TechniqueMeasurementInputView(
        appModel: SwimNoteAppModel.bootstrap(),
        profile: UserProfile(
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
    )
}