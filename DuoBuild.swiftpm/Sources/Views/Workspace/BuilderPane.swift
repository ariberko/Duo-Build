import SwiftUI

/// The left pane: the project, the conversation and the composer.
struct BuilderPane: View {
    let project: Project
    @Bindable var model: WorkspaceModel
    let layout: WorkspaceLayout
    let isDemo: Bool
    let onSend: (String?) -> Void
    let onRetry: () -> Void
    let onShowPreview: () -> Void
    let onShowHistory: () -> Void

    @FocusState private var composerFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            conversation
            Divider()
            composerArea
        }
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(project.name)
                .font(.title3.bold())
                .lineLimit(2)
            HStack(spacing: 6) {
                if let version = project.currentVersion {
                    Button(action: onShowHistory) {
                        Tag(text: "Version \(version.number)", symbol: "clock.arrow.circlepath", tint: Theme.accent)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Shows version history")
                }
                if isDemo { Tag(text: "Demo", symbol: "testtube.2", tint: .orange) }
                Text("Edited \(project.updatedAt, format: .relative(presentation: .named))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: Conversation

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(project.messages) { message in
                        MessageRow(
                            message: message,
                            version: message.versionID.flatMap { id in project.versions.first { $0.id == id } },
                            canRetry: message.id == project.messages.last?.id && model.failedInstruction != nil && !model.isWorking,
                            onRetry: onRetry,
                            onShowHistory: onShowHistory
                        )
                        .id(message.id)
                    }
                    if let stage = model.stageText {
                        WorkingRow(stage: stage, onStop: model.cancel)
                            .id("working")
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .defaultScrollAnchor(.bottom)
            .onChange(of: project.messages.count) {
                if let last = project.messages.last?.id {
                    withAnimation(.snappy) { proxy.scrollTo(last, anchor: .bottom) }
                }
            }
            .onChange(of: model.isWorking) {
                if model.isWorking { withAnimation(.snappy) { proxy.scrollTo("working", anchor: .bottom) } }
            }
        }
    }

    // MARK: Composer

    private var composerArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            if layout == .single && model.hasUnseenUpdate {
                Button {
                    model.hasUnseenUpdate = false
                    onShowPreview()
                } label: {
                    Label("Preview updated · View", systemImage: "eye")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DemoEngine.suggestions(for: project.spec), id: \.self) { idea in
                        Button(idea) { onSend(idea) }
                            .font(.footnote)
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                            .tint(Color.secondary)
                            .disabled(model.isWorking)
                    }
                }
            }
            .accessibilityLabel("Suggested changes")

            HStack(alignment: .bottom, spacing: 8) {
                TextField("Describe a change…", text: $model.draft, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($composerFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Theme.raised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .disabled(model.isWorking)

                if model.isWorking {
                    Button(action: model.cancel) {
                        Image(systemName: "stop.circle.fill").font(.system(size: 32))
                    }
                    .accessibilityLabel("Stop")
                } else {
                    Button {
                        composerFocused = false
                        onSend(nil)
                    } label: {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 32))
                    }
                    .disabled(model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Send")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .animation(.snappy, value: model.hasUnseenUpdate)
    }
}

private struct MessageRow: View {
    let message: ChatMessage
    let version: ProjectVersion?
    let canRetry: Bool
    let onRetry: () -> Void
    let onShowHistory: () -> Void

    var body: some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 40)
                Text(message.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Theme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .textSelection(.enabled)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("You: \(message.text)")

        case .assistant:
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("DuoBuild").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    if let version {
                        Button(action: onShowHistory) {
                            Tag(text: "Version \(version.number)", tint: Theme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text(message.text)
                    .font(.subheadline)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .surfaceCard(padding: 12)

        case .error:
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text(message.text).font(.subheadline)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                }
                if canRetry {
                    Button("Try Again", action: onRetry)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))

        case .note:
            Text(message.text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
    }
}

private struct WorkingRow: View {
    let stage: String
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text(stage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
                .animation(.easeInOut, value: stage)
            Spacer()
            Button("Stop", action: onStop)
                .font(.subheadline)
        }
        .surfaceCard(padding: 12)
        .accessibilityElement(children: .combine)
    }
}
