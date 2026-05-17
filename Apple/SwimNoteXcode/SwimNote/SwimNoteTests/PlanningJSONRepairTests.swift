import Foundation
import Testing
@testable import SwimNote

struct PlanningJSONRepairTests {

    @Test("extractJSONObject finds JSON after prose prefix")
    func extractAfterProse() {
        let raw = """
        Note: Here is session 3.
        ```json
        {"sessionNumber": 3, "focus": "Freestyle"}
        ```
        """
        let extracted = PlanningJSONRepair.extractJSONObject(from: raw)
        #expect(extracted?.contains("\"sessionNumber\": 3") == true)
    }

    @Test("bestJSONPayload prefers aggregated stream when final is non-JSON")
    func bestPayloadPrefersAggregated() {
        let final = "NULL"
        let aggregated = "{\"sessionNumber\": 3, \"focus\": \"test\"}"
        let best = PlanningJSONRepair.bestJSONPayload(final: final, aggregated: aggregated)
        #expect(best == aggregated)
    }

    @Test("extractJSONObject strips leading Note line")
    func extractLeadingNote() {
        let raw = "Note: output follows\n{\"sessionNumber\": 1}"
        let extracted = PlanningJSONRepair.extractJSONObject(from: raw)
        #expect(extracted == "{\"sessionNumber\": 1}")
    }
}
