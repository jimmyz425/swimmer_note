import SwiftUI

struct PBResultInputView: View {
    @Bindable var appModel: SwimNoteAppModel
    @State var profile: UserProfile
    @State private var strokeId: StrokeID = .freestyle
    @State private var distance: Int = 50
    @State private var courseType: CourseType = .shortCourse
    @State private var testDate: String = SwimNoteDateFormatting.todayShort()
    @State private var timeMinutes: String = ""
    @State private var timeSeconds: String = ""
    @State private var timeHundredths: String = ""
    @State private var meetName: String = ""
    @State private var notes: String = ""
    @State private var isSaving: Bool = false
    @State private var showingSuccess: Bool = false
    @Environment(\.dismiss) private var dismiss

    private let strokes: [(StrokeID, String)] = [
        (.freestyle, "Freestyle"),
        (.backstroke, "Backstroke"),
        (.breaststroke, "Breaststroke"),
        (.butterfly, "Butterfly"),
        (.im, "IM")
    ]

    private let distances = [50, 100, 200, 400, 800, 1500]

    var body: some View {
        NavigationStack {
            Form {
                Section("Event Details") {
                    Picker("Stroke", selection: $strokeId) {
                        ForEach(strokes, id: \.0) { strokeId, strokeName in
                            Text(strokeName).tag(strokeId)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Distance", selection: $distance) {
                        ForEach(distances, id: \.self) { dist in
                            Text("\(dist)m").tag(dist)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Course", selection: $courseType) {
                        ForEach(CourseType.allCases, id: \.self) { course in
                            Text(course.displayName).tag(course)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Meet Info") {
                    DatePicker(
                        "Date",
                        selection: Binding(
                            get: {
                                DateFormatter.yyyyMMdd.date(from: testDate) ?? Date()
                            },
                            set: {
                                testDate = DateFormatter.yyyyMMdd.string(from: $0)
                            }
                        ),
                        displayedComponents: .date
                    )

                    TextField("Meet Name (optional)", text: $meetName)
                        .submitLabel(.done)
                }

                Section {
                    HStack(spacing: 8) {
                        // Minutes (optional)
                        TextField("MM", text: $timeMinutes)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                            .keyboardType(.numberPad)
                            .submitLabel(.done)
                        Text(":")
                            .foregroundStyle(PoolTheme.smoke)

                        // Seconds
                        TextField("SS", text: $timeSeconds)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                            .keyboardType(.numberPad)
                            .submitLabel(.done)
                        Text(".")
                            .foregroundStyle(PoolTheme.smoke)

                        // Hundredths
                        TextField("HH", text: $timeHundredths)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                            .keyboardType(.numberPad)
                            .submitLabel(.done)
                    }

                    Text("Enter time as MM:SS.HH (e.g., 1:32.45 for 100m)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let calculatedTime = parsedTime {
                        HStack {
                            Text("Time:")
                                .font(.subheadline)
                            Spacer()
                            Text(formatTime(calculatedTime))
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(PoolTheme.mid)
                        }
                    }
                } header: {
                    Text("Time")
                } footer: {
                    Text("Tap Done above to close keyboard after entering time")
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }

                // Show previous best if exists
                if let previousBest = previousBestTime {
                    Section("Previous Best") {
                        HStack {
                            Text("Best time:")
                            Spacer()
                            Text(previousBest.formattedTime)
                                .font(.headline)
                                .foregroundStyle(PoolTheme.deep)
                        }

                        if let improvement = improvementOverPrevious {
                            HStack {
                                Text("Improvement:")
                                Spacer()
                                Text(improvement > 0 ? "-\(formatTime(improvement))" : "+\(formatTime(abs(improvement)))")
                                    .font(.headline)
                                    .foregroundStyle(improvement > 0 ? .green : .orange)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveResult() }
                        .disabled(parsedTime == nil || isSaving)
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
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var parsedTime: TimeInterval? {
        let mins = Int(timeMinutes) ?? 0
        let secs = Int(timeSeconds) ?? 0
        let hths = Int(timeHundredths) ?? 0

        if mins == 0 && secs == 0 && hths == 0 { return nil }

        return TimeInterval(mins * 60 + secs) + TimeInterval(hths) / 100.0
    }

    private var previousBestTime: PBResult? {
        guard let history = profile.pbHistory else { return nil }
        return history.bestTime(stroke: strokeId, distance: distance, courseType: courseType)
    }

    private var improvementOverPrevious: TimeInterval? {
        guard let previous = previousBestTime, let current = parsedTime else { return nil }
        return previous.time - current  // Positive = improvement (faster)
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

    private func saveResult() {
        guard let time = parsedTime else { return }
        isSaving = true

        let result = PBResult(
            date: testDate,
            strokeId: strokeId,
            distance: distance,
            time: time,
            meetName: meetName.isEmpty ? nil : meetName,
            courseType: courseType,
            notes: notes.isEmpty ? nil : notes
        )

        var updated = profile
        var history = updated.pbHistory ?? PBHistory()
        history = history.addingResult(result)
        updated.pbHistory = history
        updated.updatedAt = SwimNoteDateFormatting.string(from: Date())

        // Also update legacy PersonalBests if this is a 50m short course result
        if distance == 50 && courseType == .shortCourse {
            updateLegacyPersonalBests(&updated, result)
        }

        Task {
            try? await appModel.updateProfile(updated)
            isSaving = false
            dismiss()
        }
    }

    private func updateLegacyPersonalBests(_ profile: inout UserProfile, _ result: PBResult) {
        let pb = profile.personalBests
        let currentTime: TimeInterval?

        switch result.strokeId {
        case .freestyle:
            currentTime = pb.freestyle50m
            if currentTime == nil || result.time < currentTime! {
                profile.personalBests.freestyle50m = result.time
            }
        case .backstroke:
            currentTime = pb.backstroke50m
            if currentTime == nil || result.time < currentTime! {
                profile.personalBests.backstroke50m = result.time
            }
        case .breaststroke:
            currentTime = pb.breaststroke50m
            if currentTime == nil || result.time < currentTime! {
                profile.personalBests.breaststroke50m = result.time
            }
        case .butterfly:
            currentTime = pb.butterfly50m
            if currentTime == nil || result.time < currentTime! {
                profile.personalBests.butterfly50m = result.time
            }
        case .im, .master:
            break  // IM and Master not tracked in legacy PersonalBests
        }

        profile.personalBests.updatedAt = SwimNoteDateFormatting.string(from: Date())
    }
}

// MARK: - Previews

#Preview("PB Result Input - Empty") {
    PBResultInputView(
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

#Preview("PB Result Input - With Previous Best") {
    let model = SwimNoteAppModel.bootstrap()
    model.activeProfile = UserProfile(
        id: "preview-user",
        name: "Alex",
        birthday: "1995-06-15",
        sex: .male,
        skillLevel: .intermediate,
        weeklySessionTarget: 3,
        preferredStrokes: [.freestyle],
        personalBests: PersonalBests(freestyle50m: 34.2),
        pbHistory: PBHistory(results: [
            PBResult(date: "2024-03-01", strokeId: .freestyle, distance: 50, time: 34.2, meetName: "Sectional Meet", courseType: .shortCourse)
        ]),
        trainingGoals: [],
        createdAt: "2024-01-01T00:00:00Z",
        updatedAt: "2024-01-01T00:00:00Z"
    )
    return PBResultInputView(appModel: model, profile: model.activeProfile!)
}