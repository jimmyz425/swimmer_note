import SwiftUI
import UIKit

/// Phase 2: each `ToolCallingConversation` iteration is one API completion. Tool rounds consume
/// iterations; the model still needs a later round with **no** `tool_calls` to emit final JSON.
/// If the cap is N and round N returns tools, `runStreaming` throws `maxIterationsReached` — session
/// 5-style failures when the coach reads many technique files before answering.
private enum PlanningPhase2LLM {
    static let maxToolIterations = 16
}

extension PlanningView {
    // MARK: - Phase 1: Generate Outline

    func generateOutline() async {
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

        isGeneratingOutline = true
        errorMessage = nil
        generationStreamPreview = ""
        planOutline = nil
        parsedPlan = nil
        accumulatedDryLand = []  // Reset dry land for new plan

        // Register background task to continue execution when screen locks
        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "GenerateOutline") {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }

        // Get strategy for selected plan type
        let strategy = PlanStrategyFactory.strategy(for: planType)

        // Build plan context from swimmer data
        let planContext = buildPlanContext(targetWeek: weekStartingDate)

        // Use simpler configuration for outline (no tool calls needed)
        let outlineConfig: LLMConfiguration
        do {
            outlineConfig = try LLMConfiguration(
                provider: config.provider,
                apiKeyReference: config.apiKeyReference,
                baseURL: config.baseURL,
                modelName: config.modelName,
                timeoutSeconds: 180,  // 3 minutes for outline (large prompt with pre-gathered data)
                maxRetries: config.maxRetries
            )
        } catch {
            outlineConfig = config
        }

        do {
            let request = LLMRequest(
                systemRole: strategy.buildSystemRole(),
                prompt: strategy.buildOutlinePrompt(context: planContext),
                // Outline JSON is large (tierGuidance + overview + schedule + technique plan); 2048 often cuts mid-string.
                maxTokens: 4096
            )
            let rawOutput = try await streamNonToolCompletionToString(
                request: request,
                configuration: outlineConfig,
                apiKey: apiKey
            )

            // Parse outline JSON
            let outline = try parseOutlineJSON(rawOutput)
            planOutline = enrichOutlineWithDates(outline: outline, weekStarting: weekStartingDate, poolType: poolType)
            savedStatus = nil

            // Save outline for resumption if interrupted
            try? await appModel.saveOutline(planOutline!)
        } catch {
            errorMessage = "Failed to generate outline: \(error.localizedDescription)"
        }

