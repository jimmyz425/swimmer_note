import Foundation

// MARK: - Embedded tier guidance (Phase 1 & 2 — no tool calls)

internal enum PlanTierGuidancePrompt {

    static func resolvedTierAndSubTier(for context: PlanContext) -> (TrainingTier, SubTier) {
        let tier = context.profile?.trainingTier ?? .silver
        let subTier = context.profile?.subTier ?? .one
        return (tier, subTier)
    }

    /// Full tier background for prompts: capabilities, time standards, zones, focus, PBs, CSS.
    static func embeddedBlock(for context: PlanContext) -> String {
        let (tier, subTier) = resolvedTierAndSubTier(for: context)
        let tierData = CombinedToolExecutor(
            contentLoader: BundleContentLoader.bundled(),
            profile: context.profile,
            notes: context.notes
        )

        var parts: [String] = []
        parts.append("""
        === TIER GUIDANCE (authoritative) ===
        Use this block for training intensity, zone mix, and speed level. When CSS is not available, derive interval targets and effort from zone definitions here — do not invent paces.
        """)

        parts.append(buildTierDescription(tier, subTier))

        parts.append("""
        
        DETAILED ZONE DISTRIBUTION (use for `tierGuidance.zoneDistribution` in Phase 1 — zone0 through zone6):
        \(formatZoneDistributionBlock(tierData.zoneDistributionForTier(tier: tier, subTier: subTier)))
        """)

        let focusLines = tierData.trainingFocusForTier(tier: tier, subTier: subTier)
        if !focusLines.isEmpty {
            parts.append("\nTRAINING FOCUS PRIORITIES:\n" + focusLines.map { "- \($0)" }.joined(separator: "\n"))
        }

        if let pbs = personalBestsSection(profile: context.profile) {
            parts.append("\n\(pbs)")
        }

        if let css = cssSection(profile: context.profile) {
            parts.append("\n\(css)")
        }

        return parts.joined(separator: "\n")
    }

    private static func formatZoneDistributionBlock(_ zones: [String: Any]) -> String {
        let keys = [
            ("zone0", "zone_0_recovery"),
            ("zone1", "zone_1_aerobic_base"),
            ("zone2", "zone_2_aerobic_endurance"),
            ("zone3", "zone_3_tempo"),
            ("zone4", "zone_4_threshold"),
            ("zone5", "zone_5_vo2max"),
            ("zone6", "zone_6_sprint"),
        ]
        var lines: [String] = []
        for (jsonKey, dictKey) in keys {
            if let value = zones[dictKey] as? String {
                lines.append("- \(jsonKey): \(value)")
            }
        }
        if let note = zones["note"] as? String, !note.isEmpty {
            lines.append("- note: \(note)")
        }
        return lines.isEmpty ? "- Use tier summary zone percentages above." : lines.joined(separator: "\n")
    }

    private static func personalBestsSection(profile: UserProfile?) -> String? {
        guard let profile else {
            return """
            PERSONAL BESTS: None on file — infer speed level from tier/sub-tier and capabilities above only.
            """
        }
        let pbs = profile.personalBests
        if pbs.isEmpty {
            return """
            PERSONAL BESTS: None recorded — infer speed from tier (\(profile.trainingTier.displayName) \(profile.subTier.displayName)) and time-standard references above.
            """
        }
        var lines: [String] = ["PERSONAL BESTS (rough speed level — prefer CSS when tested):"]
        appendPBLine(&lines, label: "50m freestyle", seconds: pbs.freestyle50m)
        appendPBLine(&lines, label: "50m backstroke", seconds: pbs.backstroke50m)
        appendPBLine(&lines, label: "50m breaststroke", seconds: pbs.breaststroke50m)
        appendPBLine(&lines, label: "50m butterfly", seconds: pbs.butterfly50m)
        appendPBLine(&lines, label: "50yd freestyle", seconds: pbs.freestyle50yd)
        appendPBLine(&lines, label: "50yd backstroke", seconds: pbs.backstroke50yd)
        appendPBLine(&lines, label: "50yd breaststroke", seconds: pbs.breaststroke50yd)
        appendPBLine(&lines, label: "50yd butterfly", seconds: pbs.butterfly50yd)
        lines.append("- Estimated skill level (from PBs): \(profile.skillLevel.rawValue.capitalized)")
        return lines.joined(separator: "\n")
    }

    private static func appendPBLine(_ lines: inout [String], label: String, seconds: TimeInterval?) {
        guard let seconds, seconds > 0 else { return }
        lines.append("- \(label): \(formatSwimTime(seconds))")
    }

    private static func formatSwimTime(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let mins = total / 60
        let secs = total % 60
        let tenths = Int((seconds - Double(total)) * 10)
        if mins > 0 {
            return String(format: "%d:%02d.%d", mins, secs, tenths)
        }
        return String(format: "%d.%02d", secs, tenths)
    }

    private static func cssSection(profile: UserProfile?) -> String? {
        guard let profile,
              let cssHistory = profile.cssHistory,
              let latest = cssHistory.latestTest else {
            return nil
        }
        return """
        CSS (Critical Swim Speed): \(latest.formattedPace)/100m — use for swimSeconds on intervals when available.
        """
    }

    /// Phase 2: pacing guidance when CSS is missing.
    static func phase2PacingGuidance(for context: PlanContext) -> String {
        let hasCSS = context.profile?.cssHistory?.latestTest != nil
        if hasCSS {
            return "Use CSS Pace from SWIMMER CONTEXT for swimSeconds. Tier guidance below applies to zone selection and rest."
        }
        return """
        CSS is NOT TESTED — do not invent absolute swimSeconds from a made-up pace.
        - Set zone on each set from TIER GUIDANCE zone distribution.
        - Put effort guidance in `notes` (e.g. "75% effort", "CSS + 10-15s/100m equivalent for this tier") using tier level and personal bests.
        - Use restSeconds from zone guidelines in tier guidance.
        """
    }
}

extension PlanContext {
    /// Pre-built tier background for LLM prompts (Phase 1 outline, Phase 2 sessions).
    public var embeddedTierGuidance: String {
        PlanTierGuidancePrompt.embeddedBlock(for: self)
    }
}
