import Foundation

/// Demo mode. Builds designs from built-in templates and simple rules, with no network and no AI.
/// The same input always gives the same design. It always says it's a demo.
struct DemoAIService: AIService {
    var isDemo: Bool { true }
    /// How long each fake step takes. Tests set this to zero.
    var stepDelay: Duration = .milliseconds(450)

    func generate(name: String, prompt: String, progress: @escaping @Sendable (String) async -> Void) async throws -> GenerationResult {
        for step in ["Reading your description…", "Picking a demo template…", "Laying out components…"] {
            await progress(step)
            try await Task.sleep(for: stepDelay)
        }
        let result = DemoEngine.generate(name: name, prompt: prompt)
        await progress("Checking the design…")
        try await Task.sleep(for: stepDelay / 2)
        return GenerationResult(spec: try SpecValidator.validate(result.spec), summary: result.summary)
    }

    func refine(spec: UISpec, instruction: String, history: [ChatMessage], progress: @escaping @Sendable (String) async -> Void) async throws -> GenerationResult {
        await progress("Reading your change…")
        try await Task.sleep(for: stepDelay)
        let result = try DemoEngine.refine(spec, instruction: instruction)
        await progress("Updating the preview…")
        try await Task.sleep(for: stepDelay / 2)
        return GenerationResult(spec: try SpecValidator.validate(result.spec), summary: result.summary)
    }
}

/// The rules behind Demo mode. Plain functions, so they're easy to test.
enum DemoEngine {
    static let label = "Demo mode"

    // MARK: Generate

    static func generate(name: String, prompt: String) -> GenerationResult {
        let lower = prompt.lowercased()
        let template = DemoTemplates.all.first { t in t.keywords.contains { lower.contains($0) } }
        var spec: UISpec
        var summary: String
        if let template {
            spec = template.make(name)
            summary = "\(label): built a \(template.title.lowercased()) from a built-in template."
        } else {
            spec = DemoTemplates.generic(name: name, prompt: prompt)
            summary = "\(label): no template matched, so I made a simple starter screen. Refine it with follow-up changes."
        }
        // Apply any styling words in the first prompt, like "in green" or "dark".
        if let styled = try? applyRules(to: spec, instruction: prompt, stylingOnly: true), !styled.changes.isEmpty {
            spec = styled.spec
            summary += " Also: " + styled.changes.joined(separator: ", ") + "."
        }
        return GenerationResult(spec: spec, summary: summary)
    }

    // MARK: Refine

    static func refine(_ spec: UISpec, instruction: String) throws -> GenerationResult {
        let result = try applyRules(to: spec, instruction: instruction, stylingOnly: false)
        guard !result.changes.isEmpty else {
            throw AIError.notUnderstood(suggestions: suggestions(for: spec))
        }
        return GenerationResult(spec: result.spec, summary: "\(label): " + result.changes.joined(separator: "; ") + ".")
    }

    /// Ideas shown under the composer. Every one of them works in Demo mode.
    static func suggestions(for spec: UISpec) -> [String] {
        var ideas: [String] = []
        let accent = spec.theme.accent
        ideas.append(accent == .green ? "Make it orange" : "Make it green")
        let kinds = Set(spec.allNodes.map(\.kind))
        if !kinds.contains(.input) { ideas.append("Add a search field") }
        ideas.append("Add a button that says Share")
        ideas.append(spec.theme.background == .dark ? "Use a light background" : "Use a dark background")
        ideas.append(spec.theme.spacing == .small ? "Add more space" : "Make it more compact")
        if !kinds.contains(.image) { ideas.append("Add a hero image") }
        ideas.append("Add a list of Today, This week, Later")
        ideas.append("Rename it to My App")
        return ideas
    }

    private struct RuleResult {
        var spec: UISpec
        var changes: [String]
    }

