import Foundation

struct ChatMessage: Codable, Equatable, Hashable, Identifiable {
    enum Role: String, Codable {
        /// What the person typed.
        case user
        /// A successful answer from the AI service.
        case assistant
        /// A failed request. The design was not changed.
        case error
        /// A note from DuoBuild itself, like "Restored version 2".
        case note
    }

    var id = UUID()
    var role: Role
    var text: String
    var date = Date()
    /// The version this message created, if any.
    var versionID: UUID?
}

struct ProjectVersion: Codable, Equatable, Hashable, Identifiable {
    var id = UUID()
    var number: Int
    var date = Date()
    var summary: String
    var spec: UISpec
}

struct Project: Codable, Equatable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var originalPrompt: String
    var spec: UISpec
    var messages: [ChatMessage] = []
    var versions: [ProjectVersion] = []
    var currentVersionID: UUID?
    var createdAt = Date()
    var updatedAt = Date()

    init(name: String, originalPrompt: String, spec: UISpec, summary: String, date: Date = Date()) {
        self.name = name
        self.originalPrompt = originalPrompt
        self.spec = spec
        createdAt = date
        updatedAt = date
        messages.append(ChatMessage(role: .user, text: originalPrompt, date: date))
        let version = commit(spec, summary: summary, date: date)
        messages.append(ChatMessage(role: .assistant, text: summary, date: date, versionID: version.id))
    }

    var currentVersion: ProjectVersion? {
        versions.first { $0.id == currentVersionID }
    }

    /// Saves a new version and makes it the current design.
    @discardableResult
    mutating func commit(_ spec: UISpec, summary: String, date: Date = Date()) -> ProjectVersion {
        let version = ProjectVersion(number: (versions.map(\.number).max() ?? 0) + 1, date: date, summary: summary, spec: spec)
        versions.append(version)
        self.spec = spec
        currentVersionID = version.id
        updatedAt = date
        return version
    }

    /// Brings back an older version as a new version, so nothing is lost.
    @discardableResult
    mutating func restore(_ versionID: UUID) -> ProjectVersion? {
        guard let old = versions.first(where: { $0.id == versionID }) else { return nil }
        let version = commit(old.spec, summary: "Restored version \(old.number)")
        messages.append(ChatMessage(role: .note, text: "Restored version \(old.number). Saved as version \(version.number).", versionID: version.id))
        return version
    }

    /// A full copy with a new id, so it can be edited on its own.
    func duplicated(name: String) -> Project {
        var copy = self
        copy.id = UUID()
        copy.name = name
        copy.createdAt = Date()
        copy.updatedAt = Date()
        return copy
    }
}
