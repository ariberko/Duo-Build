import SwiftUI

struct WorkspaceRoute: Hashable {
    let id: UUID
    var pane: WorkspacePane = .builder
}

/// The project dashboard.
struct HomeView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AISettings.self) private var settings

    @State private var path: [WorkspaceRoute] = []
    @State private var showingNew = false
    @State private var showingSettings = false
    @State private var renaming: Project?
    @State private var renameText = ""
    @State private var deleting: Project?
    @State private var toast: String?
    @State private var didApplyLaunchOptions = false

    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 260), spacing: 14)]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    newProjectButton
                    problems
                    recentSection
                    examplesSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: 1100)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.canvas)
            .navigationTitle("DuoBuild")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNew = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New Project")
                }
            }
            .navigationDestination(for: WorkspaceRoute.self) { route in
                WorkspaceView(projectID: route.id, startPane: route.pane)
            }
        }
        .sheet(isPresented: $showingNew) {
            NewProjectView { id in
                path.append(WorkspaceRoute(id: id))
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .alert("Rename Project", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                if let renaming { store.rename(renaming.id, to: renameText) }
            }
        }
        .confirmationDialog(
            "Delete “\(deleting?.name ?? "")”?",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible,
            presenting: deleting
        ) { project in
            Button("Delete Project", role: .destructive) {
                withAnimation { store.delete(project.id) }
            }
        } message: { _ in
            Text("This removes the project and all its versions from this device.")
        }
        .overlay(alignment: .bottom) {
            if let toast {
                ToastView(text: toast)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear(perform: applyLaunchOptions)
    }

    // MARK: Sections

    private var newProjectButton: some View {
        Button {
            showingNew = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("New Project").font(.headline)
                    Text("Describe it, preview it, refine it.")
                        .font(.subheadline)
                        .opacity(0.85)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.subheadline.weight(.semibold)).opacity(0.7)
            }
            .foregroundStyle(.white)
            .padding(16)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var problems: some View {
        if settings.isDemo {
            Button {
                showingSettings = true
            } label: {
                Label(settings.statusText, systemImage: "testtube.2")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
            .padding(.top, -16)
            .accessibilityHint("Opens AI settings")
        }
        if let problem = store.loadProblem ?? store.saveProblem {
            Label(problem, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(.red)
                .surfaceCard(padding: 12)
        }
    }

    @ViewBuilder
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent").font(.title3.bold())
            let recent = store.recentProjects
            if recent.isEmpty {
                ContentUnavailableView {
                    Label("No Projects Yet", systemImage: "square.dashed")
                } description: {
                    Text("Tap New Project, or open an example below.")
                }
                .frame(maxWidth: .infinity)
                .surfaceCard()
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(recent) { project in
                        NavigationLink(value: WorkspaceRoute(id: project.id)) {
                            ProjectCard(project: project)
                        }
                        .buttonStyle(.plain)
                        .contextMenu { menu(for: project) }
                    }
                }
            }
        }
    }

    private var examplesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Examples").font(.title3.bold())
                Text("Open a ready-made starting point and change it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(ExampleProject.all) { example in
                    Button {
                        open(example)
                    } label: {
                        ExampleCard(example: example)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func menu(for project: Project) -> some View {
        Button {
            path.append(WorkspaceRoute(id: project.id))
        } label: {
            Label("Open", systemImage: "arrow.up.forward.square")
        }
        Button {
            renameText = project.name
            renaming = project
        } label: {
            Label("Rename", systemImage: "pencil")
        }
        Button {
            if let copy = store.duplicate(project.id) { show("Saved a copy: “\(copy.name)”") }
        } label: {
            Label("Duplicate", systemImage: "plus.square.on.square")
        }
        Divider()
        Button(role: .destructive) {
            deleting = project
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: Actions

    private func open(_ example: ExampleProject) {
        var project = SampleData.makeProject(name: store.uniqueName(for: example.name), prompt: example.prompt)
        project.messages.insert(ChatMessage(role: .note, text: "Started from the “\(example.name)” example."), at: 0)
        store.add(project)
        Haptics.tap()
        path.append(WorkspaceRoute(id: project.id))
    }

    private func show(_ text: String) {
        withAnimation(.snappy) { toast = text }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeOut) { toast = nil }
        }
    }

    /// Lets CI open a given screen for screenshots. See .github/screenshot-list.txt.
    private func applyLaunchOptions() {
        guard !didApplyLaunchOptions else { return }
        didApplyLaunchOptions = true
        let options = LaunchOptions.current
        if options.showNewProject { showingNew = true }
        if let pane = options.openWorkspacePane, let first = store.recentProjects.first {
            path = [WorkspaceRoute(id: first.id, pane: pane)]
        }
    }
}

/// A recent project: live thumbnail, name and last edit time.
struct ProjectCard: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SpecThumbnail(spec: project.spec)
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .background(Color(uiColor: .systemBackground))
            Divider()
            VStack(alignment: .leading, spacing: 3) {
                Text(project.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(project.updatedAt, format: .relative(presentation: .named))
                    Text("·")
                    Text("v\(project.currentVersion?.number ?? 1)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).strokeBorder(Theme.border, lineWidth: 0.5))
        .contentShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(project.name), version \(project.currentVersion?.number ?? 1)")
        .accessibilityValue(Text(project.updatedAt, format: .relative(presentation: .named)))
        .accessibilityHint("Opens the project")
    }
}

private struct ExampleCard: View {
    let example: ExampleProject

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: example.symbol)
                .font(.title3)
                .foregroundStyle(Theme.accent)
                .frame(width: 40, height: 40)
                .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(example.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Text(example.blurb).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(padding: 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Creates a project from this example")
    }
}
