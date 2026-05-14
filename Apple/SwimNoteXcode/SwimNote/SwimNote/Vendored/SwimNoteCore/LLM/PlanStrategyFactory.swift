import Foundation

// MARK: - Strategy Factory

public struct PlanStrategyFactory: Sendable {
    public static func strategy(for type: PlanType) -> PlanGenerationStrategy {
        switch type {
        case .mixed: return MixedTrainingStrategy()
        case .recovery: return RecoveryStrategy()
        case .endurance: return EnduranceStrategy()
        case .technique: return TechniqueFocusStrategy()
        case .dryLandOnly: return DryLandOnlyStrategy()
        case .racePrep: return RacePrepStrategy()
        case .speed: return SpeedSprintStrategy()
        // Macrocycle phases (Silver+ only)
        case .generalPrep: return GeneralPrepStrategy()
        case .specificPrep: return SpecificPrepStrategy()
        case .preCompetition: return PreCompetitionStrategy()
        case .competition: return CompetitionPhaseStrategy()
        case .taper: return TaperStrategy()
        }
    }
}
