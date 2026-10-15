import Foundation
import Observation

/// Keeps every project in one JSON file in Application Support, on this device only.
@MainActor
@Observable
final class ProjectStore {
    private(set) var projects: [Project] = []
    /// Set when the saved file couldn't be read. The bad file is kept as a backup.
    var loadProblem: String?
    var saveProblem: String?

    let fileURL: URL

    init(directory: URL? = nil, seedIfNew: Bool = true) {
        let folder = directory ?? Self.defaultDirectory
        fileURL = folder.appendingPathComponent("projects.json")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        load(seedIfNew: seedIfNew)
    }

    static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("DuoBuild", isDirectory: true)
    }

    /// Newest first.
    var recentProjects: [Project] {
        projects.sorted { $0.updatedAt > $1.updatedAt }
    }

    func project(id: UUID) -> Project? {
        projects.first { $0.id == id }
    }

    // MARK: Changes

    func add(_ project: Project) {
        projects.append(project)
        save()
    }

    /// Changes one project in place and saves.
    func update(_ id: UUID, _ change: (inout Project) -> Void) {
        guard let i = projects.firstIndex(where: { $0.id == id }) else { return }
        change(&projects[i])
        save()
    }

    func rename(_ id: UUID, to name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        update(id) {
            $0.name = clean
            $0.updatedAt = Date()
        }
    }

    @discardableResult
    func duplicate(_ id: UUID) -> Project? {
        guard let original = project(id: id) else { return nil }
        let copy = original.duplicated(name: uniqueName(for: original.name + " Copy"))
        add(copy)
        return copy
    }

    func delete(_ id: UUID) {
        projects.removeAll { $0.id == id }
        save()
    }

    func restoreExamples() {
        for sample in SampleData.seedProjects() where !projects.contains(where: { $0.name == sample.name }) {
            projects.append(sample)
        }
        save()
    }

    func uniqueName(for base: String) -> String {
        let names = Set(projects.map(\.name))
        guard names.contains(base) else { return base }
        var n = 2
        while names.contains("\(base) \(n)") { n += 1 }
        return "\(base) \(n)"
    }

    // MARK: Disk

    private struct FileContents: Codable {
        var formatVersion = 1
        var projects: [Project]
    }

    private func load(seedIfNew: Bool) {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            if seedIfNew {
                projects = SampleData.seedProjects()
                save()
            }
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            projects = try Self.decoder.decode(FileContents.self, from: data).projects
        } catch {
            let stamp = Int(Date().timeIntervalSince1970)
            let backup = fileURL.deletingLastPathComponent().appendingPathComponent("projects-unreadable-\(stamp).json")
            try? FileManager.default.moveItem(at: fileURL, to: backup)
            loadProblem = "Your saved projects couldn't be read, so DuoBuild started fresh. The old file was kept as \(backup.lastPathComponent)."
            projects = []
        }
    }

    func save() {
        do {
            let data = try Self.encoder.encode(FileContents(projects: projects))
            try data.write(to: fileURL, options: [.atomic])
            saveProblem = nil
        } catch {
            saveProblem = "Couldn't save your projects: \(error.localizedDescription)"
        }
    }

    // Default date coding keeps full precision, so versions round-trip exactly.
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()
}
