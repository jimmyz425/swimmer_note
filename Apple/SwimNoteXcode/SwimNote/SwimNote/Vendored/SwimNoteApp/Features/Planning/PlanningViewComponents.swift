import SwiftUI

// MARK: - Collapsible Settings Card

struct CollapsibleSettingsCard: View {
    let isExpanded: Bool
    @Binding var poolType: PoolType
    @Binding var planType: PlanType
    @Binding var weekStartingDate: Date
    let skillLevel: SkillLevel  // For filtering plan types
    let profile: UserProfile?
    let coachTiers: [CoachSwimmerTier]
    @Binding var selectedCoachingStyleIDs: Set<String>
    let isGenerating: Bool
    let onToggle: () -> Void
    let onGenerate: () -> Void
    let onLoadSample: () -> Void

    /// Filter plan types based on skill level - macrocycle phases only for Silver+ (intermediate+)
    private var availablePlanTypes: [PlanType] {
        let isSilverOrHigher = skillLevel == .intermediate ||
                               skillLevel == .advanced ||
                               skillLevel == .competitive ||
                               skillLevel == .elite
        return PlanType.allCases.filter { !$0.requiresAdvancedTier || isSilverOrHigher }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header - compact, info-dense
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    onToggle()
                }
            } label: {
                HStack(spacing: 10) {
                    // Chevron left
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(PoolTheme.mid)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))

                    Text("Plan Generator")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(PoolTheme.deep)

                    // Compact summary pills - no sessions pill, LLM determines from tier
                    HStack(spacing: 6) {
                        PoolPill(poolType.shortLabel)
                        TypePill(type: planType.rawValue)
                    }

                    Spacer()

                    // Action hint when collapsed
                    if !isExpanded {
                        Text("Tap to configure")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(PoolTheme.smoke.opacity(0.7))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expandable content
            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    // Settings Grid
                    VStack(spacing: 12) {
                        // Row 1: Pool (full width)
                        HStack {
                            Text("Pool")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(PoolTheme.smoke)
                                .tracking(0.5)

                            Spacer()

                            // Segmented buttons
                            HStack(spacing: 2) {
                                ForEach(PoolType.allCases, id: \.self) { type in
                                    Button {
                                        poolType = type
                                    } label: {
                                        Text(type.shortLabel)
                                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 5)
                                            .background(poolType == type ? PoolTheme.mid : Color.clear)
                                            .foregroundStyle(poolType == type ? .white : PoolTheme.deep)
                                            .cornerRadius(5)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(2)
                            .background(PoolTheme.surface)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(PoolTheme.border.opacity(0.5), lineWidth: 0.5)
                            )
                        }

                        Divider()
                            .background(PoolTheme.border)

                        // Note about sessions - LLM determines from tier guidance
                        HStack {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(PoolTheme.mid)
                            Text("Sessions determined by tier guidance from USA Swimming structure")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(PoolTheme.smoke.opacity(0.8))
                        }

                        Divider()
                            .background(PoolTheme.border)

                        // Row 2: Type (full width)
                        HStack {
                            Text("Type")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(PoolTheme.smoke)
                                .tracking(0.5)

                            Spacer()

                            Menu {
                                ForEach(availablePlanTypes) { type in
                                    Button {
                                        planType = type
                                    } label: {
                                        Label(type.rawValue, systemImage: type.icon)
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: planType.icon)
                                        .font(.system(size: 11, weight: .semibold))
                                    Text(planType.rawValue)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 9, weight: .bold))
                                }
                                .foregroundStyle(PoolTheme.mid)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(PoolTheme.light.opacity(0.25))
                                .cornerRadius(8)
                            }
                        }

                        // Type description
                        Text(planType.description)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(PoolTheme.smoke.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, -4)

                        Divider()
                            .background(PoolTheme.border)

                        CoachingStylesPickerSection(
                            profile: profile,
                            coachTiers: coachTiers,
                            selectedIDs: $selectedCoachingStyleIDs
                        )

                        Divider()
                            .background(PoolTheme.border)

                        // Row 3: Week (compact picker — avoid scaleEffect; it causes invalid frame warnings)
                        HStack {
                            Text("Week")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(PoolTheme.smoke)
                                .tracking(0.5)

                            Spacer(minLength: 8)

                            DatePicker("", selection: $weekStartingDate, displayedComponents: .date)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(PoolTheme.surface.opacity(0.5))
                    .cornerRadius(10)

                    // Generate Section
                    VStack(spacing: 6) {
                        // Primary button
                        Button {
                            onGenerate()
                        } label: {
                            HStack(spacing: 8) {
                                if isGenerating {
                                    ProgressView()
                                        .tint(.white)
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                Text(isGenerating ? "Generating..." : "Generate Training Plan")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [PoolTheme.mid, PoolTheme.mid.opacity(0.85)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isGenerating)
                        .animation(.easeInOut(duration: 0.15), value: isGenerating)

                        // Debug link
                        Button {
                            onLoadSample()
                        } label: {
                            Text("Load Sample Plan")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(PoolTheme.smoke)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                }
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
        .onAppear { clampPlanTypeIfNeeded() }
        .onChange(of: skillLevel) { _, _ in clampPlanTypeIfNeeded() }
        .background(PoolTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(PoolTheme.border, lineWidth: 1)
        )
        .shadow(color: PoolTheme.shadow, radius: 8, x: 0, y: 4)
    }

    private func clampPlanTypeIfNeeded() {
        guard !availablePlanTypes.contains(planType) else { return }
        planType = availablePlanTypes.first ?? .mixed
    }
}

// MARK: - Compact Pills

struct PoolPill: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(PoolTheme.mid)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(PoolTheme.light.opacity(0.25))
            .cornerRadius(5)
    }
}

struct TypePill: View {
    let type: String
    init(type: String) { self.type = type }

    var body: some View {
        Text(type)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(PoolTheme.mid)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(PoolTheme.light.opacity(0.25))
            .cornerRadius(5)
            .lineLimit(1)
            .truncationMode(.tail)
    }
}

struct SessionsPill: View {
    let count: Int
    init(count: Int) { self.count = count }

    var body: some View {
        Text("\(count)×")
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(PoolTheme.mid)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(PoolTheme.light.opacity(0.25))
            .cornerRadius(5)
    }
}
// MARK: - Session Outline Card (Phase 1)

struct SessionOutlineCard: View {
    let session: SessionOutline
    let isGenerating: Bool
    let onGenerateDetails: () -> Void

    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row - clickable to expand if details exist
            Button {
                if session.isDetailsGenerated {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }
            } label: {
                HStack(alignment: .top) {
                    // Session number badge
                    Text("#\(session.sessionNumber)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(PoolTheme.mid)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(PoolTheme.mid.opacity(0.15))
                        .cornerRadius(6)

                    // Day of week
                    if let day = session.dayOfWeek {
                        Text(day)
                            .font(.caption.bold())
                            .foregroundStyle(PoolTheme.smoke)
                    }

                    // Session name
                    Text(session.poolSession)
                        .font(.headline)
                        .foregroundStyle(PoolTheme.deep)

                    Spacer()

                    // Status badge or generate button
                    if session.isDetailsGenerated {
                        HStack(spacing: 4) {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.caption.bold())
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                            Text("Details")
                                .font(.caption.bold())
                        }
                        .foregroundStyle(.green)
                    } else {
                        Button {
                            onGenerateDetails()
                        } label: {
                            HStack(spacing: 4) {
                                if isGenerating {
                                    ProgressView()
                                        .tint(PoolTheme.mid)
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "sparkles")
                                        .font(.caption)
                                }
                                Text(isGenerating ? "..." : "Generate")
                                    .font(.caption.bold())
                            }
                            .foregroundStyle(PoolTheme.mid)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(PoolTheme.mid.opacity(0.1))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .disabled(isGenerating)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Focus description
            Text(session.focus)
                .font(.subheadline)
                .foregroundStyle(PoolTheme.smoke)

            // Session type badge
            if let sessionType = session.sessionType {
                HStack(spacing: 8) {
                    sessionTypePill(sessionType)

                    if let techFocus = session.techniqueFocus {
                        techniquePill(techFocus)
                    }
                }
            }

            // Estimated duration/distance
            HStack(spacing: 12) {
                if let duration = session.estimatedDuration {
                    Label(duration, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(PoolTheme.smoke)
                }

                if let distance = session.estimatedDistance {
                    Label(distance, systemImage: "ruler")
                        .font(.caption)
                        .foregroundStyle(PoolTheme.smoke)
                }
            }

            // Goal addressed
            if let goal = session.addressesGoal {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Addresses Goal", systemImage: "target")
                        .font(.caption.bold())
                        .foregroundStyle(PoolTheme.smoke)

                    Text(goal)
                        .font(.caption)
                        .foregroundStyle(PoolTheme.deep)
                }
            }

            // EXPANDED: Show detailed session if generated
            if isExpanded, let detailed = session.detailedSession {
                Divider()
                    .background(PoolTheme.border)

                detailedSessionPreview(detailed)
            }
        }
        .padding(12)
        .background(PoolTheme.surface)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(session.isDetailsGenerated ? Color.green.opacity(0.3) : PoolTheme.border, lineWidth: 1)
        )
    }

    // Preview of detailed session sets
    private func detailedSessionPreview(_ detailed: DetailedSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Detailed Session")
                .font(.subheadline.bold())
                .foregroundStyle(PoolTheme.mid)

            // Warm-up
            segmentPreview("Warm-up", detailed.warmUp)

            // Drill Set
            segmentPreview("Drills", detailed.drillSet)

            // Main Set
            segmentPreview("Main", detailed.mainSet)

            // Cool-down
            segmentPreview("Cool-down", detailed.coolDown)

            // Session notes
            if let notes = detailed.sessionNotes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Notes", systemImage: "note.text")
                        .font(.caption.bold())
                        .foregroundStyle(PoolTheme.smoke)

                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(PoolTheme.deep)
                }
            }
        }
    }

    private func segmentPreview(_ title: String, _ segment: SessionSegment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(PoolTheme.smoke)

                Text(segment.distance)
                    .font(.caption)
                    .foregroundStyle(PoolTheme.deep)

                if let zone = segment.zone {
                    Text("Z\(zone)")
                        .font(.caption.bold())
                        .foregroundStyle(zoneColor(zone))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(zoneColor(zone).opacity(0.15))
                        .cornerRadius(3)
                }
            }

            // Show first few sets
            if let sets = segment.sets {
                ForEach(sets.prefix(3)) { set in
                    HStack(spacing: 4) {
                        Text(set.formatted)
                            .font(.caption)
                            .foregroundStyle(PoolTheme.deep)
                    }
                }
                if sets.count > 3 {
                    Text("+\(sets.count - 3) more sets")
                        .font(.caption)
                        .foregroundStyle(PoolTheme.smoke)
                }
            } else {
                Text(segment.description)
                    .font(.caption)
                    .foregroundStyle(PoolTheme.deep)
            }
        }
    }

    private func zoneColor(_ zone: Int) -> Color {
        switch zone {
        case 0: return .gray
        case 1: return .green
        case 2: return .cyan
        case 3: return .blue
        case 4: return .orange
        case 5: return .red
        case 6: return .purple
        default: return PoolTheme.smoke
        }
    }

    private func sessionTypePill(_ type: String) -> some View {
        Text(type)
            .font(.caption.bold())
            .foregroundStyle(sessionTypeColor(type))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(sessionTypeColor(type).opacity(0.15))
            .cornerRadius(4)
    }

    private func sessionTypeColor(_ type: String) -> Color {
        switch type.lowercased() {
        case "fundamental revisit": return .orange
        case "current level": return PoolTheme.mid
        case "stretch goal": return .purple
        case "recovery": return .green
        case "endurance": return .blue
        case "technique": return PoolTheme.mid
        case "race prep": return .red
        case "speed": return .red
        default: return PoolTheme.smoke
        }
    }

    private func techniquePill(_ tech: String) -> some View {
        Text(tech)
            .font(.caption)
            .foregroundStyle(PoolTheme.deep)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(PoolTheme.light.opacity(0.2))
            .cornerRadius(4)
    }
}

