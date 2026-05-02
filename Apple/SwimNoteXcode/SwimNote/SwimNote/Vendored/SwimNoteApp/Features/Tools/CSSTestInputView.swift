import SwiftUI

struct CSSTestInputView: View {
    @Bindable var appModel: SwimNoteAppModel
    @State var profile: UserProfile
    @State private var testType: CSSTestType = .twoTrial
    @State private var strokeId: StrokeID = .freestyle
    @State private var testDate: String = SwimNoteDateFormatting.todayShort()
    @State private var time200m: String = ""
    @State private var time400m: String = ""
    @State private var threeMinuteDistance: String = ""
    @State private var notes: String = ""
    @State private var isSaving: Bool = false
    @State private var calculatedCSS: CSSTestResult?
    @State private var showingResult: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Test Method") {
                    Picker("Method", selection: $testType) {
                        ForEach(CSSTestType.allCases, id: \.self) { type in
                            VStack(alignment: .leading) {
                                Text(type.displayName)
                                Text(type.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(type)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section("Test Details") {
                    DatePicker(
                        "Test Date",
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

                    Picker("Stroke", selection: $strokeId) {
                        ForEach([StrokeID.freestyle, .backstroke, .breaststroke], id: \.self) { stroke in
                            Text(stroke.rawValue.capitalized).tag(stroke)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if testType == .twoTrial {
                    Section("Time Trials") {
                        Text("Enter times in seconds")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            Text("200m")
                                .font(.subheadline.bold())
                            Spacer()
                            TextField("Time", text: $time200m)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                                .keyboardType(.numbersAndPunctuation)
                        }

                        HStack {
                            Text("400m")
                                .font(.subheadline.bold())
                            Spacer()
                            TextField("Time", text: $time400m)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                                .keyboardType(.numbersAndPunctuation)
                        }
                    }

                    Section(header: Text("Instructions"), footer: Text("Both trials should be maximal efforts with full recovery between them (15-30 minutes).")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("1. Warm up thoroughly (400-600m)")
                            Text("2. Swim 200m at maximal effort")
                            Text("3. Rest 15-30 minutes")
                            Text("4. Swim 400m at maximal effort")
                            Text("5. Record both times above")
                        }
                        .font(.subheadline)
                        .foregroundStyle(PoolTheme.smoke)
                    }
                } else {
                    Section("3-Minute Test") {
                        Text("Enter total distance swum in 3 minutes")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            Text("Distance (m)")
                                .font(.subheadline.bold())
                            Spacer()
                            TextField("meters", text: $threeMinuteDistance)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                                .keyboardType(.numbersAndPunctuation)
                        }
                    }

                    Section(header: Text("Instructions"), footer: Text("Swim at maximal effort for exactly 3 minutes. The average speed over the final 30 seconds approximates CSS.")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("1. Warm up thoroughly (400-600m)")
                            Text("2. Start at maximal effort")
                            Text("3. Maintain effort for exactly 3:00")
                            Text("4. Record total distance swum")
                        }
                        .font(.subheadline)
                        .foregroundStyle(PoolTheme.smoke)
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }

                if let css = calculatedCSS {
                    Section("Calculated Result") {
                        HStack {
                            Text("CSS Pace")
                                .font(.headline)
                            Spacer()
                            Text(css.formattedPace)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(PoolTheme.mid)
                            Text("/100m")
                                .font(.caption)
                                .foregroundStyle(PoolTheme.smoke)
                        }

                        HStack {
                            Text("Speed")
                            Spacer()
                            Text("\(css.cssMetersPerSecond, specifier: "%.2f") m/s")
                                .foregroundStyle(PoolTheme.deep)
                        }
                    }
                }
            }
            .navigationTitle("CSS Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Calculate") {
                        calculateCSS()
                    }
                    .disabled(!canCalculate)
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button("Save") {
                        saveTest()
                    }
                    .disabled(calculatedCSS == nil || isSaving)
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

    private var canCalculate: Bool {
        if testType == .twoTrial {
            let t200 = Double(time200m) ?? 0
            let t400 = Double(time400m) ?? 0
            return t200 > 0 && t400 > 0 && t400 > t200
        } else {
            return (Double(threeMinuteDistance) ?? 0) > 0
        }
    }

    private func calculateCSS() {
        if testType == .twoTrial {
            let t200 = Double(time200m) ?? 0
            let t400 = Double(time400m) ?? 0
            calculatedCSS = CSSTestResult.calculateFromTwoTrial(
                time200m: t200,
                time400m: t400,
                date: testDate,
                strokeId: strokeId,
                notes: notes.isEmpty ? nil : notes
            )
        } else {
            // For simplicity, assume final 30s distance is 1/6 of total
            // (this is a rough approximation - real test would track final 30s separately)
            let totalDist = Double(threeMinuteDistance) ?? 0
            let final30sEstimate = totalDist / 6.0  // Approximation
            calculatedCSS = CSSTestResult.calculateFromThreeMinute(
                totalDistance: totalDist,
                final30sDistance: final30sEstimate,
                date: testDate,
                strokeId: strokeId,
                notes: notes.isEmpty ? nil : notes
            )
        }
    }

    private func saveTest() {
        guard let css = calculatedCSS else { return }
        isSaving = true

        var updated = profile
        var history = updated.cssHistory ?? CSSHistory()
        history.tests.append(css)
        history.updatedAt = SwimNoteDateFormatting.string(from: Date())
        updated.cssHistory = history
        updated.updatedAt = SwimNoteDateFormatting.string(from: Date())

        Task {
            try? await appModel.updateProfile(updated)
            isSaving = false
            dismiss()
        }
    }
}

// MARK: - Previews

#Preview("CSS Test Input") {
    CSSTestInputView(
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
            personalBests: PersonalBests(freestyle50m: 32.5),
            trainingGoals: [],
            createdAt: "2024-01-01T00:00:00Z",
            updatedAt: "2024-01-01T00:00:00Z"
        )
    )
}