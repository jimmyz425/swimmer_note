import Foundation
import OSLog

private let llmConfigStoreLog = Logger(subsystem: "com.swimnote.llm", category: "ConfigStore")

@MainActor
final class LLMConfigurationStore {
    private let defaults: UserDefaults
    private let key = "SwimNote.LLMConfiguration"
    private let migrationLoggedKey = "SwimNote.LLMConfiguration.anthropicMigrationLogged"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Load the persisted `LLMConfiguration`.
    ///
    /// P2-2A migration: native Anthropic was deleted, so any persisted blob
    /// with `provider: "anthropic"` would fail to decode (the rawValue no
    /// longer exists in `LLMProvider`). When that happens we rewrite the JSON
    /// in-place to `provider: "openrouter"`, persist the updated blob, and
    /// log the event exactly once per install. We also clear the baseURL so
    /// the new provider's default takes over instead of pointing at the dead
    /// Anthropic endpoint.
    func load() -> LLMConfiguration? {
        guard let data = defaults.data(forKey: key) else { return nil }

        if let configuration = try? JSONDecoder().decode(LLMConfiguration.self, from: data) {
            return configuration
        }

        if let migrated = migrateAnthropicConfig(from: data) {
            if !defaults.bool(forKey: migrationLoggedKey) {
                llmConfigStoreLog.notice("Migrated persisted LLMConfiguration provider 'anthropic' -> 'openrouter' (P2-2A).")
                defaults.set(true, forKey: migrationLoggedKey)
            }
            // Persist the migrated form so future loads use the fast path.
            save(migrated)
            return migrated
        }

        return nil
    }

    func save(_ configuration: LLMConfiguration?) {
        if let configuration {
            guard let data = try? JSONEncoder().encode(configuration) else { return }
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private func migrateAnthropicConfig(from data: Data) -> LLMConfiguration? {
        guard
            var json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
            let provider = json["provider"] as? String,
            provider == "anthropic"
        else {
            return nil
        }

        json["provider"] = "openrouter"
        // The persisted baseURL pointed at api.anthropic.com; clearing it lets
        // .openRouter.defaultBaseURL take over rather than 404'ing.
        json.removeValue(forKey: "baseURL")

        guard let rewritten = try? JSONSerialization.data(withJSONObject: json) else {
            return nil
        }
        return try? JSONDecoder().decode(LLMConfiguration.self, from: rewritten)
    }
}
