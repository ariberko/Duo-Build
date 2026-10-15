import SwiftUI

struct SettingsView: View {
    @Environment(AISettings.self) private var settings
    @Environment(ProjectStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var restoredExamples = false

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section {
                    Picker("Mode", selection: $settings.mode) {
                        ForEach(AISettings.Mode.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

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
                    }
                } header: {
                    Text("AI Service")
                } footer: {
                    if settings.mode == .backend && settings.backendURL == nil && !settings.backendAddress.isEmpty {
                        Text("Enter a full https:// address. Until then DuoBuild stays in Demo mode.")
                            .foregroundStyle(.red)
                    } else if settings.mode == .backend {
                        Text("DuoBuild sends your prompt and the current design to this address. Your server keeps the AI provider's key. DuoBuild never asks for or stores API keys.")
                    } else {
                        Text("Demo mode builds designs from built-in templates and simple rules. It's free, works offline and never pretends to be a real AI.")
                    }
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
}
