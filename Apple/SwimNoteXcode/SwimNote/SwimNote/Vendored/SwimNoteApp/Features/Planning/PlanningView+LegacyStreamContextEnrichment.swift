import SwiftUI
import UIKit

extension PlanningView {
    func generatePlan() async {
        guard let config = appModel.llmConfiguration else {
            errorMessage = "Configure LLM provider in Settings first"
            return
        }

        // Load API key from Keychain
        let apiKey: String
        do {
            guard let key = try credentialStore.load(account: config.apiKeyReference) else {
                errorMessage = "API key not found. Re-save settings in Settings tab."
                return
            }
            apiKey = key
        } catch {
            errorMessage = "Could not load API key: \(error.localizedDescription)"
            return
        }

        isGenerating = true
        errorMessage = nil
        generationStreamPreview = ""

        // Get strategy for selected plan type
        let strategy = PlanStrategyFactory.strategy(for: planType)

        // Build plan context from swimmer data
        let planContext = buildPlanContext(targetWeek: weekStartingDate)

        // Increase timeout for plan generation (long prompt + multiple tool calls)
        let planConfig: LLMConfiguration
        do {
            planConfig = try LLMConfiguration(
                provider: config.provider,
                apiKeyReference: config.apiKeyReference,
                baseURL: config.baseURL,
                modelName: config.modelName,
                timeoutSeconds: 300,  // 5 minutes for plan generation with more sessions
                maxRetries: config.maxRetries
            )
        } catch {
            planConfig = config  // Use original if modification fails
        }

        // Use tool calling conversation to let LLM read technique files
        let conversation = ToolCallingConversation(
            configuration: planConfig,
            apiKey: apiKey,
            executor: appModel.createToolExecutor(referenceDate: weekStartingDate)
        )

        do {
            let rawOutput = try await streamToolConversationToString(
                conversation: conversation,
                systemRole: strategy.buildSystemRole(),
                userPrompt: strategy.buildUserPrompt(context: planContext),
                tools: AllTools.all,
                maxIterations: 64,
                maxTokens: 16384
            )

            generatedPlan = rawOutput
            var plan = try parsePlanJSON(rawOutput)
            plan = enrichPlanWithComputedFields(plan: plan, poolType: poolType, profile: appModel.activeProfile)
            parsedPlan = plan
            savedStatus = nil // Reset save status when new plan generated
        } catch LLMServiceError.maxIterationsReached {
            errorMessage = "Plan generation took too long (50 iterations). Try with fewer sessions."
        } catch {
            errorMessage = "Failed to generate plan: \(error.localizedDescription)"
        }

        isGenerating = false
        generationStreamPreview = ""
    }

    // MARK: - P2-2G streaming helpers

    /// Streams a single-turn chat completion (no tools), updates `generationStreamPreview`, returns assembled text.
    func streamNonToolCompletionToString(
        request: LLMRequest,
        configuration: LLMConfiguration,
        apiKey: String
    ) async throws -> String {
        var aggregated = ""
        var terminal: String?
        let stream = llmClient.completeWithToolsStream(request, configuration: configuration, apiKey: apiKey)
        for try await event in stream {
            switch event {
            case .contentDelta(let s):
                aggregated += s
                generationStreamPreview = String(aggregated.suffix(1200))
            case .finished(let response):
                if !response.hasToolCalls, let content = response.content, !content.isEmpty {
                    terminal = content
                }
            case .toolCallDelta, .usage:
                break
            }
        }
        if let terminal, !terminal.isEmpty { return terminal }
        if !aggregated.isEmpty { return aggregated }
        throw LLMServiceError.invalidResponse
    }

