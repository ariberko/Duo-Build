import Foundation

/// The small, safe description of a screen that the AI writes and DuoBuild draws.
///
/// Only the components in `UINode.Kind` can ever be shown, and nothing in a spec
/// is ever run as code. Unknown values decode to safe fallbacks instead of failing.
struct UISpec: Codable, Equatable, Hashable {
    var title: String
    var theme: SpecTheme
    var nodes: [UINode]

    init(title: String, theme: SpecTheme = SpecTheme(), nodes: [UINode]) {
        self.title = title
        self.theme = theme
        self.nodes = nodes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "Untitled"
        theme = try c.decodeIfPresent(SpecTheme.self, forKey: .theme) ?? SpecTheme()
        nodes = try c.decodeIfPresent([UINode].self, forKey: .nodes) ?? []
    }

    /// Every node in the tree, depth first.
    var allNodes: [UINode] {
        func walk(_ nodes: [UINode]) -> [UINode] {
            nodes.flatMap { [$0] + walk($0.children ?? []) }
        }
        return walk(nodes)
    }
}

struct SpecTheme: Codable, Equatable, Hashable {
    var accent: SpecColor = .blue
    var background: SpecBackground = .system
    var spacing: SpecSpacing = .medium

    init(accent: SpecColor = .blue, background: SpecBackground = .system, spacing: SpecSpacing = .medium) {
        self.accent = accent
        self.background = background
        self.spacing = spacing
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        accent = try c.decodeIfPresent(SpecColor.self, forKey: .accent) ?? .blue
        background = try c.decodeIfPresent(SpecBackground.self, forKey: .background) ?? .system
        spacing = try c.decodeIfPresent(SpecSpacing.self, forKey: .spacing) ?? .medium
    }
}

/// One component on the screen.
struct UINode: Codable, Equatable, Hashable, Identifiable {
    enum Kind: String, Codable, CaseIterable {
        case text, button, card, image, list, input, stack, divider, spacer, unsupported

        init(from decoder: Decoder) throws {
            self = try decoder.lenientValue(fallback: .unsupported)
        }
    }

    var id: String
    var kind: Kind
    /// Text content, button label, card title or input placeholder.
    var text: String?
    /// Card subtitle.
    var detail: String?
    var style: TextStyle?
    /// An SF Symbol name for images, cards and list rows.
    var symbol: String?
    var color: SpecColor?
    /// Rows of a list.
    var items: [String]?
    var axis: StackAxis?
    var spacing: SpecSpacing?
    var size: ImageSize?
    /// What a button says when tapped in the preview.
    var message: String?
    var children: [UINode]?

    enum CodingKeys: String, CodingKey {
        case id, kind = "type", text, detail, style, symbol, color, items, axis, spacing, size, message, children
    }

    init(
        id: String = UINode.newID(), kind: Kind, text: String? = nil, detail: String? = nil,
        style: TextStyle? = nil, symbol: String? = nil, color: SpecColor? = nil, items: [String]? = nil,
        axis: StackAxis? = nil, spacing: SpecSpacing? = nil, size: ImageSize? = nil,
        message: String? = nil, children: [UINode]? = nil
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.detail = detail
        self.style = style
        self.symbol = symbol
        self.color = color
        self.items = items
        self.axis = axis
        self.spacing = spacing
        self.size = size
        self.message = message
        self.children = children
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UINode.newID()
        kind = try c.decodeIfPresent(Kind.self, forKey: .kind) ?? .unsupported
        text = try c.decodeIfPresent(String.self, forKey: .text)
        detail = try c.decodeIfPresent(String.self, forKey: .detail)
        style = try c.decodeIfPresent(TextStyle.self, forKey: .style)
        symbol = try c.decodeIfPresent(String.self, forKey: .symbol)
        color = try c.decodeIfPresent(SpecColor.self, forKey: .color)
        items = try c.decodeIfPresent([String].self, forKey: .items)
        axis = try c.decodeIfPresent(StackAxis.self, forKey: .axis)
        spacing = try c.decodeIfPresent(SpecSpacing.self, forKey: .spacing)
        size = try c.decodeIfPresent(ImageSize.self, forKey: .size)
        message = try c.decodeIfPresent(String.self, forKey: .message)
        children = try c.decodeIfPresent([UINode].self, forKey: .children)
    }

