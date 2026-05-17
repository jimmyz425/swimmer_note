import Foundation

// MARK: - Plan context coaching styles

extension PlanContext {
    /// The swimmer's TrainingTier from the profile (nil → .silver fallback).
    public var trainingTierForPlanning: TrainingTier {
        profile?.trainingTier ?? .silver
    }

    public var selectedCoachingStyles: [CoachingStyleOption] {
        let pickerOptions = CoachingStyleCatalog.optionsForStylePicker(profile: profile)
        let selected = pickerOptions.filter { selectedCoachingStyleIDs.contains($0.id) }
        if !selected.isEmpty { return selected }
        return pickerOptions.filter(\.isDefaultRecommendation)
    }

    /// Embedded block for Phase 1 / Phase 2 prompts.
    public var embeddedCoachingStyleGuidance: String {
        let tier = trainingTierForPlanning
        let styles = selectedCoachingStyles
        var lines: [String] = [
            "=== COACHING STYLES (swimming-coach-role-reference.md) ===",
            "Swimmer tier: \(tier.displayName) (\(tier.fullName))",
        ]
        if styles.isEmpty {
            lines.append("No styles selected — call read_coach_reference(tier=\"\(tier.rawValue)\") and pick 1–2 styles that fit the session.")
        } else {
            lines.append("User-selected styles (blend across the week; assign per session as appropriate):")
            for style in styles {
                lines.append("- \(style.styleName) [\(style.tier.displayName) option \(style.optionLetter)] — \(style.source). When to use: \(style.whenToUse)")
            }
        }
        lines.append("")
        lines.append(sessionStructureGuidance)
        return lines.joined(separator: "\n")
    }

    private var sessionStructureGuidance: String {
        let tier = trainingTierForPlanning
        return """
        SESSION STRUCTURE (LLM decides — not fixed templates):
        - warmUp / coolDown: always present; match coaching style (playful games for Pre-Competitive; aerobic build for distance styles).
        - drillSet: technique or signature work — get_technique_drills for stroke files; OR signature sets from read_coach_reference; playful/differential games for youth tiers. Volume share follows style (often 15–40%, not always 20%).
        - secondarySet (OPTIONAL): include only when it serves the selected style(s). Evidence-based drills (read_evidence_drills) fit Differential Learning, Salo, Touretski, Bowman race-prep — omit for Playful Learning, pure Reese consistency weeks, or when drillSet already covers technique. When used: one evidence drill code, one JSON set per table row.
        - mainSet: primary training block — Reese Texas 100s, Bowman negative splits, Salo stroke-rate sets, McKeever choice sets, short playful bursts for youth, etc. Match zones to tier guidance and plan type.
        Tools: read_coach_reference(tier="\(tier.rawValue)") for Use/Avoid/signature sets; read_evidence_drills when secondarySet uses research drills; get_technique_drills for standard drillSet.
        """
    }
}
