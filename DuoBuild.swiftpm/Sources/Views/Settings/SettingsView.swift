import SwiftUI

struct SettingsView: View {
    @Environment(AISettings.self) private var settings
    @Environment(ProjectStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var restoredExamples = false
    @State private var keyDraft = ""
    @State private var keyCheck: KeyCheck = .idle

    private enum KeyCheck: Equatable {
        case idle, checking, ok, failed(String)
    }

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section {
                    Picker("Mode", selection: $settings.mode) {
                        ForEach(AISettings.Mode.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if settings.mode == .claude {
                        claudeRows(settings)
                    }

                    if settings.mode == .backend {
                        TextField("https://your-server.example.com/duobuild", text: $settings.backendAddress)
                            .textContentType(.URL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    LabeledContent("Status") {
                        Text(settings.statusText)
                            .foregroundStyle(settings.isDemo ? Color.orange : Color.green)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("AI Service")
                } footer: {
                    footer(settings)
                }

                Section {
                    Button("Add Example Projects Again") {
                        store.restoreExamples()
                        restoredExamples = true
                    }
                    .disabled(restoredExamples)
                } header: {
                    Text("Projects")
                } footer: {
                    Text(restoredExamples ? "Examples added to Recent." : "Projects are saved only on this device.")
                }

                Section("About") {
                    LabeledContent("Two panes", value: "When the screen is wide enough")
                    LabeledContent("One pane", value: "On narrow screens")
                    Text("On iPhone Duo, open the phone to see the builder and the preview side by side. Closed, the cover display shows one pane with a quick switch. DuoBuild picks the layout from the space it's given, so it also works on other iPhones and iPad.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: Claude key

    @ViewBuilder
    private func claudeRows(_ settings: AISettings) -> some View {
        @Bindable var settings = settings
        if let hint = settings.claudeKeyHint {
            LabeledContent("API key", value: hint)
            Picker("Model", selection: $settings.claudeModel) {
                ForEach(ClaudeAIService.Model.allCases) { model in
                    Text("\(model.title) · \(model.note)").tag(model)
                }
            }
            Button {
                Task { await check(key: nil) }
            } label: {
                HStack {
                    Text("Test Connection")
                    Spacer()
                    keyCheckLabel
                }
            }
            .disabled(keyCheck == .checking)
            Button("Remove Key", role: .destructive) {
                settings.removeClaudeKey()
                keyCheck = .idle
            }
        } else {
            SecureField("Paste your Claude API key", text: $keyDraft)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button {
                Task { await check(key: keyDraft) }
            } label: {
                HStack {
                    Text("Check and Save Key")
                    Spacer()
                    keyCheckLabel
                }
            }
            .disabled(keyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || keyCheck == .checking)
            Link("Get a key at console.anthropic.com", destination: URL(string: "https://console.anthropic.com/settings/keys")!)
                .font(.footnote)
        }
    }

    @ViewBuilder
    private var keyCheckLabel: some View {
        switch keyCheck {
        case .idle: EmptyView()
        case .checking: ProgressView()
        case .ok: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed: Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        }
    }

    /// Checks a key with Anthropic's free model list call. Saves it only if it works.
    private func check(key: String?) async {
        let candidate = key?.trimmingCharacters(in: .whitespacesAndNewlines) ?? settings.savedClaudeKey() ?? ""
        keyCheck = .checking
        switch await ClaudeAIService.testKey(candidate) {
        case .success:
            if key != nil {
                do {
                    try settings.saveClaudeKey(candidate)
                    keyDraft = ""
                } catch {
                    keyCheck = .failed(error.localizedDescription)
                    return
                }
            }
            keyCheck = .ok
        case .failure(let error):
            keyCheck = .failed(error.localizedDescription)
        }
    }

    @ViewBuilder
    private func footer(_ settings: AISettings) -> some View {
        if case .failed(let message) = keyCheck, settings.mode == .claude {
            Text(message).foregroundStyle(.red)
        } else {
            switch settings.mode {
            case .demo:
                Text("Demo mode builds designs from built-in templates and simple rules. It's free, works offline and never pretends to be a real AI.")
            case .claude:
                Text("Your key is stored only on this iPhone, in the Keychain, and is sent only to api.anthropic.com. Usage is billed to your own Anthropic account. DuoBuild never sees it.")
            case .backend:
                if settings.backendURL == nil && !settings.backendAddress.isEmpty {
                    Text("Enter a full https:// address. Until then DuoBuild stays in Demo mode.")
                        .foregroundStyle(.red)
                } else {
                    Text("DuoBuild sends your prompt and the current design to this address. Your server keeps the AI provider's key.")
                }
            }
        }
    }
}
