import SwiftUI

/// Name the project, describe it, then watch it get built.
struct NewProjectView: View {
    var initialPrompt = ""
    let onCreated: (UUID) -> Void

    @Environment(ProjectStore.self) private var store
    @Environment(AISettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var prompt = ""
    @State private var phase: Phase = .editing
    @State private var task: Task<Void, Never>?
    @FocusState private var focus: Field?

    private enum Field { case name, prompt }

    private enum Phase: Equatable {
        case editing
        case generating(steps: [String])
        case failed(String)
    }

    struct Starter {
        let title: String
        let name: String
    }

    static let starters = [
        Starter(title: "A personal habit tracker", name: "Habit Tracker"),
        Starter(title: "A restaurant landing page", name: "Restaurant"),
        Starter(title: "A simple expense tracker", name: "Expenses"),
        Starter(title: "A to-do list for groceries", name: "Groceries"),
    ]

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .editing:
                    form
                case .generating(let steps):
                    GeneratingView(steps: steps, isDemo: settings.isDemo) { task?.cancel() }
                case .failed(let message):
                    failure(message)
                }
            }
            .animation(.snappy, value: phase)
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        task?.cancel()
                        dismiss()
                    }
                }
            }
        }
        .interactiveDismissDisabled(phase != .editing)
        .onAppear {
            if prompt.isEmpty { prompt = initialPrompt }
            focus = .name
        }
    }

    // MARK: Form

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Project name").font(.subheadline.weight(.semibold))
                    TextField("My App", text: $name)
                        .focused($focus, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focus = .prompt }
                        .padding(12)
                        .background(Theme.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("What do you want to build?").font(.subheadline.weight(.semibold))
                    ZStack(alignment: .topLeading) {
                        if prompt.isEmpty {
                            Text("Describe what you want to build…")
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 17)
                                .padding(.vertical, 20)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                        TextEditor(text: $prompt)
                            .focused($focus, equals: .prompt)
                            .scrollContentBackground(.hidden)
                            .padding(12)
                            .frame(minHeight: 140)
                            .accessibilityLabel("Describe what you want to build")
                    }
                    .background(Theme.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Start from an idea").font(.subheadline.weight(.semibold))
                    ForEach(Self.starters, id: \.title) { starter in
                        Button {
                            prompt = starter.title
                            if name.trimmingCharacters(in: .whitespaces).isEmpty {
                                name = store.uniqueName(for: starter.name)
                            }
                            Haptics.tap()
                        } label: {
                            HStack {
                                Image(systemName: "text.bubble").foregroundStyle(Theme.accent)
                                Text(starter.title).foregroundStyle(.primary)
                                Spacer()
                                if prompt == starter.title {
                                    Image(systemName: "checkmark").foregroundStyle(Theme.accent)
                                }
                            }
                            .padding(12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.border, lineWidth: 0.5))
                    }
                }

                if settings.isDemo {
                    Label {
                        Text("Demo mode: DuoBuild builds this from built-in templates. No real AI is used. You can connect your own backend in Settings.")
                    } icon: {
                        Image(systemName: "testtube.2").foregroundStyle(.orange)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            Button(action: create) {
                Text("Create")
                    .font(.headline)
                    .frame(maxWidth: 600)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canCreate)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(.bar)
        }
    }

    private func failure(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Couldn't Create Project", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again", action: create)
                .buttonStyle(.borderedProminent)
            Button("Edit Description") { phase = .editing }
        }
    }

    // MARK: Generate

    private func create() {
        guard canCreate else { return }
        focus = nil
        let projectName = store.uniqueName(for: name.trimmingCharacters(in: .whitespacesAndNewlines))
        let description = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let service = settings.makeService()
        phase = .generating(steps: [])

        task = Task {
            do {
                let result = try await service.generate(name: projectName, prompt: description) { step in
                    await MainActor.run {
                        if case .generating(let steps) = phase {
                            phase = .generating(steps: steps + [step])
                        }
                    }
                }
                try Task.checkCancellation()
                let project = Project(name: projectName, originalPrompt: description, spec: result.spec, summary: result.summary)
                store.add(project)
                Haptics.success()
                dismiss()
                onCreated(project.id)
            } catch is CancellationError {
                phase = .editing
            } catch {
                Haptics.failure()
                phase = .failed(error.localizedDescription)
            }
        }
    }
}

/// The steps of a generation, each ticked off as it finishes.
private struct GeneratingView: View {
    let steps: [String]
    let isDemo: Bool
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            ProgressView()
                .controlSize(.large)
                .accessibilityLabel("Creating project")
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    let done = index < steps.count - 1
                    HStack(spacing: 10) {
                        Image(systemName: done ? "checkmark.circle.fill" : "circle.dotted")
                            .foregroundStyle(done ? Theme.accent : Color.secondary)
                            .symbolEffect(.pulse, isActive: !done)
                        Text(step).foregroundStyle(done ? Color.secondary : Color.primary)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: steps)
            .frame(minHeight: 140, alignment: .top)

            if isDemo {
                Text("Demo mode · simulated, no real AI")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button("Stop", role: .cancel, action: onCancel)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}
