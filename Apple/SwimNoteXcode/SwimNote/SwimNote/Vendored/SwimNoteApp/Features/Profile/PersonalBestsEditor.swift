import SwiftUI

struct PersonalBestsEditor: View {
    @Bindable var appModel: SwimNoteAppModel
    @Environment(ProfileStore.self) private var profileStore
    @State var profile: UserProfile
    @State private var name: String
    @State private var mainStroke: StrokeID?
    @State private var distancePreference: DistancePreference
    @State private var trainingTier: TrainingTier
    @State private var subTier: SubTier
    @State private var profileIconType: ProfileIconType
    @State private var profileImageData: Data?
    @State private var profileIconName: String?
    @State private var isSaving: Bool = false
    @State private var showTierGuide: Bool = false
    @Environment(\.dismiss) private var dismiss

    init(appModel: SwimNoteAppModel, profile: UserProfile) {
        self.appModel = appModel
        self._profile = State(initialValue: profile)
        self._name = State(initialValue: profile.name)
        self._mainStroke = State(initialValue: profile.mainStroke)
        self._distancePreference = State(initialValue: profile.distancePreference)
        self._trainingTier = State(initialValue: profile.trainingTier)
        self._subTier = State(initialValue: profile.trainingTier.clampedSubTier(profile.subTier))
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

    /// Tier-specific guidance text
    private var tierGuidance: String {
        switch trainingTier {
        case .preCompetitive:
            return "Pre-competitive: 2-3 practices/week, 3-7 km/week. Water comfort, basic strokes, fun."
        case .bronze:
            switch subTier {
            case .one: return "Bronze 1: 3 practices, 4.5-7.5 km/week. First year competitive, legal strokes."
            case .two: return "Bronze 2: 3-4 practices, 6-14 km/week. Working toward B times."
            case .three: return "Bronze 3: 4 practices, 10-18 km/week. Has B times, preparing for Silver."
            default: return "Bronze: 3-4 practices/week, 8-18 km/week. First B times."
            }
        case .silver:
            switch subTier {
            case .one: return "Silver 1: 4 practices, 10-16 km/week. Just got B times, transitioning."
            case .two: return "Silver 2: 4 practices, 12-20 km/week. Working on A times, aerobic engine."
            case .three: return "Silver 3: 4-5 practices, 14-28 km/week. Has A times, preparing for Gold."
            default: return "Silver: 4-5 practices/week, 15-28 km/week. A times."
            }
        case .gold: return "Gold: 5-6 practices/week, 25-40 km/week. AA times, Zone qualifiers."
        case .senior: return "Senior: 6-8 practices/week, 40-60 km/week. AAA times, Junior Nationals."
        case .national: return "National: 8-12+ practices/week, 50-80+ km/week. AAAA times, National level."
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Name", text: $name)
                        .submitLabel(.done)
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

                Section {
                    // Main tier picker
                    Picker("Training Group", selection: $trainingTier) {
                        ForEach(TrainingTier.allCases, id: \.self) { tier in
                            Text(tier.displayName).tag(tier)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .onChange(of: trainingTier) { _, newTier in
                        subTier = newTier.clampedSubTier(subTier)
                    }

                    // Sub-tier picker (only shown for tiers with sub-tiers)
                    if trainingTier.hasSubTiers {
                        Picker("Sub-Level", selection: $subTier) {
                            ForEach(trainingTier.availableSubTiers, id: \.self) { sub in
                                Text(subTierLabel(sub, for: trainingTier)).tag(sub)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }

                    Button {
                        showTierGuide = true
                    } label: {
                        HStack {
                            Label("What's my level?", systemImage: "questionmark.circle")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.blue)
                } header: {
                    Text("Training Level")
                } footer: {
                    Text(tierGuidance)
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
                }

                Section("Personal Bests") {
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
                        NavigationLink {
                            PBTrackerView(appModel: appModel)
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
                        .disabled(isSaving || name.isEmpty)
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
            .sheet(isPresented: $showTierGuide) {
                TrainingTierGuideView(selectedTier: trainingTier, selectedSubTier: subTier)
            }
        }
    }

    /// Label for sub-tier based on main tier
    private func subTierLabel(_ sub: SubTier, for tier: TrainingTier) -> String {
        switch tier {
        case .preCompetitive:
            switch sub {
            case .a: return "A - Foundations"
            case .b: return "B - Skill Building"
            case .c: return "C - Pre-Competitive"
            default: return sub.displayName
            }
        case .bronze:
            switch sub {
            case .one: return "1 - First Year"
            case .two: return "2 - Toward B Times"
            case .three: return "3 - Has B Times"
            default: return sub.displayName
            }
        case .silver:
            switch sub {
            case .one: return "1 - Early Silver"
            case .two: return "2 - Mid Silver"
            case .three: return "3 - Upper Silver"
            default: return sub.displayName
            }
        default: return sub.displayName
        }
    }

    private func saveProfile() {
        isSaving = true
        var updated = profile
        updated.name = name
        updated.mainStroke = mainStroke
        updated.distancePreference = distancePreference
        updated.trainingTier = trainingTier
        updated.subTier = subTier
        updated.profileIconType = profileIconType
        updated.profileImageData = profileImageData
        updated.profileIconName = profileIconName

        Task { @MainActor in
            try? await profileStore.updateProfile(updated)
            isSaving = false
            dismiss()
        }
    }
}

// MARK: - Previews

#Preview("Personal Bests Editor - Silver 2") {
    let model = SwimNoteAppModel.bootstrap()
    PersonalBestsEditor(
        appModel: model,
        profile: UserProfile(
            id: "preview-user",
            name: "Alex",
            birthday: "1995-06-15",
            sex: .male,
            trainingTier: .silver,
            subTier: .two,
            weeklySessionTarget: 4,
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
    .environment(model.profileStore)
}

#Preview("Personal Bests Editor - Bronze 1") {
    let model = SwimNoteAppModel.bootstrap()
    PersonalBestsEditor(
        appModel: model,
        profile: UserProfile(
            id: "preview-user",
            name: "Maya",
            birthday: "2015-03-20",
            sex: .female,
            trainingTier: .bronze,
            subTier: .one,
            weeklySessionTarget: 3,
            preferredStrokes: [],
            mainStroke: nil,
            distancePreference: .na,
            preferredDistanceUnit: .meters,
            personalBests: .empty(),
            trainingGoals: [],
            createdAt: "2024-01-01T00:00:00Z",
            updatedAt: "2024-01-01T00:00:00Z"
        )
    )
    .environment(model.profileStore)
}

#Preview("Personal Bests Editor - Senior") {
    let model = SwimNoteAppModel.bootstrap()
    PersonalBestsEditor(
        appModel: model,
        profile: UserProfile(
            id: "preview-user",
            name: "Jordan",
            birthday: "2005-11-10",
            sex: .male,
            trainingTier: .senior,
            subTier: .none,
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
    .environment(model.profileStore)
}