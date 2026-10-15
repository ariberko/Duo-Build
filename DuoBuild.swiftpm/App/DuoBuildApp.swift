import SwiftUI

@main
struct DuoBuildApp: App {
    @State private var store: ProjectStore
    @State private var settings = AISettings()

    init() {
        let options = LaunchOptions.current
        if options.freshStart {
            try? FileManager.default.removeItem(at: ProjectStore.defaultDirectory)
        }
        _store = State(initialValue: ProjectStore())
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(store)
                .environment(settings)
                .tint(Theme.accent)
        }
    }
}

/// Launch arguments used by the screenshot workflow. They do nothing in normal use.
struct LaunchOptions {
    var freshStart = false
    var showNewProject = false
    var openWorkspacePane: WorkspacePane?

    static let current: LaunchOptions = {
        let args = ProcessInfo.processInfo.arguments
        var options = LaunchOptions()
        options.freshStart = args.contains("-freshStart")
        options.showNewProject = args.contains("-showNewProject")
        if let i = args.firstIndex(of: "-openWorkspace"), i + 1 < args.count {
            options.openWorkspacePane = WorkspacePane(rawValue: args[i + 1])
        }
        return options
    }()
}
