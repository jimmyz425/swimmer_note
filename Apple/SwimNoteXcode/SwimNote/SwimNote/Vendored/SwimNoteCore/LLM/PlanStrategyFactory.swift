import Foundation

// MARK: - Strategy Factory

public struct PlanStrategyFactory: Sendable {
    public static func strategy(for type: PlanType) -> PlanGenerationStrategy {
        switch type {
        case .mixed: return MixedTrainingStrategy()
        case .recovery: return RecoveryStrategy()
        case .racePrep: return RacePrepStrategy()
        }
    }
}
