import Foundation

/// Checks and cleans a spec before DuoBuild shows or saves it.
/// Anything that came from an AI goes through here first.
enum SpecValidator {
    static let maxNodes = 150
    static let maxDepth = 5
    static let maxTextLength = 400
    static let maxItems = 30

    enum Failure: LocalizedError, Equatable {
        case empty
        case tooManyComponents(Int)
        case tooDeep

        var errorDescription: String? {
            switch self {
            case .empty:
                "The design came back empty."
            case .tooManyComponents(let count):
                "The design has \(count) components. DuoBuild previews up to \(SpecValidator.maxNodes)."
            case .tooDeep:
                "The design nests containers more than \(SpecValidator.maxDepth) levels deep."
            }
        }
    }

    /// Returns a cleaned copy: trimmed text, capped lists, safe symbol names and unique ids.
    static func validate(_ spec: UISpec) throws -> UISpec {
        guard !spec.nodes.isEmpty else { throw Failure.empty }
        let count = spec.allNodes.count
        guard count <= maxNodes else { throw Failure.tooManyComponents(count) }
        guard depth(of: spec.nodes) <= maxDepth else { throw Failure.tooDeep }

        var seen = Set<String>()
        var clean = spec
        clean.title = trim(spec.title) ?? "Untitled"
        clean.nodes = spec.nodes.map { sanitize($0, seen: &seen) }
        return clean
    }

    static func depth(of nodes: [UINode]) -> Int {
        nodes.map { 1 + depth(of: $0.children ?? []) }.max() ?? 0
    }

    private static func sanitize(_ node: UINode, seen: inout Set<String>) -> UINode {
        var n = node
        if n.id.isEmpty || seen.contains(n.id) { n.id = UINode.newID() }
        seen.insert(n.id)
        n.text = trim(n.text)
        n.detail = trim(n.detail)
        n.message = trim(n.message)
        n.symbol = safeSymbol(n.symbol)
        n.items = n.items.map { Array($0.prefix(maxItems).compactMap { trim($0) }) }
        n.children = n.children.map { $0.map { sanitize($0, seen: &seen) } }
        return n
    }

    private static func trim(_ text: String?) -> String? {
        guard let text else { return nil }
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : String(t.prefix(maxTextLength))
    }

    /// SF Symbol names only use lowercase letters, digits and dots.
    static func safeSymbol(_ name: String?) -> String? {
        guard let name, !name.isEmpty, name.count <= 60 else { return nil }
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789.")
        return name.allSatisfy { allowed.contains($0) } ? name : nil
    }
}