    private static func applyRules(to original: UISpec, instruction: String, stylingOnly: Bool) throws -> RuleResult {
        var spec = original
        var changes: [String] = []
        for clause in clauses(of: instruction) {
            let lower = clause.lowercased()

            // Colors
            if let color = SpecColor.namedAccents.first(where: { containsWord(lower, $0.rawValue) }),
               !lower.contains("background") || lower.contains("accent") {
                spec.theme.accent = color
                changes.append("accent color is now \(color.rawValue)")
            }

            // Background
            if containsWord(lower, "dark") {
                spec.theme.background = .dark
                changes.append("dark background")
            } else if containsWord(lower, "light") && (lower.contains("background") || lower.contains("mode") || lower.contains("theme")) {
                spec.theme.background = .system
                changes.append("light background")
            } else if lower.contains("tinted") || lower.contains("colorful background") {
                spec.theme.background = .tinted
                changes.append("tinted background")
            }

            // Spacing
            if ["compact", "tighter", "less space", "denser", "smaller gaps"].contains(where: { lower.contains($0) }) {
                spec.theme.spacing = .small
                changes.append("compact spacing")
            } else if ["more space", "roomier", "spacious", "breathing room", "bigger gaps"].contains(where: { lower.contains($0) }) {
                spec.theme.spacing = .large
                changes.append("more spacing")
            }

            if stylingOnly { continue }

            // Title
            if let newTitle = capture(#"(?:rename (?:it|the app|this)? ?to|call it|name it|change the title to|title it|set the title to)\s+["“']?(.+?)["”']?$"#, in: clause) {
                spec.title = newTitle
                if let i = spec.nodes.firstIndex(where: { $0.kind == .text && ($0.style == .largeTitle || $0.style == .title) }) {
                    spec.nodes[i].text = newTitle
                } else {
                    spec.nodes.insert(.text(newTitle, .largeTitle), at: 0)
                }
                changes.append("renamed to “\(newTitle)”")
                continue
            }

            if lower.contains("bigger title") || lower.contains("larger title") || lower.contains("bigger heading") {
                if let i = spec.nodes.firstIndex(where: { $0.kind == .text }) {
                    spec.nodes[i].style = .largeTitle
                    changes.append("bigger title")
                }
            }

            // Remove
            if let what = capture(#"(?:remove|delete|get rid of|drop)\s+(?:the\s+|all\s+|all the\s+)?(.+)$"#, in: lower) {
                if what.hasPrefix("last") {
                    if spec.nodes.count > 1 {
                        spec.nodes.removeLast()
                        changes.append("removed the last component")
                    }
                } else if let kind = kind(named: what) {
                    let kept = removing(kind, from: spec.nodes)
                    let removed = spec.allNodes.count - UISpec(title: "", nodes: kept).allNodes.count
                    // Never remove everything: an empty screen can't be previewed.
                    if removed > 0, !kept.isEmpty {
                        spec.nodes = kept
                        changes.append("removed \(removed) \(kind.rawValue)\(removed == 1 ? "" : "s")")
                    }
                }
                continue
            }

            // Add
            if lower.contains("add") || lower.contains("include") || lower.contains("put") || lower.contains("insert") {
                if let node = newNode(for: clause) {
                    if node.kind == .image {
                        let at = spec.nodes.firstIndex(where: { $0.kind == .text }).map { $0 + 1 } ?? 0
                        spec.nodes.insert(node, at: min(at, spec.nodes.count))
                    } else {
                        spec.nodes.append(node)
                    }
                    changes.append("added \(describe(node))")
                }
            }
        }
        return RuleResult(spec: spec, changes: changes)
    }

