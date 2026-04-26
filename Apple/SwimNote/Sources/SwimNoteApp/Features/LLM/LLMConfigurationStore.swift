import Foundation
import SwimNoteCore

@MainActor
final class LLMConfigurationStore {
    private let defaults: UserDefaults
    private let key = "SwimNote.LLMConfiguration"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> LLMConfiguration? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(LLMConfiguration.self, from: data)
    }

    func save(_ configuration: LLMConfiguration) {
        guard let data = try? JSONEncoder().encode(configuration) else { return }
        defaults.set(data, forKey: key)
    }
}