    /// Streams `ToolCallingConversation` until a non-tool assistant turn completes; updates `generationStreamPreview`.
    func streamToolConversationToString(
        conversation: ToolCallingConversation,
        systemRole: String,
        userPrompt: String,
        tools: [Tool],
        maxIterations: Int,
        maxTokens: Int?
    ) async throws -> String {
        var aggregated = ""
        var lastFinalText: String?
        let stream = conversation.runStreaming(
            systemRole: systemRole,
            userPrompt: userPrompt,
            tools: tools,
            maxIterations: maxIterations,
            maxTokens: maxTokens
        )
        for try await event in stream {
            switch event {
            case .contentDelta(let s):
                aggregated += s
                generationStreamPreview = String(aggregated.suffix(2000))
            case .finished(let response):
                if !response.hasToolCalls {
                    if let content = response.content, !content.isEmpty {
                        lastFinalText = content
                    } else if let reasoning = response.reasoningContent {
                        // DeepSeek V4 thinking mode: JSON may live in reasoning_content (mirrors `ToolCallingConversation.run`).
                        let trimmed = reasoning.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") || trimmed.hasPrefix("```") {
                            lastFinalText = reasoning
                        }
                    }
                }
            case .toolCallDelta, .usage:
                break
            }
        }
        if let lastFinalText, !lastFinalText.isEmpty { return lastFinalText }
        if !aggregated.isEmpty { return aggregated }
        throw LLMServiceError.invalidResponse
    }

    func buildPlanContext(targetWeek: Date) -> PlanContext {
        // Analyze stroke balance from recent notes
        let recentNotes = Array(appModel.notes.sorted { $0.date > $1.date }.prefix(14))
        let strokeBalance = analyzeStrokeBalance(recentNotes)

        // Analyze goal progress
        let goalProgress = analyzeGoalProgressInfo(appModel.notes)

        // Extract individual sessions from past plans within the 2-week window before target week
        let twoWeekCutoff = Calendar.current.date(byAdding: .weekOfYear, value: -2, to: targetWeek) ?? targetWeek
        var pastSessions: [String] = []
        var uniqueTechRefs: Set<String> = []
        let allPlans = appModel.weeklyPlans.sorted { $0.weekStartingDate ?? Date.distantPast > $1.weekStartingDate ?? Date.distantPast }
        for plan in allPlans {
            guard let weekStart = plan.weekStartingDate else { continue }
            guard weekStart < targetWeek else { continue }
            let sessionCount = plan.schedule.count
            let dayOffsets = PlanningSessionScheduling.computeDayOffsets(count: sessionCount)
            for (idx, daySchedule) in plan.schedule.enumerated() {
                var date = weekStart
                if idx < dayOffsets.count {
                    let offset = dayOffsets[idx].dayOffset
                    date = Calendar.current.date(byAdding: .day, value: offset, to: weekStart) ?? weekStart
                }
                guard date >= twoWeekCutoff && date < targetWeek else { continue }
                let dateLabel = SwimNoteDateFormatting.shortDateString(from: date)
                var line = "\(dateLabel) Session \(daySchedule.sessionNumber): \(daySchedule.poolSession) — \(daySchedule.focus)"
                if let dur = daySchedule.duration { line += " (\(dur))" }
                if let type = daySchedule.sessionType { line += " [\(type)]" }
                pastSessions.append(line)
            }
            // Collect technique file references from detailed sessions
            for session in plan.detailedSessions {
                if let techRef = session.techniqueFileRef {
                    uniqueTechRefs.insert(techRef)
                }
            }
        }

        // Load technique content (key focus + common mistakes) for unique references
        var pastTechniqueSections: [String] = []
        let parser = TechniqueMarkdownParser()
        for techRef in uniqueTechRefs.sorted() {
            let md = contentStore.markdown(filename: techRef)
            let parsed = parser.parse(filename: techRef, rawContent: md)
            var content = ""
            if !parsed.keyPoints.isEmpty {
                content += parsed.keyPoints.joined(separator: "\n")
            }
            if !parsed.commonMistakes.isEmpty {
                if !content.isEmpty { content += "\n" }
                content += parsed.commonMistakes.joined(separator: "\n")
            }
            if !content.isEmpty {
                pastTechniqueSections.append("--- \(techRef) ---\n\(content)")
            }
        }

        // Debug: Log context data
        #if DEBUG
        print("[PlanContext] Profile: \(appModel.activeProfile?.id ?? "none")")
        print("[PlanContext] Target week: \(SwimNoteDateFormatting.shortDateString(from: targetWeek))")
        print("[PlanContext] Two-week cutoff: \(SwimNoteDateFormatting.shortDateString(from: twoWeekCutoff))")
        print("[PlanContext] Past plans count: \(allPlans.count)")
        for plan in allPlans {
            let weekDate = plan.weekStartingDate.map { SwimNoteDateFormatting.shortDateString(from: $0) } ?? "nil"
            print("[PlanContext] Plan week=\(weekDate) focus=\(plan.overview.weekFocus) sessions=\(plan.schedule.count)")
        }
        print("[PlanContext] Filtered past sessions: \(pastSessions.count)")
        print("[PlanContext] Unique technique files: \(uniqueTechRefs.count)")
        #endif

        return PlanContext(
            profile: appModel.activeProfile,
            notes: recentNotes,
            pastSessions: pastSessions,
            pastTechniqueSections: pastTechniqueSections,
            targetWeek: targetWeek,
            poolType: poolType,
            strokeBalance: strokeBalance,
            goalProgress: goalProgress
        )
    }

    func analyzeStrokeBalance(_ notes: [TrainingNote]) -> [StrokeBalanceInfo] {
        var counts: [StrokeID: Int] = [:]
        for note in notes {
            for stroke in note.strokeFocus {
                counts[stroke, default: 0] += 1
            }
        }
        let total = max(counts.values.reduce(0, +), 1)
        return StrokeID.allCases.filter { $0 != .im && $0 != .master }.map { stroke in
            StrokeBalanceInfo(
                stroke: stroke.rawValue,
                sessions: counts[stroke] ?? 0,
                percentage: Int((Double(counts[stroke] ?? 0) / Double(total)) * 100)
            )
        }.sorted { $0.sessions > $1.sessions }
    }

    func analyzeGoalProgressInfo(_ notes: [TrainingNote]) -> GoalProgressInfo {
        var achieved: [GoalSummary] = []
        var struggling: [GoalSummary] = []
        var inProgress: [GoalSummary] = []
        var seenIds: Set<String> = []

        for note in notes.sorted(by: { $0.date > $1.date }) {
            for goal in note.goals {
                if seenIds.contains(goal.id) { continue }
                seenIds.insert(goal.id)

                let summary = GoalSummary(
                    stroke: goal.strokeId?.rawValue,
                    description: goal.description
                )

                switch goal.status {
                case .achieved:
                    if achieved.count < 3 { achieved.append(summary) }
                case .unableToAchieve:
                    if struggling.count < 3 { struggling.append(summary) }
                case .inProgress, .planned:
                    if inProgress.count < 5 { inProgress.append(summary) }
                }
            }
        }

        return GoalProgressInfo(achieved: achieved, struggling: struggling, inProgress: inProgress)
    }

    func parsePlanJSON(_ raw: String) throws -> WeeklyTrainingPlan {
        // Extract JSON from response (may have markdown wrapper)
        var jsonString = raw.trimmingCharacters(in: .whitespaces)

        // Remove markdown code block wrapper if present
        if jsonString.hasPrefix("```json") {
            jsonString = jsonString.dropFirst(7).trimmingCharacters(in: .whitespaces)
        }
        if jsonString.hasPrefix("```") {
            jsonString = jsonString.dropFirst(3).trimmingCharacters(in: .whitespaces)
        }
        if jsonString.hasSuffix("```") {
            jsonString = String(jsonString.dropLast(3).trimmingCharacters(in: .whitespaces))
        }

        // Repair common LLM JSON typos
        jsonString = PlanningJSONRepair.repairLLMJSON(jsonString)

        let decoder = JSONDecoder()
        let data = jsonString.data(using: .utf8) ?? Data()

        do {
            return try decoder.decode(WeeklyTrainingPlan.self, from: data)
        } catch let decodingError as DecodingError {
            // Provide detailed error info for debugging
            #if DEBUG
            print("❌ JSON Decoding Error:")
            print("Raw JSON (first 500 chars): \(String(jsonString.prefix(500)))")
            switch decodingError {
            case .keyNotFound(let key, let context):
                print("Missing key: \(key.stringValue) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                print("Debug description: \(context.debugDescription)")
            case .typeMismatch(let type, let context):
                print("Type mismatch: expected \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                print("Debug description: \(context.debugDescription)")
            case .valueNotFound(let type, let context):
                print("Value not found: \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
            case .dataCorrupted(let context):
                print("Data corrupted at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                print("Debug description: \(context.debugDescription)")
            @unknown default:
                print("Unknown decoding error: \(decodingError)")
            }
            #endif
            throw decodingError
        }
    }

    func loadSamplePlan() {
        // Load sample plan from file for UI testing
        let samplePath = "/Users/zhongmingyu/Documents/Developer/SwimNote/sample_training_plan.json"

        guard let data = FileManager.default.contents(atPath: samplePath) else {
            errorMessage = "Could not load sample plan file"
            return
        }

        do {
            let rawString = String(data: data, encoding: .utf8) ?? ""
            generatedPlan = rawString
            var plan = try parsePlanJSON(rawString)
            plan = enrichPlanWithComputedFields(plan: plan, poolType: poolType, profile: appModel.activeProfile)
            parsedPlan = plan
            errorMessage = nil
            savedStatus = nil // Reset save status
            planOutline = nil // Clear outline
            accumulatedDryLand = [] // Clear dry land - sample plan has its own

            // Expand first session by default
            expandedSessions.insert(1)
        } catch {
            errorMessage = "Failed to parse sample plan: \(error.localizedDescription)"
        }
    }

    /// Populate computed fields that shouldn't come from LLM
    func enrichPlanWithComputedFields(
        plan: WeeklyTrainingPlan,
        poolType: PoolType,
        profile: UserProfile?
    ) -> WeeklyTrainingPlan {
        var enriched = plan

        // Set week starting date
        enriched.weekStartingDate = weekStartingDate

        // Get actual session count from the plan (LLM determined from tier guidance)
        let sessionsPerWeek = enriched.detailedSessions.count

        // Build swimmer summary from profile
        if let profile = profile {
            let pbs = profile.personalBests
            let pbText = pbs.isEmpty ? "No PBs recorded" :
                "PBs: Free \(pbs.freestyle50m ?? 0)s, Back \(pbs.backstroke50m ?? 0)s"
            enriched.overview.swimmerSummary = """
            \(profile.name), Age \(profile.age), \(profile.skillLevel.rawValue.capitalized) level.
            Target: \(sessionsPerWeek) sessions/week (from tier guidance).
            Strokes: \(profile.preferredStrokes.map { $0.rawValue.capitalized }.joined(separator: ", "))
            \(pbText)
            """
        }

        // Set session count from the plan (LLM determined)
        enriched.overview.sessionCount = sessionsPerWeek

        // Set pool type from user selection
        enriched.overview.poolType = poolType.shortLabel

        // Store raw pool type for proper distance display when loading saved plans
        enriched.poolTypeRaw = poolType.rawValue

        // Fix segment distances - calculate from actual set descriptions
        enriched.detailedSessions = enriched.detailedSessions.map { session in
            var fixedSession = session
            fixedSession.warmUp = fixSegmentDistance(session.warmUp, poolType: poolType)
            fixedSession.drillSet = fixSegmentDistance(session.drillSet, poolType: poolType)
            fixedSession.mainSet = fixSegmentDistance(session.mainSet, poolType: poolType)
            if let secondary = session.secondarySet {
                fixedSession.secondarySet = fixSegmentDistance(secondary, poolType: poolType)
            }
            fixedSession.coolDown = fixSegmentDistance(session.coolDown, poolType: poolType)
            return fixedSession
        }

        // Calculate total distance from detailed sessions (now with corrected distances)
        let totalMeters = enriched.detailedSessions.reduce(0) { sum, session in
            let sessionDistance = sum
                + parseDistance(session.warmUp.distance)
                + parseDistance(session.drillSet.distance)
                + parseDistance(session.mainSet.distance)
                + parseDistance(session.coolDown.distance)
            // Add secondary set distance if present
            if let secondary = session.secondarySet {
                return sessionDistance + parseDistance(secondary.distance)
            }
            return sessionDistance
        }
        // Format total distance with pool unit
        let unit = poolType == .scy ? "yd" : "m"
        let displayDistance = poolType == .scy ? Int(Double(totalMeters) * 1.09361) : totalMeters
        enriched.overview.totalDistance = "~\(displayDistance)\(unit)"

        // Assign dates to sessions
        enriched.detailedSessions = assignSessionDates(
            sessions: enriched.detailedSessions,
            weekStarting: weekStartingDate,
            sessionsPerWeek: sessionsPerWeek
        )

        // Assign dates to dry land exercises (spread across rest days)
        enriched.dryLandProgram = assignDryLandDates(
            exercises: enriched.dryLandProgram,
            sessions: enriched.detailedSessions,
            weekStarting: weekStartingDate
        )

        return enriched
    }

    /// Assign dates to dry land exercises on days without pool sessions
    func assignDryLandDates(
        exercises: [DryLandExercisePlan]?,
        sessions: [DetailedSession],
        weekStarting: Date
    ) -> [DryLandExercisePlan]? {
        guard let exercises = exercises, !exercises.isEmpty else { return exercises }

        var assigned = exercises
        let calendar = Calendar.current

        // Get dates that have pool sessions
        let sessionDates = sessions.compactMap { $0.scheduledDate }.map { DateFormatter.yyyyMMdd.string(from: $0) }

        // Find available days (days without pool sessions) for dry land
        var availableDays: [Date] = []
        for dayOffset in 0..<7 {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStarting) ?? weekStarting
            let dateStr = DateFormatter.yyyyMMdd.string(from: date)
            if !sessionDates.contains(dateStr) {
                availableDays.append(date)
            }
        }

        // Fallback: if no available days, use all days in the week
        if availableDays.isEmpty {
            for dayOffset in 0..<7 {
                availableDays.append(calendar.date(byAdding: .day, value: dayOffset, to: weekStarting) ?? weekStarting)
            }
        }

        // Assign dry land exercises to available days, cycling if needed
        for (index, _) in assigned.enumerated() {
            let dayIndex = index % availableDays.count
            assigned[index].scheduledDate = availableDays[dayIndex]
            assigned[index].isAssigned = true  // Mark as assigned when auto-scheduled
        }

        return assigned
    }

    /// Fix segment distance by computing from structured sets (preferred) or parsing description (fallback)
    func fixSegmentDistance(_ segment: SessionSegment, poolType: PoolType) -> SessionSegment {
        var fixed = segment

        func formatDist(_ meters: Int) -> String {
            let unit = poolType == .scy ? "yd" : "m"
            let display = poolType == .scy ? Int(Double(meters) * 1.09361) : meters
            return "\(display)\(unit)"
        }

        // Preferred: Use structured sets array for accurate calculation
        if let sets = segment.sets, !sets.isEmpty {
            let calculatedMeters = sets.reduce(0) { $0 + $1.totalDistance }
            fixed.distance = formatDist(calculatedMeters)

            // Build description from sets for display
            fixed.description = sets.map { $0.formatted }.joined(separator: "\n")

            // Extract drill names from sets that are drills
            let drillSets = sets.filter { $0.item.lowercased().contains("drill") || $0.notes?.lowercased().contains("drill") ?? false }
            if !drillSets.isEmpty {
                fixed.drills = drillSets.map { $0.item }
            }
        } else {
            // Fallback: Parse description for NxM patterns
            let calculatedMeters = calculateDistanceFromDescription(segment.description)
            let statedDistance = parseDistance(segment.distance)

            if calculatedMeters > 0 && (statedDistance == 0 || abs(calculatedMeters - statedDistance) > 50) {
                fixed.distance = formatDist(calculatedMeters)
            } else if statedDistance > 0 {
                // Re-format stated distance with correct unit
                fixed.distance = formatDist(statedDistance)
            }
        }

        return fixed
    }

    /// Calculate total distance from set descriptions like "6x50 breaststroke, 4x25 streamline"
    func calculateDistanceFromDescription(_ description: String) -> Int {
        var totalDistance = 0

        // Pattern: NxM where N is reps, M is distance per rep
        // Examples: "6x50", "4x25", "2x50m", "10x100m breaststroke"
        let pattern = #"(\d+)\s*[x×]\s*(\d+)"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return 0
        }

        let range = NSRange(description.startIndex..., in: description)
        let matches = regex.matches(in: description, options: [], range: range)

        for match in matches {
            // Extract reps and distance per rep
            if let repsRange = Range(match.range(at: 1), in: description),
               let distanceRange = Range(match.range(at: 2), in: description) {
                let repsStr = String(description[repsRange])
                let distStr = String(description[distanceRange])

                if let reps = Int(repsStr), let distance = Int(distStr) {
                    totalDistance += reps * distance
                }
            }
        }

        return totalDistance
    }

    /// Parse distance string like "400m" or "~1500m" into meters
    func parseDistance(_ distance: String) -> Int {
        let digits = distance.filter { $0.isNumber }
        return Int(digits) ?? 0
    }

    /// Update a session's scheduled date and mark as assigned
    func updateSessionDate(sessionNumber: Int, date: Date) {
        guard var plan = parsedPlan else { return }
        for i in plan.detailedSessions.indices {
            if plan.detailedSessions[i].sessionNumber == sessionNumber {
                plan.detailedSessions[i].scheduledDate = date
                plan.detailedSessions[i].isAssigned = true  // Mark as assigned when user picks a date
            }
        }
        parsedPlan = plan
    }

    /// Update a dry land exercise's scheduled date and mark as assigned
    func updateDryLandDate(exerciseId: String, date: Date) {
        guard var plan = parsedPlan,
              var dryLand = plan.dryLandProgram else { return }
        for i in dryLand.indices {
            if dryLand[i].id == exerciseId {
                dryLand[i].scheduledDate = date
                dryLand[i].isAssigned = true  // Mark as assigned when user picks a date
            }
        }
        plan.dryLandProgram = dryLand
        parsedPlan = plan
    }

    /// Assign dates to sessions based on sessionsPerWeek
    func assignSessionDates(
        sessions: [DetailedSession],
        weekStarting: Date,
        sessionsPerWeek: Int
    ) -> [DetailedSession] {
        var assigned = sessions
        let calendar = Calendar.current

        // Distribution: spread sessions evenly across the week
        // Supports double sessions (morning + afternoon) for higher training tiers
        let dayOffsets = PlanningSessionScheduling.dayOffsetsForSessions(count: sessionsPerWeek)

        for (index, _) in assigned.enumerated() {
            if index < dayOffsets.count {
                let (dayOffset, timeOfDay) = dayOffsets[index]
                assigned[index].scheduledDate = calendar.date(byAdding: .day, value: dayOffset, to: weekStarting)
                assigned[index].timeOfDay = timeOfDay
                assigned[index].isAssigned = true  // Mark as assigned when auto-scheduled
            } else {
                // Fallback: assign to consecutive days with cycling time of day
                let dayOffset = index % 7
                let timeOfDay: SessionTimeOfDay = index >= 7 ? .afternoon : .morning
                assigned[index].scheduledDate = calendar.date(byAdding: .day, value: dayOffset, to: weekStarting)
                assigned[index].timeOfDay = timeOfDay
                assigned[index].isAssigned = true
            }
        }

        return assigned
    }
}
