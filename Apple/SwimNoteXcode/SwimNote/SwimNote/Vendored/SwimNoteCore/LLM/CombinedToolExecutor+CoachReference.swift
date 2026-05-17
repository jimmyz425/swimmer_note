import Foundation

extension CombinedToolExecutor {
  func readCoachReference(tier: String?, section: String?) throws -> String {
    guard let content = CoachingStyleCatalog.loadContent() else {
      throw ToolError.executionError("Could not find swimming-coach-role-reference.md")
    }

    if let tierCode = tier, !tierCode.isEmpty {
      let normalized = tierCode.uppercased()
      guard let coachTier = CoachSwimmerTier(rawValue: normalized) else {
        let valid = CoachSwimmerTier.allCases.map(\.rawValue).joined(separator: ", ")
        throw ToolError.invalidParameter("tier", "\(tierCode) — use one of: \(valid)")
      }
      let tierSection = CoachingStyleCatalog.extractTierSection(content: content, tier: coachTier)
      var payload: [String: Any] = [
        "tier": coachTier.rawValue,
        "tier_name": coachTier.displayName,
        "content": tierSection,
        "planning_hint": "Blend user-selected coaching styles with this tier playbook. Choose drillSet/mainSet/secondarySet structure from Use/Avoid and signature sets — evidence drills are optional when styles call for exploration (Differential, Salo, Touretski, Bowman), not mandatory every session.",
      ]
      if let section, !section.isEmpty {
        payload["requested_section"] = section
      }
      return try encodeJSON(payload)
    }

    if let section, !section.isEmpty {
      let extracted = extractCoachReferenceSection(content: content, section: section)
      return try encodeJSON([
        "section": section,
        "content": extracted,
      ])
    }

    let indexEnd = content.range(of: "## Quick Lookup:")?.lowerBound ?? content.endIndex
    let overview = String(content[..<indexEnd]).prefix(12_000)
    return try encodeJSON([
      "note": "Call with tier='INT' (etc.) for a full tier section. Sections: decision_tree, compatibility, signature_sets, evidence_mapping.",
      "overview": String(overview),
    ])
  }

  private func extractCoachReferenceSection(content: String, section: String) -> String {
    let key = section.lowercased().replacingOccurrences(of: "_", with: " ")
    let markers: [(String, String)] = [
      ("decision_tree", "## Style Selection Decision Tree"),
      ("decision tree", "## Style Selection Decision Tree"),
      ("compatibility", "## Quick Lookup: Style → Swimmer Tier Compatibility"),
      ("signature_sets", "## Signature Sets by Coaching Style"),
      ("signature sets", "## Signature Sets by Coaching Style"),
      ("evidence_mapping", "## Evidence-Based Drill Mapping by Tier"),
      ("evidence mapping", "## Evidence-Based Drill Mapping by Tier"),
      ("never", "## What to NEVER Do"),
    ]
    for (needle, header) in markers where key.contains(needle) || needle.contains(key) {
      guard let start = content.range(of: header) else { continue }
      let tail = content[start.lowerBound...]
      if let next = tail.dropFirst(header.count).range(of: "\n## ") {
        return String(tail[..<next.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
      }
      return String(tail).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return "Unknown section '\(section)'. Try: decision_tree, compatibility, signature_sets, evidence_mapping."
  }
}
