import SwiftUI
import UIKit

extension PlanningView {
    // MARK: - JSON Parsing Helpers

    func parseOutlineJSON(_ raw: String) throws -> WeeklyPlanOutline {
        var jsonString = raw.trimmingCharacters(in: .whitespaces)

        // Remove markdown wrapper
        if jsonString.hasPrefix("```json") {
            jsonString = jsonString.dropFirst(7).trimmingCharacters(in: .whitespaces)
        }
        if jsonString.hasPrefix("```") {
            jsonString = jsonString.dropFirst(3).trimmingCharacters(in: .whitespaces)
        }
        if jsonString.hasSuffix("```") {
            jsonString = String(jsonString.dropLast(3).trimmingCharacters(in: .whitespaces))
        }

        let decoder = JSONDecoder()

        // 1) Valid JSON from the model decodes as-is (extra root keys like `tierGuidance` are ignored).
        // 2) Outline-safe repair: no full-plan key renames or root `notes` injection (those can corrupt outline JSON).
        // 3) Full-plan repair last: helps truncated legacy payloads but can break some outline shapes.
        let candidates = [
            jsonString,
            PlanningJSONRepair.repairLLMJSON(jsonString, mode: .weeklyPlanOutline),
            PlanningJSONRepair.repairLLMJSON(jsonString, mode: .fullTrainingPlan),
        ]

        var lastData = jsonString.data(using: .utf8) ?? Data()
        var lastError: Error?

        for candidate in candidates {
            guard let data = candidate.data(using: .utf8) else { continue }
            lastData = data
            do {
                return try decoder.decode(WeeklyPlanOutline.self, from: data)
            } catch {
                lastError = error
            }
        }

        let decodingError = lastError ?? DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: [], debugDescription: "Outline JSON could not be decoded.")
        )

        if let decodingError = decodingError as? DecodingError {
            #if DEBUG
            let jsonString = String(data: lastData, encoding: .utf8) ?? ""
            print("❌ Outline JSON Decoding Error:")
            print("Raw JSON (first 500 chars): \(String(jsonString.prefix(500)))")
            switch decodingError {
            case .keyNotFound(let key, let context):
                print("Missing key: \(key.stringValue) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
            case .typeMismatch(let type, let context):
                print("Type mismatch: expected \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
            case .valueNotFound(let type, let context):
                print("Value not found: \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
            case .dataCorrupted(let context):
                let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
                print("Data corrupted at path: \(path.isEmpty ? "(root)" : path) — \(context.debugDescription)")
            @unknown default:
                print("Unknown decoding error: \(decodingError)")
            }
            #endif
            throw decodingError
        }

        throw decodingError
    }

    func parseDetailedSessionJSON(_ raw: String) throws -> DetailedSession {
        var jsonString = raw.trimmingCharacters(in: .whitespaces)

        // Remove markdown wrapper
        if jsonString.hasPrefix("```json") {
            jsonString = jsonString.dropFirst(7).trimmingCharacters(in: .whitespaces)
        }
        if jsonString.hasPrefix("```") {
            jsonString = jsonString.dropFirst(3).trimmingCharacters(in: .whitespaces)
        }
        if jsonString.hasSuffix("```") {
            jsonString = String(jsonString.dropLast(3).trimmingCharacters(in: .whitespaces))
        }

        // Repair common issues
        jsonString = PlanningJSONRepair.repairLLMJSON(jsonString)

        let decoder = JSONDecoder()
        let data = jsonString.data(using: .utf8) ?? Data()

        return try decoder.decode(DetailedSession.self, from: data)
    }

    /// Parse dry land exercises from Phase 2 JSON (if present)
    func parseDryLandFromJSON(_ raw: String) -> [MinimalDryLandExercise] {
        var jsonString = raw.trimmingCharacters(in: .whitespaces)

        // Remove markdown wrapper
        if jsonString.hasPrefix("```json") {
            jsonString = jsonString.dropFirst(7).trimmingCharacters(in: .whitespaces)
        }
        if jsonString.hasPrefix("```") {
            jsonString = jsonString.dropFirst(3).trimmingCharacters(in: .whitespaces)
        }
        if jsonString.hasSuffix("```") {
            jsonString = String(jsonString.dropLast(3).trimmingCharacters(in: .whitespaces))
        }

        // Repair common issues
        jsonString = PlanningJSONRepair.repairLLMJSON(jsonString)

        #if DEBUG
        print("🔧 parseDryLandFromJSON - repaired JSON (last 300 chars): \(String(jsonString.suffix(300)))")
        #endif

        // Extract dryLandExercises array from JSON
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            #if DEBUG
            print("🔧 parseDryLandFromJSON - failed to parse JSON object")
            #endif
            return []
        }

        #if DEBUG
        print("🔧 parseDryLandFromJSON - JSON keys: \(json.keys)")
        #endif

        guard let dryLandArray = json["dryLandExercises"] as? [[String: Any]] else {
            #if DEBUG
            print("🔧 parseDryLandFromJSON - dryLandExercises key not found or not array")
            // Try alternate key names
            if let alternate = json["dry_land_exercises"] as? [[String: Any]] {
                print("🔧 parseDryLandFromJSON - found dry_land_exercises (snake_case)")
                // Process alternate
                let decoder = JSONDecoder()
                var exercises: [MinimalDryLandExercise] = []
                for exerciseJson in alternate {
                    guard let exerciseData = try? JSONSerialization.data(withJSONObject: exerciseJson),
                          let exercise = try? decoder.decode(MinimalDryLandExercise.self, from: exerciseData) else {
                        continue
                    }
                    exercises.append(exercise)
                }
                return exercises
            }
            #endif
            return []
        }

        let decoder = JSONDecoder()
        var exercises: [MinimalDryLandExercise] = []

        for exerciseJson in dryLandArray {
            guard let exerciseData = try? JSONSerialization.data(withJSONObject: exerciseJson),
                  let exercise = try? decoder.decode(MinimalDryLandExercise.self, from: exerciseData) else {
                #if DEBUG
                print("🔧 parseDryLandFromJSON - failed to decode exercise: \(exerciseJson)")
                #endif
                continue
            }
            exercises.append(exercise)
        }

        return exercises
    }

    /// Enrich dry land exercises from unified pre-parsed JSON file using ID matching
    func enrichDryLandFromJSON(_ minimalExercises: [MinimalDryLandExercise]) -> [DryLandExercisePlan] {
        let decoder = JSONDecoder()

        // Load the unified dry land JSON file once
        let filename = "dry-land-exercises.json"

        guard let url = Bundle.main.url(forResource: filename, withExtension: nil, subdirectory: "swimming-strokes") ??
                      Bundle.main.url(forResource: filename, withExtension: nil, subdirectory: "Resources/swimming-strokes") ??
                      Bundle.main.url(forResource: String(filename.dropLast(5)), withExtension: "json") else {
            #if DEBUG
            print("🔧 enrichDryLandJSON - unified file not found: \(filename)")
            #endif
            // Return minimal exercises without enrichment
            return minimalExercises.map { minimal in
                DryLandExercisePlan(
                    exercise: minimal.exerciseId,
                    setsReps: minimal.setsReps,
                    focus: nil,
                    techniqueSupport: nil
                )
            }
        }

        guard let data = try? Data(contentsOf: url),
              let trainingData = try? decoder.decode(DryLandTrainingData.self, from: data) else {
            #if DEBUG
            print("🔧 enrichDryLandJSON - failed to decode unified file: \(filename)")
            #endif
            return minimalExercises.map { minimal in
                DryLandExercisePlan(
                    exercise: minimal.exerciseId,
                    setsReps: minimal.setsReps,
                    focus: nil,
                    techniqueSupport: nil
                )
            }
        }

        #if DEBUG
        print("🔧 enrichDryLandJSON - loaded \(trainingData.exercises.count) exercises from unified file")
        #endif

        var enriched: [DryLandExercisePlan] = []

        for minimal in minimalExercises {
            // Find matching exercise by ID
            let matchingExercise = trainingData.exercises.first { exercise in
                exercise.id == minimal.exerciseId
            }

            #if DEBUG
            if let match = matchingExercise {
                print("🔧 enrichDryLandJSON - matched ID: \(minimal.exerciseId) -> \(match.name)")
            } else {
                print("🔧 enrichDryLandJSON - SKIPPING (no match for ID): \(minimal.exerciseId)")
            }
            #endif

            // Only add matched exercises - skip if no match found
            if let exercise = matchingExercise {
                // Get stroke-specific focus points
                let focusPoints = exercise.strokeFocusPoints[minimal.stroke]
                enriched.append(DryLandExercisePlan(
                    exercise: exercise.name,  // Use canonical name from JSON
                    setsReps: minimal.setsReps,
                    focus: exercise.category,
                    techniqueSupport: focusPoints
                ))
            }
        }

        return enriched
    }

    func enrichOutlineWithDates(
        outline: WeeklyPlanOutline,
        weekStarting: Date,
        poolType: PoolType
    ) -> WeeklyPlanOutline {
        var enriched = outline
        enriched.weekStartingDate = weekStarting
        enriched.poolTypeRaw = poolType.rawValue

        // Assign day of week to each session
        let dayOffsets = PlanningSessionScheduling.dayOffsetsForSessions(count: outline.schedule.count)
        let calendar = Calendar.current

        for (index, _) in enriched.schedule.enumerated() {
            if index < dayOffsets.count {
                let (dayOffset, _) = dayOffsets[index]
                let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStarting) ?? weekStarting
                let weekday = DateFormatter.weekdayShort.string(from: date)
                enriched.schedule[index].dayOfWeek = weekday
            }
        }

        return enriched
    }

    func convertOutlineToFullPlan(_ outline: WeeklyPlanOutline) {
        // Build WeeklyTrainingPlan from outline with all detailed sessions
        var detailedSessions: [DetailedSession] = []
        for sessionOutline in outline.schedule {
            if let detailed = sessionOutline.detailedSession {
                var session = detailed
                // Assign date and time of day based on session number
                let dayOffsets = PlanningSessionScheduling.dayOffsetsForSessions(count: outline.schedule.count)
                let calendar = Calendar.current
                let sessionIndex = sessionOutline.sessionNumber - 1
                if sessionIndex < dayOffsets.count {
                    let (dayOffset, timeOfDay) = dayOffsets[sessionIndex]
                    session.scheduledDate = calendar.date(
                        byAdding: .day,
                        value: dayOffset,
                        to: weekStartingDate
                    )
                    session.timeOfDay = timeOfDay
                    session.isAssigned = true
                }
                detailedSessions.append(session)
            }
        }

        // Enrich and spread dry land exercises across all 7 days
        let dryLandToUse = outline.dryLandExercises ?? accumulatedDryLand
        let enrichedDryLand = enrichDryLandFromJSON(dryLandToUse)
        let spreadDryLand = spreadDryLandAcrossWeek(enrichedDryLand, weekStarting: weekStartingDate)

        let plan = WeeklyTrainingPlan(
            overview: outline.overview,
            schedule: outline.schedule.map { s in
                DaySchedule(
                    sessionNumber: s.sessionNumber,
                    poolSession: s.poolSession,
                    duration: s.estimatedDuration,
                    focus: s.focus,
                    dryLand: nil,
                    sessionType: s.sessionType
                )
            },
            detailedSessions: detailedSessions,
            dryLandProgram: spreadDryLand,  // Dry land enriched from markdown and spread across week
            weeklyGoals: nil,
            techniqueProgressPlan: outline.techniqueProgressPlan,
            notes: outline.notes,
            weekStartingDate: outline.weekStartingDate,
            poolTypeRaw: outline.poolTypeRaw
        )

        // Enrich with computed fields
        parsedPlan = enrichPlanWithComputedFields(
            plan: plan,
            poolType: poolType,
            profile: appModel.activeProfile
        )
        generatedPlan = "Generated from outline"  // Placeholder
        expandedSessions.insert(1)
    }

    /// Spread dry land exercises across all 7 days of the week
    func spreadDryLandAcrossWeek(_ exercises: [DryLandExercisePlan], weekStarting: Date) -> [DryLandExercisePlan] {
        var spread = exercises
        let calendar = Calendar.current

        // Create all 7 days
        let allDays = (0..<7).map { offset in
            calendar.date(byAdding: .day, value: offset, to: weekStarting) ?? weekStarting
        }

        // Distribute exercises across days (cycling if fewer days than exercises)
        for (index, _) in spread.enumerated() {
            let dayIndex = index % allDays.count
            spread[index].scheduledDate = allDays[dayIndex]
            spread[index].isAssigned = true
        }

        return spread
    }
}
