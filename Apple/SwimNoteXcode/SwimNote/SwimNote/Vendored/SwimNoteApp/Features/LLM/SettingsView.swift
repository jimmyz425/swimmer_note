import SwiftUI

struct SettingsView: View {
    @Bindable var appModel: SwimNoteAppModel
    @State private var showLLMConfig: Bool = false

    private let credentialStore: any SecureCredentialStore = {
        #if canImport(Security)
        KeychainCredentialStore()
        #else
        InMemoryCredentialStore()
        #endif
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection

                    llmStatusSection

                    iCloudSection
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [PoolTheme.surface, PoolTheme.light.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showLLMConfig) {
                LLMConfigurationSheet(appModel: appModel)
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SETTINGS")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(PoolTheme.deep)
            Text("Configure your preferences")
                .font(.headline)
                .foregroundStyle(PoolTheme.mid)
        }
    }

    private var llmStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("LLM Provider")
                .font(.title3.bold())
                .foregroundStyle(PoolTheme.deep)

            HStack {
                if appModel.llmConfiguration != nil {
                    // Configured - show status
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Configured")
                            .font(.headline)
                            .foregroundStyle(PoolTheme.deep)
                        Text("\(appModel.llmConfiguration?.provider.rawValue ?? "") • \(appModel.llmConfiguration?.modelName ?? "")")
                            .font(.caption)
                            .foregroundStyle(PoolTheme.smoke)
                    }

                    Spacer()

                    Button("Reset", systemImage: "arrow.counterclockwise") {
                        resetLLMConfiguration()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                } else {
                    // Not configured
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(.orange)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Not Configured")
                            .font(.headline)
                            .foregroundStyle(PoolTheme.deep)
                        Text("Required for AI planning features")
                            .font(.caption)
                            .foregroundStyle(PoolTheme.smoke)
                    }

                    Spacer()
                }
            }

            Button("Configure LLM", systemImage: "gearshape.2") {
                showLLMConfig = true
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
        .poolCard()
    }

    private var iCloudSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Storage")
                .font(.title3.bold())

            let readiness = CloudKitPersistenceReadiness()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Container")
                        .font(.subheadline.bold())
                    Spacer()
                    Text(readiness.cloudKitContainerIdentifier)
                        .font(.subheadline)
                        .foregroundStyle(PoolTheme.smoke)
                }

                HStack {
                    Text("Persistent History")
                        .font(.subheadline.bold())
                    Spacer()
                    Text(readiness.usesPersistentHistoryTracking ? "On" : "Off")
                        .font(.subheadline)
                        .foregroundStyle(readiness.usesPersistentHistoryTracking ? .green : PoolTheme.smoke)
                }

                HStack {
                    Text("Remote Changes")
                        .font(.subheadline.bold())
                    Spacer()
                    Text(readiness.usesRemoteChangeNotifications ? "On" : "Off")
                        .font(.subheadline)
                        .foregroundStyle(readiness.usesRemoteChangeNotifications ? .green : PoolTheme.smoke)
                }
            }

            // Note about efficiency improvements
            Text("Calendar lookups are now cached for faster performance")
                .font(.caption)
                .foregroundStyle(.green)
        }
        .poolCard()
    }

    private func resetLLMConfiguration() {
        // Delete API key from keychain
        if let config = appModel.llmConfiguration {
            try? credentialStore.delete(account: config.apiKeyReference)
        }
        // Clear configuration
        appModel.llmConfiguration = nil
        appModel.saveLLMConfiguration(nil)
    }
}

// MARK: - LLM Configuration Sheet

struct LLMConfigurationSheet: View {
    @Bindable var appModel: SwimNoteAppModel
    @Environment(\.dismiss) private var dismiss

    @State private var provider: LLMProvider = .openAICompatible
    @State private var modelName: String = ""
    @State private var baseURLText: String = ""
    @State private var apiKey: String = ""

    @State private var isTesting: Bool = false
    @State private var testResult: TestResult?

    private let credentialStore: any SecureCredentialStore = {
        #if canImport(Security)
        KeychainCredentialStore()
        #else
        InMemoryCredentialStore()
        #endif
    }()

    private let llmClient = OpenAIClient()

    enum TestResult {
        case success
        case failure(String)
    }

