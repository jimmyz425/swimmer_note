import Foundation

// MARK: - Plan context coaching styles

extension PlanContext {
    /// Coach-reference tier codes inferred from profile (YB, INT, etc.).
    public var coachSwimmerTiers: [CoachSwimmerTier] {
        CoachTierProfileMapping.resolve(profile: profile)
    }

    public var coachTierMappingSummary: String {
        CoachTierProfileMapping.mappingSummary(for: profile)
    }

    public var selectedCoachingStyles: [CoachingStyleOption] {
        let pickerOptions = CoachingStyleCatalog.optionsForStylePicker(profile: profile)
        let selected = pickerOptions.filter { selectedCoachingStyleIDs.contains($0.id) }
        if !selected.isEmpty { return selected }
        return pickerOptions.filter(\.isDefaultRecommendation)
    }

    /// Embedded block for Phase 1 / Phase 2 prompts.
    public var embeddedCoachingStyleGuidance: String {
        let tiers = coachSwimmerTiers
        let tierLine = tiers.map { "\($0.rawValue) (\($0.displayName))" }.joined(separator: ", ")
        let styles = selectedCoachingStyles
        var lines: [String] = [
            "=== COACHING STYLES (swimming-coach-role-reference.md) ===",
            coachTierMappingSummary,
            "Coach tier codes for read_coach_reference: \(tierLine)",
        ]
        if styles.isEmpty {
            let pickerTier = CoachTierProfileMapping.coachTiersForStylePicker(profile: profile).first?.rawValue ?? "INT"
            lines.append("No styles selected — call read_coach_reference(tier=\"\(pickerTier)\") and pick 1–2 styles that fit the session.")
        } else {
            lines.append("User-selected styles (blend across the week; assign per session as appropriate):")
            for style in styles {
                lines.append("- \(style.styleName) [\(style.tier.rawValue) option \(style.optionLetter)] — \(style.source). When to use: \(style.whenToUse)")
            }
        }
        lines.append("")
        lines.append(sessionStructureGuidance)
        return lines.joined(separator: "\n")
    }

    private var sessionStructureGuidance: String {
        """
        SESSION STRUCTURE (LLM decides — not fixed templates):
        - warmUp / coolDown: always present; match coaching style (playful games for YB/YD; aerobic build for distance styles).
        - drillSet: technique or signature work — get_technique_drills for stroke files; OR signature sets from read_coach_reference; playful/differential games for youth tiers. Volume share follows style (often 15–40%, not always 20%).
        - secondarySet (OPTIONAL): include only when it serves the selected style(s). Evidence-based drills (read_evidence_drills) fit Differential Learning, Salo, Touretski, Bowman race-prep — omit for Playful Learning, pure Reese consistency weeks, or when drillSet already covers technique. When used: one evidence drill code, one JSON set per table row.
        - mainSet: primary training block — Reese Texas 100s, Bowman negative splits, Salo stroke-rate sets, McKeever choice sets, short playful bursts for youth, etc. Match zones to tier guidance and plan type.
        Tools: read_coach_reference(tier="\(coachSwimmerTiers.first?.rawValue ?? "INT")") for Use/Avoid/signature sets; read_evidence_drills when secondarySet uses research drills; get_technique_drills for standard drillSet.
        """
    }
}
