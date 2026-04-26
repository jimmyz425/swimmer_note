import SwiftUI
import SwimNoteCore

struct SettingsView: View {
    @Bindable var appModel: SwimNoteAppModel
    @State private var provider: LLMProvider = .openAI
    @State private var modelName = "gpt-4.1-mini"
    @State private var apiKey = ""
    @State private var message: String?
    private let credentialStore: any SecureCredentialStore = {
        #if canImport(Security)
        KeychainCredentialStore()
        #else
        InMemoryCredentialStore()
        #endif
    }()

    var body: some View {
        NavigationStack {
            Form {
                Section("LLM Provider") {
                    Picker("Provider", selection: $provider) {
                        ForEach(LLMProvider.allCases, id: \.self) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    TextField("Model", text: $modelName)
                    SecureField("API Key", text: $apiKey)
                    Button("Save Provider Settings") {
                        saveConfiguration()
                    }
                }

                Section("iCloud") {
                    let readiness = CloudKitPersistenceReadiness()
                    LabeledContent("Container", value: readiness.cloudKitContainerIdentifier)
                    LabeledContent("Persistent History", value: readiness.usesPersistentHistoryTracking ? "On" : "Off")
                    LabeledContent("Remote Changes", value: readiness.usesRemoteChangeNotifications ? "On" : "Off")
                }

                if let message {
                    Section {
                        Text(message)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func saveConfiguration() {
        do {
            let reference = "llm-\(provider.rawValue)"
            try credentialStore.save(apiKey, for: reference)
            let configuration = try LLMConfiguration(
                provider: provider,
                apiKeyReference: reference,
                modelName: modelName
            )
            appModel.saveLLMConfiguration(configuration)
            apiKey = ""
            message = "Provider settings saved locally."
        } catch LLMConfigurationError.insecureBaseURL {
            message = "Provider endpoints must use HTTPS."
        } catch {
            message = "Could not save provider settings."
        }
    }
}
