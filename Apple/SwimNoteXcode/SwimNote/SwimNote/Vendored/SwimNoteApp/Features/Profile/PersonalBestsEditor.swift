import SwiftUI

struct PersonalBestsEditor: View {
    @Bindable var appModel: SwimNoteAppModel
    @State var profile: UserProfile
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

                Section("Current Level") {
                    HStack {
                        Text("Skill Level")
                        Spacer()
                        skillBadge(profile.skillLevel)
                    }

                    if let pbHistory = profile.pbHistory, !pbHistory.isEmpty {
                        NavigationLink {
                            PBTrackerView(appModel: appModel)
                        } label: {
                            HStack {
                                Image(systemName: "medal")
                                    .foregroundStyle(PoolTheme.mid)
                                Text("Manage Personal Bests")
                                    .foregroundStyle(PoolTheme.deep)
                                Spacer()
                                Text("\(pbHistory.currentBests().count) events")
                                    .font(.caption)
                                    .foregroundStyle(PoolTheme.smoke)
                            }
                        }
                    } else {
                        Button {
                            // Will open PBTrackerView where user can add results
                        } label: {
                            HStack {
                                Image(systemName: "medal")
                                    .foregroundStyle(PoolTheme.mid)
                                Text("Add Personal Bests")
                                    .foregroundStyle(PoolTheme.deep)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(PoolTheme.smoke)
                            }
                        }
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

    private func skillBadge(_ level: SkillLevel) -> some View {
        Text(level.displayName)
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
        updated.mainStroke = mainStroke
        updated.distancePreference = distancePreference
        updated.preferredDistanceUnit = distanceUnit
        updated.profileIconType = profileIconType
        updated.profileImageData = profileImageData
        updated.profileIconName = profileIconName

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