// MARK: - Coaching style multi-select

struct CoachingStylesPickerSection: View {
    let profile: UserProfile?
    let coachTiers: [CoachSwimmerTier]
    @Binding var selectedIDs: Set<String>

    private var optionGroups: [(tier: CoachSwimmerTier, options: [CoachingStyleOption])] {
        CoachingStyleCatalog.optionsGroupedForStylePicker(profile: profile)
    }

    private var mappingNote: String? {
        guard let profile else { return nil }
        return CoachTierProfileMapping.matchingRow(for: profile)?.notes
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Coaching styles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PoolTheme.smoke)
                    .tracking(0.5)
                Spacer()
                if !selectedIDs.isEmpty {
                    Text("\(selectedIDs.count) selected")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PoolTheme.mid)
                }
            }

            if coachTiers.isEmpty {
                Text("Set a training profile to see style options.")
                    .font(.system(size: 11))
                    .foregroundStyle(PoolTheme.smoke.opacity(0.8))
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Coach tiers: \(coachTiers.map { $0.rawValue }.joined(separator: ", "))")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(PoolTheme.mid)
                    Text(coachTiers.map(\.displayName).joined(separator: " · "))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PoolTheme.smoke.opacity(0.75))
                    if let profile {
                        Text(profileMappingLine(profile))
                            .font(.system(size: 10))
                            .foregroundStyle(PoolTheme.smoke.opacity(0.7))
                    }
                    if let mappingNote, !mappingNote.isEmpty {
                        Text(mappingNote)
                            .font(.system(size: 10))
                            .foregroundStyle(PoolTheme.smoke.opacity(0.65))
                            .italic()
                    }
                }

                if optionGroups.isEmpty {
                    Text("Could not load styles from coach reference.")
                        .font(.system(size: 11))
                        .foregroundStyle(PoolTheme.smoke.opacity(0.8))
                } else {
                    ForEach(optionGroups, id: \.tier) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            if optionGroups.count > 1 {
                                Text(group.tier.displayName)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(PoolTheme.mid)
                                    .textCase(.uppercase)
                            }
                            ForEach(group.options) { option in
                                coachingStyleRow(option)
                            }
                        }
                    }
                }
            }
        }
    }

    private func coachingStyleRow(_ option: CoachingStyleOption) -> some View {
        let isOn = selectedIDs.contains(option.id)
        return Button {
            if isOn {
                selectedIDs.remove(option.id)
            } else {
                selectedIDs.insert(option.id)
            }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isOn ? PoolTheme.mid : PoolTheme.smoke.opacity(0.5))
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(option.styleName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(PoolTheme.deep)
                        if option.isDefaultRecommendation {
                            Text("Suggested")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(PoolTheme.mid)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(PoolTheme.light.opacity(0.35))
                                .cornerRadius(4)
                        }
                    }
                    Text(option.source)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PoolTheme.smoke.opacity(0.85))
                    Text("When to use: \(option.whenToUse)")
                        .font(.system(size: 10))
                        .foregroundStyle(PoolTheme.smoke.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(isOn ? PoolTheme.light.opacity(0.2) : PoolTheme.surface.opacity(0.6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isOn ? PoolTheme.mid.opacity(0.35) : PoolTheme.border.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func profileMappingLine(_ profile: UserProfile) -> String {
        let tier = profile.trainingTier.displayName
        let sub = profile.subTier.displayName
        let subPart = sub.isEmpty ? "" : " \(sub)"
        return "From profile: \(tier)\(subPart), age \(profile.age)"
    }
}
