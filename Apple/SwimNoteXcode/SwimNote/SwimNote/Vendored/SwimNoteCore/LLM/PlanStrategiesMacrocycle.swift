import Foundation

// MARK: - Macrocycle Phase Strategies (Silver+ Only)

/// General Preparation Phase (Base Building)
/// Duration: 8-16 weeks
/// Focus: High aerobic volume (60-75% Zone 1-2), threshold introduction (5-10%)
public struct GeneralPrepStrategy: PlanGenerationStrategy, Sendable {
    public var planType: PlanType { .generalPrep }

    public func buildSystemRole() -> String {
        return "expert_swimming_coach"
    }

    public func buildUserPrompt(context: PlanContext) -> String {
        return buildDefaultOutlinePrompt(context, planType: planType) + """

        GENERAL PREPARATION PHASE RULES:
        - Zone distribution: 60-75% Zone 1-2 (aerobic base), 10-15% Zone 3 (tempo), 5-10% Zone 4 (threshold introduction)
        - Long repetitions: 200-500m intervals for aerobic development
        - Long rest relative to work: low metabolic stress, focus on technique consistency
        - High total session volume: building aerobic foundation
        - Primary focus: mitochondrial density, capillary networks, stroke efficiency
        - Volume: highest of all phases, building base for later phases

        CALL read_interval_research(section: "periodization") to get:
        - Zone distribution percentages for Phase 1 (General Preparation)
        - Sample week structures for base building
        - Interval characteristics for this phase

        SESSION TYPES: aerobic base / tempo introduction / technique maintenance

        OUTPUT ONLY JSON.
        """
    }

    public func guidanceFiles() -> [String] {
        return ["coach_prompt.md", "swimming-interval-training-research.md"]
    }

    public func coachingRules() -> String {
        return """
        GENERAL PREP PHASE:
        - Primary: Zone 1-2 aerobic swimming (CSS + 5-15s/100m)
        - Long reps: 200-500m at conversational pace
        - Weekly volume: building toward peak
        - Technique: quality under moderate fatigue
        - NO sprint work in this phase - save neuromuscular reserves
        """
    }
}

/// Specific Preparation Phase (Build Phase)
/// Duration: 6-12 weeks
/// Focus: Threshold work becomes primary (15-25% Zone 4), VO2max introduction (10-15%)
public struct SpecificPrepStrategy: PlanGenerationStrategy, Sendable {
    public var planType: PlanType { .specificPrep }

    public func buildSystemRole() -> String {
        return "expert_swimming_coach"
    }

    public func buildUserPrompt(context: PlanContext) -> String {
        return buildDefaultOutlinePrompt(context, planType: planType) + """

        SPECIFIC PREPARATION PHASE RULES:
        - Zone distribution: 40-50% Zone 1-2 (maintained aerobic), 15-20% Zone 3 (tempo), 15-25% Zone 4 (PRIMARY - threshold), 10-15% Zone 5 (VO2max introduction)
        - Moderate repetitions: 100-300m intervals at threshold
        - Moderate rest: increasing metabolic stress
        - Threshold work is the centerpiece of this phase
        - Primary focus: lactate threshold pace improvement, buffering capacity

        CALL read_interval_research(section: "periodization") to get:
        - Zone distribution percentages for Phase 2 (Specific Preparation)
        - Threshold interval characteristics
        - Sample threshold sets with rest intervals

        SESSION TYPES: threshold main set / tempo bridge / VO2max introduction

        OUTPUT ONLY JSON.
        """
    }

    public func guidanceFiles() -> [String] {
        return ["coach_prompt.md", "swimming-interval-training-research.md"]
    }

    public func coachingRules() -> String {
        return """
        SPECIFIC PREP PHASE:
        - Primary: Zone 4 threshold work (CSS to CSS - 2s/100m)
        - Threshold reps: 100-200m at threshold pace
        - Key sets: 10x100m on tight send-offs
        - Tempo: Zone 3 as bridge work
        - VO2max: limited introduction (10-15%)
        - This is where fitness translates to performance capability
        """
    }
}

/// Pre-Competition Phase (Sharpening)
/// Duration: 4-8 weeks
/// Focus: Race-pace specificity (15-20% Zone 5-6), reduced aerobic volume
public struct PreCompetitionStrategy: PlanGenerationStrategy, Sendable {
    public var planType: PlanType { .preCompetition }

    public func buildSystemRole() -> String {
        return "expert_swimming_coach"
    }

    public func buildUserPrompt(context: PlanContext) -> String {
        return buildDefaultOutlinePrompt(context, planType: planType) + """

        PRE-COMPETITION PHASE RULES:
        - Zone distribution: 25-35% Zone 1-2 (significantly reduced aerobic), 15-20% Zone 3, 15-20% Zone 4, 15-20% Zone 5 (INCREASED VO2max), 10-15% Zone 6 (sprint introduction)
        - Short to moderate repetitions: 25-200m
        - Race-pace specificity increases dramatically
        - Total volume decreases - quality over quantity
        - Primary focus: neuromuscular patterning at race pace, pace awareness

        CALL read_interval_research(section: "periodization") to get:
        - Zone distribution for Phase 3 (Pre-Competition)
        - Race-pace interval design
        - VO2max and sprint integration

        SESSION TYPES: race-pace rehearsal / VO2max sets / sharpening sprints

        OUTPUT ONLY JSON.
        """
    }