    private static func newNode(for clause: String) -> UINode? {
        let lower = clause.lowercased()
        if lower.contains("button") {
            let label = capture(#"button\s+(?:that says|saying|called|labeled|labelled|named|with the text|for)\s+["“']?(.+?)["”']?$"#, in: clause)
            let text = label.map(capitalizedFirst) ?? "Get Started"
            return .button(text, message: "“\(text)” tapped")
        }
        if lower.contains("list") || lower.contains("checklist") {
            let raw = capture(#"(?:list|checklist)\s+(?:of|with|for)\s+(.+)$"#, in: clause)
            let items = raw.map(splitItems) ?? ["First item", "Second item", "Third item"]
            return .list(items.map(capitalizedFirst))
        }
        if lower.contains("search") {
            return .input("Search")
        }
        if lower.contains("field") || lower.contains("input") || lower.contains("text box") {
            let label = capture(#"(?:field|input|text box)\s+(?:for|called|labeled|labelled)\s+(?:the\s+|a\s+|an\s+)?["“']?(.+?)["”']?$"#, in: clause)
                ?? capture(#"(?:an?\s+)?(\w+)\s+(?:field|input)"#, in: clause)
            return .input(label.map(capitalizedFirst) ?? "Type here")
        }
        if lower.contains("image") || lower.contains("photo") || lower.contains("picture") || lower.contains("hero") || lower.contains("banner") {
            return .image("photo.on.rectangle.angled", size: .large)
        }
        if lower.contains("card") {
            let title = capture(#"card\s+(?:about|for|called|titled|that says|with)\s+["“']?(.+?)["”']?$"#, in: clause)
            return .card(title.map(capitalizedFirst) ?? "New card", detail: "Tap Refine to change this text.", symbol: "square.text.square")
        }
        if containsWord(lower, "divider") || containsWord(lower, "separator") || containsWord(lower, "line") {
            return .divider
        }
        if let text = capture(#"(?:text|heading|subtitle|caption|paragraph|label)\s+(?:that says|saying|with|:)\s+["“']?(.+?)["”']?$"#, in: clause) {
            let style: TextStyle = lower.contains("heading") ? .headline : lower.contains("caption") ? .caption : .body
            return .text(capitalizedFirst(text), style)
        }
        return nil
    }

    // MARK: Helpers

    /// Splits "make it green and add a button" into two requests.
    static func clauses(of text: String) -> [String] {
        let verbs = "add|make|remove|delete|change|set|use|rename|call|give|put|include|insert|drop"
        let pattern = #"\s*(?:;|\.\s+|\n|,?\s+(?:and|then|also)\s+(?=(?:"# + verbs + #")\b))\s*"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [text] }
        let ns = text as NSString
        var parts: [String] = []
        var start = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            parts.append(ns.substring(with: NSRange(location: start, length: match.range.location - start)))
            start = match.range.location + match.range.length
        }
        parts.append(ns.substring(from: start))
        return parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".!"))) }
            .filter { !$0.isEmpty }
    }

    private static func capture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else { return nil }
        let value = text[range].trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"“”'.!")))
        return value.isEmpty ? nil : String(value.prefix(60))
    }

    private static func containsWord(_ text: String, _ word: String) -> Bool {
        capture(#"\b("# + NSRegularExpression.escapedPattern(for: word) + #")\b"#, in: text) != nil
    }

    private static func splitItems(_ text: String) -> [String] {
        text.replacingOccurrences(of: " and ", with: ",")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func capitalizedFirst(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }

    private static func kind(named text: String) -> UINode.Kind? {
        let map: [(String, UINode.Kind)] = [
            ("button", .button), ("list", .list), ("image", .image), ("photo", .image), ("picture", .image),
            ("card", .card), ("field", .input), ("input", .input), ("search", .input), ("divider", .divider),
        ]
        return map.first { text.contains($0.0) }?.1
    }

    private static func removing(_ kind: UINode.Kind, from nodes: [UINode]) -> [UINode] {
        nodes.compactMap { node in
            guard node.kind != kind else { return nil }
            var n = node
            n.children = n.children.map { removing(kind, from: $0) }
            return n
        }
    }

    private static func describe(_ node: UINode) -> String {
        switch node.kind {
        case .button: "a “\(node.text ?? "")” button"
        case .list: "a list with \(node.items?.count ?? 0) items"
        case .input: "a “\(node.text ?? "")” field"
        case .image: "an image"
        case .card: "a “\(node.text ?? "")” card"
        case .divider: "a divider"
        case .text: "text"
        default: "a component"
        }
    }
}
