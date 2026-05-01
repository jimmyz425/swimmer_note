import SwiftUI

struct PersonalBestsEditor: View {
    @Bindable var appModel: SwimNoteAppModel
    @State var profile: UserProfile
    @State private var personalBests: PersonalBests
    @State private var isBeginner: Bool
    @State private var mainStroke: StrokeID?
    @State private var distancePreference: DistancePreference
    @State private var distanceUnit: DistanceUnit
    @State private var profileIconType: ProfileIconType
    @State private var profileImageData: Data?
    @State private var profileIconName: String?
    @State private var isSaving: Bool = false
    @Environment(\.dismiss) private var dismiss

    init(appModel: SwimNoteAppModel, profile: UserProfile) {
        self.appModel = appModel
        self._profile = State(initialValue: profile)
        self._personalBests = State(initialValue: profile.personalBests)
        self._isBeginner = State(initialValue: profile.personalBests.isEmpty)
        self._mainStroke = State(initialValue: profile.mainStroke)
        self._distancePreference = State(initialValue: profile.distancePreference)
        self._distanceUnit = State(initialValue: profile.preferredDistanceUnit)
        self._profileIconType = State(initialValue: profile.profileIconType)
        self._profileImageData = State(initialValue: profile.profileImageData)
        self._profileIconName = State(initialValue: profile.profileIconName)
    }

    private let strokes: [(StrokeID, String)] = [
        (.freestyle, "Freestyle"),
        (.backstroke, "Backstroke"),
        (.breaststroke, "Breaststroke"),
        (.butterfly, "Butterfly")
    ]

    private var distanceLabel: String {
        distanceUnit == .meters ? "50m" : "50yd"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    LabeledContent("Name", value: profile.name)
                    LabeledContent("Age", value: "\(profile.age)")
                    LabeledContent("Sex", value: profile.sex.rawValue.capitalized)
                }

                Section {
                    ProfileIconPicker(
                        iconType: $profileIconType,
                        imageData: $profileImageData,
                        iconName: $profileIconName,
                        name: profile.name
                    )
                } header: {
                    Text("Profile Icon")
                }