    public func guidanceFiles() -> [String] {
        return ["coach_prompt.md", "swimming-interval-training-research.md"]
    }

    public func coachingRules() -> String {
        return """
        PRE-COMPETITION PHASE:
        - Primary: Zone 5 VO2max (CSS - 3-6s/100m) and race-pace work
        - Race-pace reps: exact target race pace
        - Volume: decreasing, intensity increasing
        - Sprint: Zone 6 introduction (10-15%)
        - Focus: quality over quantity
        - Neuromuscular: learning race pace without clock
        """
    }
}

/// Competition Phase (Meet Season)
/// Focus: High sprint/speed (20-30% Zone 6), race-pace precision, low volume
public struct CompetitionPhaseStrategy: PlanGenerationStrategy, Sendable {
    public var planType: PlanType { .competition }

    public func buildSystemRole() -> String {
        return "expert_swimming_coach"
    }

    public func buildUserPrompt(context: PlanContext) -> String {
        return buildDefaultOutlinePrompt(context, planType: planType) + """

        COMPETITION PHASE RULES:
        - Zone distribution: 15-25% Zone 1-2 (maintenance only), 10-15% Zone 3, 10-15% Zone 4, 15-20% Zone 5, 20-30% Zone 6 (PRIMARY - sprint)
        - Very short repetitions: 10-100m
        - Full or near-full recovery between reps
        - Race-pace precision is paramount
        - Low total volume, very high quality
        - Primary focus: meet performance, race readiness, peak speed

        CALL read_interval_research(section: "periodization") to get:
        - Zone distribution for Phase 4 (Competition)
        - Sprint interval design with full recovery
        - Race-pace exactness guidance

        SESSION TYPES: race rehearsal / meet simulation / speed maintenance

        OUTPUT ONLY JSON.
        """
    }

    public func guidanceFiles() -> [String] {
        return ["coach_prompt.md", "swimming-interval-training-research.md"]
    }

    public func coachingRules() -> String {
        return """
        COMPETITION PHASE:
        - Primary: Zone 6 sprint (race pace and faster)
        - Very short reps: 10-50m with full recovery
        - Volume: lowest of all phases
        - Recovery: critical - 10-15% of training
        - Race rehearsal: practice meet routine
        - Intensity maintained, volume minimal
        """
    }
}

/// Taper Phase (10-21 days before major meet)
/// Focus: Volume reduction 41-60%, intensity maintained, race-pace focus (30-40% Zone 6)
public struct TaperStrategy: PlanGenerationStrategy, Sendable {
    public var planType: PlanType { .taper }

    public func buildSystemRole() -> String {
        return "expert_swimming_coach"
    }

    public func buildUserPrompt(context: PlanContext) -> String {
        return buildDefaultOutlinePrompt(context, planType: planType) + """

        TAPER PHASE RULES (10-21 days before major competition):
        - Volume reduction: 41-60% from pre-taper volume
        - Intensity MAINTAINED: race-pace and faster work is maintained or slightly increased
        - Frequency MAINTAINED: training frequency is not significantly reduced (to maintain neuromuscular patterns)
        - Zone distribution Week 1: 30-40% Zone 1-2, 15-20% Zone 5, 20-25% Zone 6
        - Zone distribution Week 2: 20-30% Zone 1-2, 15-20% Zone 5, 25-30% Zone 6
        - Competition Week: 15-20% Zone 1-2, 15-20% Zone 5, 30-40% Zone 6

        CRITICAL: Training load should NOT be reduced at the expense of intensity during taper.
        - Very short, sharp repetitions
        - Race-pace exactness
        - Full recovery between reps
        - Total session distance reduced by 40-60%

        CALL read_interval_research(section: "periodization") to get:
        - Taper protocol from research (Mujika 2010)
        - Zone distribution progression during taper
        - Taper interval characteristics

        SESSION TYPES: race-pace touch-ups / activation sprints / recovery focus

        OUTPUT ONLY JSON.
        """
    }

    public func guidanceFiles() -> [String] {
        return ["coach_prompt.md", "swimming-interval-training-research.md"]
    }

    public func coachingRules() -> String {
        return """
        TAPER PHASE:
        - Volume: reduce 41-60% from pre-taper
        - Intensity: MAINTAIN or increase slightly
        - Frequency: maintain (don't skip sessions)
        - Primary: Zone 6 race-pace work (30-40%)
        - Recovery: 15-20% of training
        - Focus: feeling fast, race-ready
        - Key principle: "Training load should not be reduced at the expense of intensity during the taper"
        """
    }
}