    var body: some View {
        NavigationStack {
            Form {
                providerSection

                modelSection

                if provider == .openAICompatible {
                    baseURLSection
                }

                apiKeySection

                if testResult != nil {
                    testResultSection
                }
            }
            .navigationTitle("Configure LLM")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save & Test") {
                        Task { await saveAndTest() }
                    }
                    .disabled(apiKey.isEmpty || modelName.isEmpty || isTesting)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .task {
                // Load existing config if available
                if let config = appModel.llmConfiguration {
                    provider = config.provider
                    modelName = config.modelName
                    if provider == .openAICompatible {
                        baseURLText = config.baseURL?.absoluteString ?? ""
                    }
                }
            }
        }
    }

    private var providerSection: some View {
        Section("Provider") {
            Picker("Provider", selection: $provider) {
                ForEach(LLMProvider.allCases, id: \.self) { p in
                    Text(p.displayName).tag(p)
                }
            }
            .pickerStyle(.segmented)

            // Tool calling support indicator
            HStack {
                Image(systemName: provider.supportsToolCalling ? "checkmark.circle.fill" : "exclamationmark.triangle")
                    .foregroundStyle(provider.supportsToolCalling ? .green : .orange)
                Text(provider.supportsToolCalling ? "Tool calling supported" : "Tool calling depends on endpoint")
                    .font(.caption)
                    .foregroundStyle(PoolTheme.smoke)
            }

            if provider == .openAICompatible {
                Text("Use OpenAI-compatible endpoints (DashScope, Together, etc.)")
                    .font(.caption)
                    .foregroundStyle(PoolTheme.smoke)
            }
        }
    }

    private var modelSection: some View {
        Section("Model") {
            TextField("Model name", text: $modelName)
                .textContentType(.none)
                .autocapitalization(.none)
                .submitLabel(.done)

            // Show suggested models for each provider
            VStack(alignment: .leading, spacing: 4) {
                Text("Suggested models:")
                    .font(.caption.bold())
                    .foregroundStyle(PoolTheme.smoke)

                ForEach(provider.suggestedModels, id: \.self) { model in
                    Button {
                        modelName = model
                    } label: {
                        Text(model)
                            .font(.caption)
                            .foregroundStyle(PoolTheme.mid)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var baseURLSection: some View {
        Section("Base URL") {
            if provider == .openAICompatible {
                TextField("https://api.example.com/v1", text: $baseURLText)
                    .textContentType(.URL)
                    .autocapitalization(.none)
                    .keyboardType(.URL)
                    .submitLabel(.done)

                Text("For DashScope: https://dashscope.aliyuncs.com/compatible-mode/v1")
                    .font(.caption)
                    .foregroundStyle(PoolTheme.smoke)
            } else {
                Text(provider.defaultBaseURL?.absoluteString ?? "Default endpoint")
                    .font(.subheadline)
                    .foregroundStyle(PoolTheme.smoke)

                if provider == .openRouter {
                    Text("OpenRouter uses a unified API for many models")
                        .font(.caption)
                        .foregroundStyle(PoolTheme.smoke)
                }
            }
        }
    }

    private var apiKeySection: some View {
        Section("API Key") {
            SecureField("Enter API key", text: $apiKey)

            Text("Key is stored securely in Keychain")
                .font(.caption)
                .foregroundStyle(PoolTheme.smoke)
        }
    }

    @ViewBuilder
    private var testResultSection: some View {
        Section("Test Result") {
            switch testResult {
            case .success:
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Connection successful!")
                        .foregroundStyle(.green)
                }

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)

            case .failure(let message):
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Text("Test failed")
                            .foregroundStyle(.red)
                    }
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(PoolTheme.smoke)
                }

            case .none:
                EmptyView()
            }
        }
    }

    private func saveAndTest() async {
        isTesting = true
        testResult = nil

        // Save configuration
        do {
            let reference = "llm-\(provider.rawValue)"
            try credentialStore.save(apiKey, for: reference)

            let baseURL: URL?
            if provider == .openAICompatible {
                // Custom endpoint requires manual URL
                if !baseURLText.isEmpty {
                    guard let url = URL(string: baseURLText.trimmingCharacters(in: .whitespaces)) else {
                        testResult = .failure("Invalid base URL")
                        isTesting = false
                        return
                    }
                    guard url.scheme?.lowercased() == "https" else {
                        testResult = .failure("Base URL must use HTTPS")
                        isTesting = false
                        return
                    }
                    baseURL = url
                } else {
                    testResult = .failure("Base URL required for OpenAI Compatible")
                    isTesting = false
                    return
                }
            } else {
                // Use provider's default URL
                baseURL = provider.defaultBaseURL
            }

            let configuration = try LLMConfiguration(
                provider: provider,
                apiKeyReference: reference,
                baseURL: baseURL,
                modelName: modelName.trimmingCharacters(in: .whitespaces)
            )

            appModel.llmConfiguration = configuration

            // Run test with appropriate client
            let testRequest = LLMRequest(
                systemRole: "assistant",
                prompt: "Say 'OK' in one word.",
                temperature: 0
            )

            let client: any LLMClient = provider == .anthropic ? AnthropicClient() : OpenAIClient()
            let response = try await client.complete(testRequest, configuration: configuration, apiKey: apiKey)

            if response.lowercased().contains("ok") {
                testResult = .success
                appModel.saveLLMConfiguration(configuration)
            } else {
                testResult = .success // Still success if API responded
                appModel.saveLLMConfiguration(configuration)
            }

        } catch LLMConfigurationError.insecureBaseURL {
            testResult = .failure("Base URL must use HTTPS")
        } catch {
            testResult = .failure(error.localizedDescription)
        }

        isTesting = false
    }
}

// MARK: - Previews

#Preview("Settings - Not Configured") {
    SettingsView(appModel: SwimNoteAppModel.bootstrap())
}

#Preview("Settings - Configured") {
    let model = SwimNoteAppModel.bootstrap()
    model.llmConfiguration = try? LLMConfiguration(
        provider: .openRouter,
        apiKeyReference: "llm-openrouter",
        baseURL: nil,
        modelName: "anthropic/claude-sonnet-4"
    )
    return SettingsView(appModel: model)
}

#Preview("LLM Config Sheet") {
    LLMConfigurationSheet(appModel: SwimNoteAppModel.bootstrap())
}