    static func newID() -> String {
        String(UUID().uuidString.prefix(8)).lowercased()
    }

    // MARK: Builders

    static func text(_ text: String, _ style: TextStyle = .body, color: SpecColor? = nil) -> UINode {
        UINode(kind: .text, text: text, style: style, color: color)
    }

    static func button(_ label: String, message: String? = nil, secondary: Bool = false) -> UINode {
        UINode(kind: .button, text: label, style: secondary ? .caption : nil, message: message)
    }

    static func card(_ title: String, detail: String? = nil, symbol: String? = nil, children: [UINode]? = nil) -> UINode {
        UINode(kind: .card, text: title, detail: detail, symbol: symbol, children: children)
    }

    static func image(_ symbol: String, size: ImageSize = .medium, color: SpecColor? = nil) -> UINode {
        UINode(kind: .image, symbol: symbol, color: color, size: size)
    }

    static func list(_ items: [String], symbol: String? = nil) -> UINode {
        UINode(kind: .list, symbol: symbol, items: items)
    }

    static func input(_ placeholder: String) -> UINode {
        UINode(kind: .input, text: placeholder)
    }

    static func vstack(spacing: SpecSpacing? = nil, _ children: [UINode]) -> UINode {
        UINode(kind: .stack, axis: .vertical, spacing: spacing, children: children)
    }

    static func hstack(spacing: SpecSpacing? = nil, _ children: [UINode]) -> UINode {
        UINode(kind: .stack, axis: .horizontal, spacing: spacing, children: children)
    }

    static var divider: UINode { UINode(kind: .divider) }
    static var spacer: UINode { UINode(kind: .spacer) }
}

enum TextStyle: String, Codable, CaseIterable {
    case largeTitle, title, headline, body, caption
    init(from decoder: Decoder) throws { self = try decoder.lenientValue(fallback: .body) }
}

enum SpecColor: String, Codable, CaseIterable {
    case blue, indigo, purple, pink, red, orange, yellow, green, mint, teal, brown, gray, primary, secondary
    init(from decoder: Decoder) throws { self = try decoder.lenientValue(fallback: .blue) }

    /// Colors a person can ask for by name.
    static var namedAccents: [SpecColor] { allCases.filter { $0 != .primary && $0 != .secondary } }
}

enum SpecBackground: String, Codable, CaseIterable {
    case system, grouped, tinted, dark
    init(from decoder: Decoder) throws { self = try decoder.lenientValue(fallback: .system) }
}

enum SpecSpacing: String, Codable, CaseIterable {
    // Not called `none`, which would clash with Optional.none.
    case zero = "none", small, medium, large
    init(from decoder: Decoder) throws { self = try decoder.lenientValue(fallback: .medium) }

    var points: Double {
        switch self {
        case .zero: 0
        case .small: 6
        case .medium: 12
        case .large: 20
        }
    }
}

enum StackAxis: String, Codable, CaseIterable {
    case vertical, horizontal
    init(from decoder: Decoder) throws { self = try decoder.lenientValue(fallback: .vertical) }
}

enum ImageSize: String, Codable, CaseIterable {
    case small, medium, large
    init(from decoder: Decoder) throws { self = try decoder.lenientValue(fallback: .medium) }

    var height: Double {
        switch self {
        case .small: 64
        case .medium: 140
        case .large: 200
        }
    }
}

extension Decoder {
    /// Decodes a string enum, matching case-insensitively and falling back instead of failing.
    func lenientValue<T: RawRepresentable & CaseIterable>(fallback: T) throws -> T where T.RawValue == String {
        let raw = try singleValueContainer().decode(String.self)
        if let exact = T(rawValue: raw) { return exact }
        return T.allCases.first { $0.rawValue.lowercased() == raw.lowercased() } ?? fallback
    }
}
