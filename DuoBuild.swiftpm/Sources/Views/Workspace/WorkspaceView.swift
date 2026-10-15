import SwiftUI

enum WorkspacePane: String, CaseIterable, Identifiable {
    case builder, preview
    var id: String { rawValue }
    var title: String { self == .builder ? "Builder" : "Preview" }
}

/// One open project. Two panes side by side when there's room (like the open iPhone Duo),
/// one pane with a switch when there isn't (like its cover display).
/// All state lives above the panes, so nothing is lost when the layout changes.
struct WorkspaceView: View {
    let projectID: UUID
    var startPane: WorkspacePane = .builder

    @Environment(ProjectStore.self) private var store
    @Environment(AISettings.self) private var settings
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dismiss) private var dismiss

    @State private var model = WorkspaceModel()
    @State private var interaction = PreviewInteraction()
    @State private var previewOptions = PreviewOptions()
    @State private var pane: WorkspacePane = .builder
    @State private var showingHistory = false
    @State private var showingRename = false
    @State private var renameText = ""
    @State private var confirmingDelete = false
    @State private var didApplyStartPane = false

    var body: some View {
        Group {
            if let project = store.project(id: projectID) {
                GeometryReader { geo in
                    let layout = WorkspaceLayout.resolve(width: geo.size.width, sizeClass: sizeClass)
                    content(project, layout: layout, width: geo.size.width)
                        .toolbar { toolbarContent(project, layout: layout) }
                }
                .sheet(isPresented: $showingHistory) {
                    VersionHistoryView(project: project, canRestore: !model.isWorking) { version in
                        store.update(projectID) { $0.restore(version.id) }
                        interaction.show("Restored version \(version.number)")
                    }
                }
                .alert("Rename Project", isPresented: $showingRename) {
                    TextField("Name", text: $renameText)
                    Button("Cancel", role: .cancel) {}
                    Button("Rename") { store.rename(projectID, to: renameText) }
                }
                .confirmationDialog("Delete “\(project.name)”?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                    Button("Delete Project", role: .destructive) {
                        model.cancel()
                        dismiss()
                        store.delete(projectID)
                    }
                } message: {
                    Text("This removes the project and all its versions from this device.")
                }
            } else {
                ContentUnavailableView("Project Not Found", systemImage: "questionmark.folder", description: Text("It may have been deleted."))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(store.project(id: projectID)?.name ?? "")
        .overlay(alignment: .top) {
            if let toast = interaction.toast {
                ToastView(text: toast)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            guard !didApplyStartPane else { return }
            didApplyStartPane = true
            pane = startPane
        }
        .onDisappear { model.cancel() }
    }

    // MARK: Layout

    @ViewBuilder
    private func content(_ project: Project, layout: WorkspaceLayout, width: CGFloat) -> some View {
        switch layout {
        case .split:
            HStack(spacing: 0) {
                builder(project, layout: layout)
                    .frame(width: WorkspaceLayout.builderWidth(total: width))
                Divider().ignoresSafeArea(edges: .bottom)
                preview(project)
            }
        case .single:
            ZStack {
                switch pane {
                case .builder:
                    builder(project, layout: layout)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                case .preview:
                    preview(project)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: pane)
        }
    }

    private func builder(_ project: Project, layout: WorkspaceLayout) -> some View {
        BuilderPane(
            project: project,
            model: model,
            layout: layout,
            isDemo: settings.isDemo,
            onSend: { text in
                model.send(text, projectID: projectID, store: store, service: settings.makeService())
            },
            onRetry: {
                model.retry(projectID: projectID, store: store, service: settings.makeService())
            },
            onShowPreview: { pane = .preview },
            onShowHistory: { showingHistory = true }
        )
    }

    private func preview(_ project: Project) -> some View {
        PreviewPane(project: project, interaction: interaction, options: $previewOptions, isUpdating: model.isWorking)
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private func toolbarContent(_ project: Project, layout: WorkspaceLayout) -> some ToolbarContent {
        // One pane: a Builder / Preview switch. Two panes: nothing here, the builder shows the name.
        ToolbarItem(placement: .principal) {
            if layout == .single {
                Picker("Pane", selection: $pane) {
                    ForEach(WorkspacePane.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                .onChange(of: pane) {
                    if pane == .preview { model.hasUnseenUpdate = false }
                }
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    showingHistory = true
                } label: {
                    Label("Version History", systemImage: "clock.arrow.circlepath")
                }
                Button {
                    renameText = project.name
                    showingRename = true
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                Button {
                    if let copy = store.duplicate(projectID) {
                        interaction.show("Saved a copy: “\(copy.name)”")
                    }
                } label: {
                    Label("Duplicate", systemImage: "plus.square.on.square")
                }
                Divider()
                Button(role: .destructive) {
                    confirmingDelete = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("Project actions")
        }
    }
}
