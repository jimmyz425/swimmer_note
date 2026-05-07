import SwiftUI

struct UserSetupView: View {
    @Bindable var appModel: SwimNoteAppModel
    @State private var name: String = ""
    @State private var birthday: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var sex: Sex = .male
    @State private var distanceUnit: DistanceUnit = .meters
    @State private var trainingTier: TrainingTier = .silver
    @State private var subTier: SubTier = .two
    @State private var profileIconType: ProfileIconType = .letter
    @State private var profileImageData: Data?
    @State private var profileIconName: String?
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?
    @State private var showTierGuide: Bool = false
    @Environment(\.dismiss) private var dismiss

    private var age: Int {
        Calendar.current.dateComponents([.year], from: birthday, to: Date()).year ?? 0
    }

    /// Computed skill level from tier selection
    private var skillLevel: SkillLevel {
        switch trainingTier {
        case .preCompetitive: return .beginner
        case .bronze:
            switch subTier {
            case .one, .two: return .beginner
            case .three: return .intermediate
            default: return .beginner
            }
        case .silver:
            switch subTier {
            case .one: return .beginner
            case .two: return .intermediate
            case .three: return .advanced
            default: return .intermediate
            }
        case .gold: return .advanced
        case .senior: return .competitive
        case .national: return .elite
        }
    }

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
                Section("Basic Information") {
                    TextField("Name", text: $name)
                        .submitLabel(.done)
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
                    // Main tier picker
                    Picker("Training Group", selection: $trainingTier) {
                        ForEach(TrainingTier.allCases, id: \.self) { tier in
                            Text(tier.displayName).tag(tier)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .onChange(of: trainingTier) { _, newTier in
                        // Reset sub-tier when main tier changes
                        subTier = newTier.defaultSubTier
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
                        // If profiles exist and we're in setup mode, transition to user selection
                        if !appModel.profiles.isEmpty && appModel.needsSetup {
                            appModel.needsSetup = false
                        }
                        appModel.showingUserSetup = false
                        dismiss()
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
        guard !name.isEmpty else { return }
        isSaving = true
        errorMessage = nil

        let birthdayString = SwimNoteDateFormatting.shortDateString(from: birthday)

        Task { @MainActor in
            do {
                _ = try await appModel.createProfile(
                    name: name,
                    birthday: birthdayString,
                    sex: sex,
                    preferredDistanceUnit: distanceUnit,
                    trainingTier: trainingTier,
                    subTier: subTier,
                    profileIconType: profileIconType,
                    profileImageData: profileImageData,
                    profileIconName: profileIconName
                )
                appModel.showingUserSetup = false
                isSaving = false
                dismiss()
            } catch {
                errorMessage = "Failed to save: \(error.localizedDescription)"
                isSaving = false
            }
        }
    }
}

// MARK: - Training Tier Guide View

struct TrainingTierGuideView: View {
    let selectedTier: TrainingTier
    let selectedSubTier: SubTier
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(TrainingTier.allCases, id: \.self) { tier in
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            // Quick stats
                            HStack(spacing: 12) {
                                Label(tier.ageRange, systemImage: "person")
                                Label(tier.timeStandardReference, systemImage: "medal")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                            // Sub-tier breakdown for tiers with sub-tiers
                            if tier.hasSubTiers {
                                Text("Sub-levels:")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)

                                ForEach(tier.availableSubTiers, id: \.self) { sub in
                                    subTierInfoRow(sub, for: tier)
                                }
                            }

                            // Full name description
                            Text(tier.fullName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    } header: {
                        HStack {
                            Text(tier.displayName)
                            if tier == selectedTier && (selectedSubTier == .none || !tier.hasSubTiers) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else if tier == selectedTier && tier.hasSubTiers {
                                Text("(\(selectedSubTier.displayName))")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Training Levels Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func subTierInfoRow(_ sub: SubTier, for tier: TrainingTier) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(subTierLabel(sub, for: tier))
                    .font(.subheadline.bold())
                if tier == selectedTier && sub == selectedSubTier {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            Text(subTierDescription(sub, for: tier))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Label(subTierWeeklyDistance(sub, for: tier), systemImage: "figure.pool.swim")
                Label(subTierPractices(sub, for: tier), systemImage: "calendar")
            }
            .font(.caption2)
            .foregroundStyle(.blue)
        }
        .padding(.vertical, 4)
    }

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
            case .one: return "Bronze 1"
            case .two: return "Bronze 2"
            case .three: return "Bronze 3"
            default: return sub.displayName
            }
        case .silver:
            switch sub {
            case .one: return "Silver 1"
            case .two: return "Silver 2"
            case .three: return "Silver 3"
            default: return sub.displayName
            }
        default: return sub.displayName
        }
    }

    private func subTierDescription(_ sub: SubTier, for tier: TrainingTier) -> String {
        switch tier {
        case .preCompetitive: return sub.preCompetitiveDescription
        case .bronze: return sub.bronzeDescription
        case .silver: return sub.silverDescription
        default: return ""
        }
    }

    private func subTierWeeklyDistance(_ sub: SubTier, for tier: TrainingTier) -> String {
        switch tier {
        case .preCompetitive: return sub.preCompetitiveWeeklyDistance
        case .bronze: return sub.bronzeWeeklyDistance
        case .silver: return sub.silverWeeklyDistance
        default: return ""
        }
    }

    private func subTierPractices(_ sub: SubTier, for tier: TrainingTier) -> String {
        switch tier {
        case .preCompetitive: return sub.preCompetitivePractices
        case .bronze: return sub.bronzePractices
        case .silver: return sub.silverPractices
        default: return ""
        }
    }
}

// MARK: - Markdown Text View

struct MarkdownText: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(parsedBlocks, id: \.self) { block in
                blockView(block)
            }
        }
    }

    private var parsedBlocks: [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var currentParagraph: [String] = []

        for line in markdown.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                if !currentParagraph.isEmpty {
                    blocks.append(.paragraph(currentParagraph.joined(separator: "\n")))
                    currentParagraph = []
                }
            } else if trimmed.hasPrefix("**") && trimmed.hasSuffix("**") {
                // Header line (bold standalone)
                if !currentParagraph.isEmpty {
                    blocks.append(.paragraph(currentParagraph.joined(separator: "\n")))
                    currentParagraph = []
                }
                let headerText = trimmed.dropFirst(2).dropLast(2)
                blocks.append(.header(String(headerText)))
            } else if trimmed.hasPrefix("- ") {
                if !currentParagraph.isEmpty {
                    blocks.append(.paragraph(currentParagraph.joined(separator: "\n")))
                    currentParagraph = []
                }
                let listItem = trimmed.dropFirst(2)
                blocks.append(.listItem(String(listItem)))
            } else {
                currentParagraph.append(line)
            }
        }

        if !currentParagraph.isEmpty {
            blocks.append(.paragraph(currentParagraph.joined(separator: "\n")))
        }

        return blocks
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .header(let text):
            Text(text)
                .font(.headline)
                .foregroundStyle(.primary)
        case .paragraph(let text):
            if let attributedString = try? AttributedString(
                markdown: text,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            ) {
                Text(attributedString)
                    .font(.body)
            } else {
                Text(text)
                    .font(.body)
            }
        case .listItem(let text):
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .font(.body)
                    .foregroundStyle(.secondary)
                if let attributedString = try? AttributedString(
                    markdown: text,
                    options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                ) {
                    Text(attributedString)
                        .font(.body)
                } else {
                    Text(text)
                        .font(.body)
                }
            }
        }
    }

    private enum MarkdownBlock: Hashable {
        case header(String)
        case paragraph(String)
        case listItem(String)
    }
}

// MARK: - Previews

#Preview("User Setup - Empty") {
    UserSetupView(appModel: SwimNoteAppModel.bootstrap())
}

#Preview("User Setup - Bronze 3") {
    let model = SwimNoteAppModel.bootstrap()
    UserSetupView(appModel: model)
}