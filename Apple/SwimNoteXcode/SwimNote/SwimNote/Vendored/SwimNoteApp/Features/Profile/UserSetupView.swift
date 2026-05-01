import SwiftUI

struct UserSetupView: View {
    @Bindable var appModel: SwimNoteAppModel
    @State private var name: String = ""
    @State private var birthday: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var sex: Sex = .male
    @State private var distanceUnit: DistanceUnit = .meters
    @State private var isBeginner: Bool = false
    @State private var personalBests = PersonalBests.empty()
    @State private var profileIconType: ProfileIconType = .letter
    @State private var profileImageData: Data?
    @State private var profileIconName: String?
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?
    
    private let strokes: [(StrokeID, String)] = [
        (.freestyle, "Freestyle"),
        (.backstroke, "Backstroke"),
        (.breaststroke, "Breaststroke"),
        (.butterfly, "Butterfly")
    ]

    private var age: Int {
        Calendar.current.dateComponents([.year], from: birthday, to: Date()).year ?? 0
    }

    private var distanceLabel: String {
        distanceUnit == .meters ? "50m" : "50yd"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Name", text: $name)
                    DatePicker(
                        "Birthday",
                        selection: $birthday,
                        in: Calendar.current.date(byAdding: .year, value: -100, to: Date())!...Date(),
                        displayedComponents: .date
                    )
                    LabeledContent("Age", value: "\(age) years")
                    Picker("Sex", selection: $sex) {
                        ForEach(Sex.allCases, id: \.self) { s in
                            Text(s.rawValue.capitalized).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Preferences") {
                    Picker("Distance Unit", selection: $distanceUnit) {
                        Text("Meters").tag(DistanceUnit.meters)
                        Text("Yards").tag(DistanceUnit.yards)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    ProfileIconPicker(
                        iconType: $profileIconType,
                        imageData: $profileImageData,
                        iconName: $profileIconName,
                        name: name
                    )
                } header: {
                    Text("Profile Icon")
                } footer: {
                    Text("Choose how your profile appears in the app.")
                }

                Section("Personal Bests (Optional)") {
                    Toggle("I'm a beginner - no PBs yet", isOn: $isBeginner)
                        .onChange(of: isBeginner) { _, newValue in
                            if newValue {
                                personalBests = .empty()
                            }
                        }

                    if !isBeginner {
                        Text("Enter your best times (seconds) for \(distanceLabel)")
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
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Create Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        appModel.showingUserSetup = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProfile()
                    }
                    .disabled(name.isEmpty || isSaving)
                }
            }
            .disabled(isSaving)
            .overlay {
                if isSaving {
                    ProgressView("Creating profile...")
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
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
                .keyboardType(.decimalPad)
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

    private func saveProfile() {
        guard !name.isEmpty else { return }
        isSaving = true
        errorMessage = nil

        let birthdayString = SwimNoteDateFormatting.shortDateString(from: birthday)

        Task {
            do {
                _ = try await appModel.createProfile(
                    name: name,
                    birthday: birthdayString,
                    sex: sex,
                    preferredDistanceUnit: distanceUnit,
                    personalBests: personalBests,
                    profileIconType: profileIconType,
                    profileImageData: profileImageData,
                    profileIconName: profileIconName
                )
                appModel.showingUserSetup = false
                isSaving = false
            } catch {
                errorMessage = "Failed to save: \(error.localizedDescription)"
                isSaving = false
            }
        }
    }
}

// MARK: - Previews

#Preview("User Setup - Empty") {
    UserSetupView(appModel: SwimNoteAppModel.bootstrap())
}

#Preview("User Setup - With Data") {
    let model = SwimNoteAppModel.bootstrap()
    return UserSetupView(appModel: model)
}