        // End background task
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
        }
        isGeneratingOutline = false
        generationStreamPreview = ""
    }

    // MARK: - Phase 2: Generate Detailed Session

    /// Result from generating a single session
    struct SessionGenerationResult: Sendable {
        let sessionNumber: Int
        let detailedSession: DetailedSession?
        let error: Error?
    }

    /// Generate a single session (pure function - returns result without modifying state)
    func generateSingleSessionResult(
        sessionOutline: SessionOutline,
        weeklyOutline: WeeklyPlanOutline,
        config: LLMConfiguration,
        apiKey: String,
        strategy: any PlanGenerationStrategy,
        planContext: PlanContext
    ) async -> SessionGenerationResult {
        // Use tool calling for Phase 2 (read technique files for drills)
        let conversation = ToolCallingConversation(
            configuration: config,
            apiKey: apiKey,
            executor: appModel.createToolExecutor(referenceDate: weekStartingDate)
        )

        // Tools for Phase 2: technique file reading + evidence-based drills
        let phase2Tools = ResourcesNavigationTools.all + [UserDataTools.readEvidenceDrills]

        do {
            let rawOutput = try await streamToolConversationToString(
                conversation: conversation,
                systemRole: strategy.buildSystemRole(),
                userPrompt: strategy.buildDetailPrompt(sessionOutline: sessionOutline, weeklyOutline: weeklyOutline, context: planContext),
                tools: phase2Tools,
                maxIterations: PlanningPhase2LLM.maxToolIterations,
                maxTokens: 4096
            )

            let detailedSession = try parseDetailedSessionJSON(rawOutput)
            return SessionGenerationResult(sessionNumber: sessionOutline.sessionNumber, detailedSession: detailedSession, error: nil)
        } catch {
            return SessionGenerationResult(sessionNumber: sessionOutline.sessionNumber, detailedSession: nil, error: error)
        }
    }

    /// Generate all detailed sessions in parallel with throttling
    func generateAllDetailedSessionsParallel(for outline: WeeklyPlanOutline) async {
        guard let config = appModel.llmConfiguration,
              var currentOutline = planOutline else {
            errorMessage = "Generate outline first"
            return
        }

        // Load API key
        let apiKey: String
        do {
            guard let key = try credentialStore.load(account: config.apiKeyReference) else {
                errorMessage = "API key not found"
                return
            }
            apiKey = key
        } catch {
            errorMessage = "Could not load API key: \(error.localizedDescription)"
            return
        }

        isGeneratingDetails = true
        errorMessage = nil
        generatingSessions = []

        // Register background task
        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "GenerateAllSessionsParallel") {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }

        let strategy = PlanStrategyFactory.strategy(for: planType)
        let planContext = buildPlanContext(targetWeek: weekStartingDate)

        // Get sessions that need generation
        let sessionsToGenerate = outline.schedule.filter { !$0.isDetailsGenerated }

        #if DEBUG
        print("🔄 Starting parallel generation of \(sessionsToGenerate.count) sessions with max \(maxConcurrentSessions) concurrent")
        #endif

        // Use TaskGroup with throttling
        var results: [SessionGenerationResult] = []
        var errors: [String] = []

        await withTaskGroup(of: SessionGenerationResult.self) { group in
            var activeCount = 0
            var sessionIndex = 0
            let sessions = sessionsToGenerate

            while sessionIndex < sessions.count || activeCount > 0 {
                // Add tasks up to max concurrent
                while activeCount < maxConcurrentSessions && sessionIndex < sessions.count {
                    let session = sessions[sessionIndex]
                    sessionIndex += 1
                    activeCount += 1

                    // Update UI to show this session is generating
                    Task { @MainActor in
                        generatingSessions.insert(session.sessionNumber)
                    }

                    group.addTask {
                        await generateSingleSessionResult(
                            sessionOutline: session,
                            weeklyOutline: outline,
                            config: config,
                            apiKey: apiKey,
                            strategy: strategy,
                            planContext: planContext
                        )
                    }
                }

                // Wait for one result
                if let result = await group.next() {
                    activeCount -= 1
                    results.append(result)

                    // Update UI
                    Task { @MainActor in
                        generatingSessions.remove(result.sessionNumber)
                    }

                    if let session = result.detailedSession {
                        // Update outline with completed session
                        for i in currentOutline.schedule.indices {
                            if currentOutline.schedule[i].sessionNumber == result.sessionNumber {
                                currentOutline.schedule[i].detailedSession = session
                                currentOutline.schedule[i].isDetailsGenerated = true
                            }
                        }

                        // Save progress after each session completes
                        Task { @MainActor in
                            planOutline = currentOutline
                        }
                        try? await appModel.saveOutline(currentOutline)

                        #if DEBUG
                        print("✅ Session #\(result.sessionNumber) completed")
                        #endif
                    } else if let error = result.error {
                        errors.append("Session #\(result.sessionNumber): \(error.localizedDescription)")
                        #if DEBUG
                        print("❌ Session #\(result.sessionNumber) failed: \(error)")
                        #endif
                    }
                }
            }
        }

        // Update final outline
        planOutline = currentOutline

        // Report errors
        if !errors.isEmpty {
            errorMessage = errors.isEmpty ? nil : "Some sessions failed: " + errors.joined(separator: "; ")
        }

        // Check if all sessions complete
        if currentOutline.schedule.allSatisfy({ $0.isDetailsGenerated }) && errors.isEmpty {
            // Generate dry land and convert
            await generateWeeklyDryLand(outline: currentOutline)
            convertOutlineToFullPlan(currentOutline)
            try? await appModel.deleteOutline()
        }

        // End background task
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
        }

        isGeneratingDetails = false
        generatingSessions = []
    }

    /// Generate single session (for individual button tap)
    func generateDetailedSession(for sessionOutline: SessionOutline, in outline: WeeklyPlanOutline) async {
        guard let config = appModel.llmConfiguration,
              var currentOutline = planOutline else {
            errorMessage = "Generate outline first"
            return
        }

        // Load API key
        let apiKey: String
        do {
            guard let key = try credentialStore.load(account: config.apiKeyReference) else {
                errorMessage = "API key not found"
                return
            }
            apiKey = key
        } catch {
            errorMessage = "Could not load API key: \(error.localizedDescription)"
            return
        }

        generatingSessionNumber = sessionOutline.sessionNumber
        errorMessage = nil
        generationStreamPreview = ""

        // Register background task to continue execution when screen locks
        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "GenerateSession") {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }

        let strategy = PlanStrategyFactory.strategy(for: planType)
        let planContext = buildPlanContext(targetWeek: weekStartingDate)

        // Use tool calling for Phase 2 (read technique files for drills)
        let conversation = ToolCallingConversation(
            configuration: config,
            apiKey: apiKey,
            executor: appModel.createToolExecutor(referenceDate: weekStartingDate)
        )

        // Tools for Phase 2: technique file reading + evidence-based drills
        let phase2Tools = ResourcesNavigationTools.all + [UserDataTools.readEvidenceDrills]

        do {
            let rawOutput = try await streamToolConversationToString(
                conversation: conversation,
                systemRole: strategy.buildSystemRole(),
                userPrompt: strategy.buildDetailPrompt(sessionOutline: sessionOutline, weeklyOutline: currentOutline, context: planContext),
                tools: phase2Tools,
                maxIterations: PlanningPhase2LLM.maxToolIterations,
                maxTokens: 4096
            )

            // Parse detailed session JSON
            let detailedSession = try parseDetailedSessionJSON(rawOutput)

            // Update outline with detailed session
            for i in currentOutline.schedule.indices {
                if currentOutline.schedule[i].sessionNumber == sessionOutline.sessionNumber {
                    currentOutline.schedule[i].detailedSession = detailedSession
                    currentOutline.schedule[i].isDetailsGenerated = true
                }
            }
            planOutline = currentOutline

            // Save progress for resumption if interrupted
            try? await appModel.saveOutline(currentOutline)

            // Check if all sessions are generated - generate dryland then convert to full plan
            if currentOutline.schedule.allSatisfy({ $0.isDetailsGenerated }) {
                // Phase 3: Generate weekly dryland based on full plan
                await generateWeeklyDryLand(outline: currentOutline)
                convertOutlineToFullPlan(currentOutline)

                // Delete outline since generation is complete
                try? await appModel.deleteOutline()
            }
        } catch LLMServiceError.maxIterationsReached {
            errorMessage = "Session generation took too long. Try again."
        } catch {
            errorMessage = "Failed to generate session #\(sessionOutline.sessionNumber): \(error.localizedDescription)"
        }

        // End background task
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
        }
        generatingSessionNumber = nil
        generationStreamPreview = ""
    }

    // MARK: - Phase 3: Weekly Dry Land Generation

    func generateWeeklyDryLand(outline: WeeklyPlanOutline) async {
        guard let config = appModel.llmConfiguration else {
            errorMessage = "No LLM configuration"
            return
        }

        let apiKey: String
        do {
            guard let key = try credentialStore.load(account: config.apiKeyReference) else {
                errorMessage = "API key not found"
                return
            }
            apiKey = key
        } catch {
            errorMessage = "Could not load API key: \(error.localizedDescription)"
            return
        }

        isGeneratingDryLand = true
        errorMessage = nil
        generationStreamPreview = ""

        // Register background task to continue execution when screen locks
        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "GenerateDryLand") {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }

        let strategy = PlanStrategyFactory.strategy(for: planType)
        let planContext = buildPlanContext(targetWeek: weekStartingDate)

        // Use simple completion (no tools) for dryland generation
        let request = LLMRequest(
            systemRole: strategy.buildSystemRole(),
            prompt: strategy.buildDryLandPrompt(outline: outline, context: planContext),
            temperature: 0.2,
            maxTokens: 1536
        )

        do {
            let rawOutput = try await streamNonToolCompletionToString(
                request: request,
                configuration: config,
                apiKey: apiKey
            )

            #if DEBUG
            print("🔧 Dryland raw output: \(String(rawOutput.prefix(500)))")
            #endif

            let dryLandExercises = parseDryLandFromJSON(rawOutput)

            #if DEBUG
            print("🔧 Parsed dryland exercises count: \(dryLandExercises.count)")
            for exercise in dryLandExercises {
                print("🔧 Dryland: \(exercise.stroke) - \(exercise.exerciseId) - \(exercise.setsReps)")
            }
            #endif

            accumulatedDryLand = dryLandExercises

            // Save outline with dry land exercises for resumption
            var updatedOutline = outline
            updatedOutline.dryLandExercises = dryLandExercises
            planOutline = updatedOutline
            try? await appModel.saveOutline(updatedOutline)
        } catch {
            errorMessage = "Failed to generate dry land: \(error.localizedDescription)"
            #if DEBUG
            print("🔧 Dryland generation error: \(error)")
            #endif
        }

        // End background task
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
        }
        isGeneratingDryLand = false
        generationStreamPreview = ""
    }

    func generateAllDetailedSessions(for outline: WeeklyPlanOutline) async {
        isGeneratingDetails = true
        errorMessage = nil

        // Register background task for the overall generation loop
        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "GenerateAllSessions") {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }

        for session in outline.schedule where !session.isDetailsGenerated {
            await generateDetailedSession(for: session, in: outline)
            // Small delay to avoid rate limiting
            try? await Task.sleep(for: .milliseconds(500))
        }

        // End background task
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
        }
        isGeneratingDetails = false
    }
}
