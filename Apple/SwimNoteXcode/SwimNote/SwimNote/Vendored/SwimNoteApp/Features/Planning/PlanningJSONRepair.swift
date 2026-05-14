import Foundation

/// Normalizes common LLM JSON mistakes before `JSONDecoder` runs.
enum PlanningJSONRepair {
    /// Which decoding path this repair targets. Full-plan heuristics can corrupt outline-only JSON
    /// (extra root keys like `tierGuidance`, or nested objects that still use `sessions` / `goals`).
    enum Mode: Sendable {
        /// WeeklyTrainingPlan + related payloads: all renames, truncation heuristics, root `notes` injection.
        case fullTrainingPlan
        /// WeeklyPlanOutline: no full-plan key renames or root `notes` injection; still runs
        /// truncation/brace repair so a hard `max_tokens` cutoff can yield decodable JSON.
        case weeklyPlanOutline
    }

    static func repairLLMJSON(_ json: String, mode: Mode = .fullTrainingPlan) -> String {
        var repaired = json

        // Fix truncated keys: "ills" -> "drills"
        repaired = repaired.replacingOccurrences(of: "\"ills\":", with: "\"drills\":")
        repaired = repaired.replacingOccurrences(of: "\"ills\" :", with: "\"drills\" :")

        if mode == .fullTrainingPlan {
            // Fix wrong field names from LLM (WeeklyTrainingPlan schema only — do not apply to outlines)
            repaired = repaired.replacingOccurrences(of: "\"sessions\":", with: "\"detailedSessions\":")
            repaired = repaired.replacingOccurrences(of: "\"exercisePlan\":", with: "\"dryLandProgram\":")
            repaired = repaired.replacingOccurrences(of: "\"dryLand\":", with: "\"dryLandProgram\":")
            repaired = repaired.replacingOccurrences(of: "\"goals\":", with: "\"weeklyGoals\":")
        }

        // Fix numbers as strings for Int fields (sessionNumber, sessionCount)
        // Pattern: "sessionNumber": "1" -> "sessionNumber": 1
        repaired = repaired.replacingOccurrences(of: "\"sessionNumber\": \"", with: "\"sessionNumber\": ")
        repaired = repaired.replacingOccurrences(of: "\"sessionCount\": \"", with: "\"sessionCount\": ")
        // Remove trailing quote after the number
        let intPattern = #"\"(sessionNumber|sessionCount|id)": (\d+)\""#
        if let regex = try? NSRegularExpression(pattern: intPattern, options: []) {
            let range = NSRange(repaired.startIndex..., in: repaired)
            repaired = regex.stringByReplacingMatches(in: repaired, options: [], range: range, withTemplate: "\"$1\": $2")
        }

        // Fix boolean values where strings are expected (common LLM mistake)
        // poolSession: true -> "Pool Session", false -> "Rest Day"
        repaired = repaired.replacingOccurrences(of: "\"poolSession\": true", with: "\"poolSession\": \"Pool Session\"")
        repaired = repaired.replacingOccurrences(of: "\"poolSession\": false", with: "\"poolSession\": \"Rest Day\"")
        // dryLand in schedule: true -> "Dry Land", false -> "None"
        repaired = repaired.replacingOccurrences(of: "\"dryLand\": true", with: "\"dryLand\": \"Dry Land Training\"")
        repaired = repaired.replacingOccurrences(of: "\"dryLand\": false", with: "\"dryLand\": \"None\"")
        // Other string fields that might get bools
        repaired = repaired.replacingOccurrences(of: "\"focus\": true", with: "\"focus\": \"Training\"")
        repaired = repaired.replacingOccurrences(of: "\"focus\": false", with: "\"focus\": \"Rest\"")
        repaired = repaired.replacingOccurrences(of: "\"duration\": true", with: "\"duration\": \"60 min\"")
        repaired = repaired.replacingOccurrences(of: "\"duration\": false", with: "\"duration\": \"0 min\"")
        repaired = repaired.replacingOccurrences(of: "\"sessionType\": true", with: "\"sessionType\": \"Pool\"")
        repaired = repaired.replacingOccurrences(of: "\"sessionType\": false", with: "\"sessionType\": \"Rest\"")

        // Fix missing commas between array elements (common in LLM output)
        // Pattern: } \n { without comma
        repaired = repaired.replacingOccurrences(of: "}\n      {", with: "},\n      {")
        repaired = repaired.replacingOccurrences(of: "}\n    {", with: "},\n    {")
        repaired = repaired.replacingOccurrences(of: "}\n  {", with: "},\n  {")
        repaired = repaired.replacingOccurrences(of: "}\n{", with: "},\n{")

        // Truncated / malformed JSON (stream or max_tokens cut mid-string): both outline and full plan.
        // Never inject root `notes` here — that is WeeklyTrainingPlan-only (see below).
        repaired = applyTruncationAndStructureRepair(repaired)

        if mode == .fullTrainingPlan {
            // Add missing "notes" field if not present (required by WeeklyTrainingPlan)
            if !repaired.contains("\"notes\":") {
                if let lastBraceIndex = repaired.lastIndex(of: "}") {
                    let insertPosition = repaired.index(before: lastBraceIndex)
                    repaired = String(repaired[..<insertPosition]) + ",\n  \"notes\": \"\"\n}"
                }
            }
        }

        return repaired
    }

    /// Close incomplete string values and balance `[]` / `{}` so `JSONDecoder` can run after a hard cutoff.
    private static func applyTruncationAndStructureRepair(_ json: String) -> String {
        var repaired = json

        // 1. Remove incomplete field at end (e.g., `"sessionNumber": 1, "` without field name)
        if repaired.hasSuffix("\"") || repaired.hasSuffix(", \"") {
            if let lastCommaIndex = repaired.lastIndex(of: ",") {
                let prefix = String(repaired[..<lastCommaIndex])
                let suffix = String(repaired[lastCommaIndex...])
                if suffix.contains("\""), !suffix.contains(":") {
                    repaired = prefix
                }
            }
        }

        // 2. Close incomplete string value at end (e.g. `"weekFocus": "…` with no closing quote)
        let lastQuotePattern = #"[a-zA-Z][a-zA-Z0-9_]*\": \"[^\"]*$"#
        if let regex = try? NSRegularExpression(pattern: lastQuotePattern, options: []) {
            let range = NSRange(repaired.startIndex..., in: repaired)
            if let match = regex.firstMatch(in: repaired, options: [], range: range) {
                let matchRange = Range(match.range, in: repaired)!
                let keyMatch = String(repaired[matchRange])
                if let colonIndex = keyMatch.firstIndex(of: ":") {
                    let keyPart = String(keyMatch[..<colonIndex])
                    repaired = repaired.replacingOccurrences(of: keyMatch, with: keyPart + ": \"\"")
                }
            }
        }

        // 3. Balance brackets (arrays)
        let openBrackets = repaired.filter { $0 == "[" }.count
        let closeBrackets = repaired.filter { $0 == "]" }.count
        if openBrackets > closeBrackets {
            repaired += String(repeating: "]", count: openBrackets - closeBrackets)
        }

        // 4. Balance braces (objects)
        let openBraces = repaired.filter { $0 == "{" }.count
        let closeBraces = repaired.filter { $0 == "}" }.count
        if openBraces > closeBraces {
            repaired += String(repeating: "}", count: openBraces - closeBraces)
        }

        // 5. Trailing commas before `]` / `}`
        repaired = repaired.replacingOccurrences(of: ",]", with: "]")
        repaired = repaired.replacingOccurrences(of: ",}", with: "}")

        return repaired
    }
}