                Section("Swimming Focus") {
                    Picker("Main Stroke", selection: $mainStroke) {
                        Text("Not set").tag(nil as StrokeID?)
                        ForEach(strokes, id: \.0) { strokeId, strokeName in
                            Text(strokeName).tag(strokeId as StrokeID?)
                        }
                    }

                    Picker("Distance Preference", selection: $distancePreference) {
                        ForEach(DistancePreference.allCases, id: \.self) { dist in
                            Text(dist.displayName).tag(dist)
                        }
                    }

                    Picker("Distance Unit", selection: $distanceUnit) {
                        Text("Meters").tag(DistanceUnit.meters)
                        Text("Yards").tag(DistanceUnit.yards)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Personal Bests") {
                    Toggle("Beginner - no PBs yet", isOn: $isBeginner)
                        .onChange(of: isBeginner) { _, newValue in
                            if newValue {
                                personalBests = .empty()
                            }
                        }

                    if !isBeginner {
                        Text("Enter times in seconds for \(distanceLabel)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(strokes, id: \.0) { strokeId, strokeName in
                            HStack {
                                Text(strokeName)
                                    .font(.subheadline.bold())
                                Spacer()
                                timeField(label: distanceLabel, binding: bindingFor(strokeId, distance: distanceLabel))
                            }
                            .padding(.vertical, 4)
                        }

                        Button("Clear All Times") {
                            personalBests = .empty()
                            isBeginner = true
                        }
                        .foregroundStyle(.red)
                    }
                }

                Section("Current Level") {
                    HStack {
                        Text("Skill Level")
                        Spacer()
                        skillBadge(estimatedLevel)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveProfile() }
                        .disabled(isSaving)
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

    private var estimatedLevel: SkillLevel {
        personalBests.estimatedSkillLevel(birthday: profile.birthday, sex: profile.sex)
    }

    private func timeField(label: String, binding: Binding<TimeInterval?>) -> some View {
        HStack {
            Text(label)
                .font(.caption)
            TextField("Time", value: Binding(
                get: { binding.wrappedValue ?? 0 },
                set: { binding.wrappedValue = $0 > 0 ? $0 : nil }
            ), format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
                .keyboardType(.numbersAndPunctuation)
        }
    }

    private func bindingFor(_ strokeId: StrokeID, distance: String) -> Binding<TimeInterval?> {
        switch (strokeId, distance) {
        case (.freestyle, "50m"): return $personalBests.freestyle50m
        case (.freestyle, "50yd"): return $personalBests.freestyle50yd
        case (.backstroke, "50m"): return $personalBests.backstroke50m
        case (.backstroke, "50yd"): return $personalBests.backstroke50yd
        case (.breaststroke, "50m"): return $personalBests.breaststroke50m
        case (.breaststroke, "50yd"): return $personalBests.breaststroke50yd
        case (.butterfly, "50m"): return $personalBests.butterfly50m
        case (.butterfly, "50yd"): return $personalBests.butterfly50yd
        default: return .constant(nil)
        }
    }

    private func skillBadge(_ level: SkillLevel) -> some View {
        Text(level.rawValue.capitalized)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(skillColor(level))
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }

    private func skillColor(_ level: SkillLevel) -> Color {
        switch level {
        case .beginner: .gray
        case .intermediate: .blue
        case .advanced: .green
        case .competitive: .orange
        case .elite: .purple
        }
    }

    private func saveProfile() {
        isSaving = true
        var updated = profile
        updated.personalBests = personalBests
        updated.mainStroke = mainStroke
        updated.distancePreference = distancePreference
        updated.preferredDistanceUnit = distanceUnit
        updated.profileIconType = profileIconType
        updated.profileImageData = profileImageData
        updated.profileIconName = profileIconName
        if personalBests.updatedAt == nil && !personalBests.isEmpty {
            updated.personalBests.updatedAt = SwimNoteDateFormatting.string(from: Date())
        }

        Task {
            try? await appModel.updateProfile(updated)
            isSaving = false
            dismiss()
        }
    }
}

// MARK: - Previews

#Preview("Personal Bests Editor - Intermediate") {
    PersonalBestsEditor(
        appModel: SwimNoteAppModel.bootstrap(),
        profile: UserProfile(
            id: "preview-user",
            name: "Alex",
            birthday: "1995-06-15",
            sex: .male,
            skillLevel: .intermediate,
            weeklySessionTarget: 3,
            preferredStrokes: [.freestyle],
            mainStroke: .freestyle,
            distancePreference: .mid,
            preferredDistanceUnit: .meters,
            personalBests: PersonalBests(freestyle50m: 32.5, backstroke50m: 35.0),
            trainingGoals: [],
            createdAt: "2024-01-01T00:00:00Z",
            updatedAt: "2024-01-01T00:00:00Z"
        )
    )
}

#Preview("Personal Bests Editor - Beginner") {
    PersonalBestsEditor(
        appModel: SwimNoteAppModel.bootstrap(),
        profile: UserProfile(
            id: "preview-user",
            name: "Maya",
            birthday: "2000-03-20",
            sex: .female,
            skillLevel: .beginner,
            weeklySessionTarget: 2,
            preferredStrokes: [],
            distancePreference: .na,
            preferredDistanceUnit: .meters,
            personalBests: .empty(),
            trainingGoals: [],
            createdAt: "2024-01-01T00:00:00Z",
            updatedAt: "2024-01-01T00:00:00Z"
        )
    )
}

#Preview("Personal Bests Editor - Elite") {
    PersonalBestsEditor(
        appModel: SwimNoteAppModel.bootstrap(),
        profile: UserProfile(
            id: "preview-user",
            name: "Jordan",
            birthday: "1988-11-10",
            sex: .male,
            skillLevel: .elite,
            weeklySessionTarget: 6,
            preferredStrokes: [.butterfly, .freestyle],
            mainStroke: .butterfly,
            distancePreference: .short,
            preferredDistanceUnit: .meters,
            personalBests: PersonalBests(freestyle50m: 22.0, backstroke50m: 26.0, breaststroke50m: 28.5, butterfly50m: 24.5),
            trainingGoals: [],
            createdAt: "2024-01-01T00:00:00Z",
            updatedAt: "2024-01-01T00:00:00Z"
        )
    )
}