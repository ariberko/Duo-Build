import SwiftUI
import UIKit

/// What the person has done inside the preview: typed text, checked rows, tapped buttons.
/// It lives outside the preview views so it survives layout changes, like opening the phone.
@MainActor
@Observable
final class PreviewInteraction {
    var inputs: [String: String] = [:]
    var checked: Set<String> = []
    var toast: String?
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    func tap(_ node: UINode) {
        show(node.message ?? "“\(node.text ?? "Button")” tapped")
        Haptics.tap()
    }

    func toggle(_ key: String) {
        if checked.contains(key) { checked.remove(key) } else { checked.insert(key) }
    }

    func show(_ text: String) {
        toastTask?.cancel()
        withAnimation(.snappy) { toast = text }
        toastTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut) { toast = nil }
        }
    }

    func reset() {
        inputs = [:]
        checked = []
        toast = nil
    }
}

extension SpecColor {
    var color: Color {
        switch self {
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .pink: .pink
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .mint: .mint
        case .teal: .teal
        case .brown: .brown
        case .gray: .gray
        case .primary: .primary
        case .secondary: .secondary
        }
    }
}

extension TextStyle {
    var font: Font {
        switch self {
        case .largeTitle: .largeTitle.bold()
        case .title: .title2.bold()
        case .headline: .headline
        case .body: .body
        case .caption: .footnote
        }
    }
}

/// Draws a `UISpec` with real SwiftUI controls. Only the supported components exist here.
/// Pass `interaction: nil` for a still picture, like a thumbnail.
struct SpecCanvas: View {
    let spec: UISpec
    var interaction: PreviewInteraction?

    var body: some View {
        VStack(alignment: .leading, spacing: spec.theme.spacing.points) {
            ForEach(spec.nodes) { node in
                NodeView(node: node, theme: spec.theme, interaction: interaction, parentAxis: .vertical)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .tint(spec.theme.accent.color)
        .environment(\.colorScheme, spec.theme.background == .dark ? .dark : colorScheme)
        .background(backgroundColor)
    }

    @Environment(\.colorScheme) private var colorScheme

    private var backgroundColor: Color {
        switch spec.theme.background {
        case .system: Color(uiColor: .systemBackground)
        case .grouped: Color(uiColor: .systemGroupedBackground)
        case .tinted: spec.theme.accent.color.opacity(0.08)
        case .dark: Color(white: 0.07)
        }
    }
}

private struct NodeView: View {
    let node: UINode
    let theme: SpecTheme
    let interaction: PreviewInteraction?
    let parentAxis: StackAxis

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var content: some View {
        switch node.kind {
        case .text:
            Text(node.text ?? "")
                .font((node.style ?? .body).font)
                .foregroundStyle(node.color?.color ?? .primary)
                .fixedSize(horizontal: false, vertical: true)

        case .button:
            Button {
                interaction?.tap(node)
            } label: {
                Text(node.text ?? "Button")
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity)
            }
            .modifier(SpecButtonStyle(secondary: node.style == .caption))
            .tint(node.color?.color ?? theme.accent.color)

        case .card:
            VStack(alignment: .leading, spacing: 6) {
                if let symbol = node.symbol, UIImage(systemName: symbol) != nil {
                    Image(systemName: symbol)
                        .font(.title3)
                        .foregroundStyle(node.color?.color ?? theme.accent.color)
                }
                if let text = node.text {
                    Text(text).font(.headline)
                }
                if let detail = node.detail {
                    Text(detail).font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(node.children ?? []) { child in
                    NodeView(node: child, theme: theme, interaction: interaction, parentAxis: .vertical)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

        case .image:
            // Images are built-in symbols on a soft tile. The preview never loads anything from the web.
            let tint = node.color?.color ?? theme.accent.color
            let height = (node.size ?? .medium).height
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(tint.opacity(0.14))
                Image(systemName: validSymbol(node.symbol) ?? "photo")
                    .font(.system(size: height * 0.38))
                    .foregroundStyle(tint)
            }
            .frame(height: height)
            .accessibilityLabel("Image placeholder")

        case .list:
            let items = node.items ?? []
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    ListRow(node: node, index: index, item: item, interaction: interaction, accent: theme.accent.color)
                    if index < items.count - 1 {
                        Divider().padding(.leading, 44)
                    }
                }
            }
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

        case .input:
            let placeholder = node.text ?? "Type here"
            Group {
                if let interaction {
                    TextField(placeholder, text: Binding(
                        get: { interaction.inputs[node.id, default: ""] },
                        set: { interaction.inputs[node.id] = $0 }
                    ))
                } else {
                    Text(placeholder).foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

        case .stack:
            let spacing = (node.spacing ?? theme.spacing).points
            let children = node.children ?? []
            if node.axis == .horizontal {
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(children) { child in
                        NodeView(node: child, theme: theme, interaction: interaction, parentAxis: .horizontal)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: spacing) {
                    ForEach(children) { child in
                        NodeView(node: child, theme: theme, interaction: interaction, parentAxis: .vertical)
                    }
                }
            }

        case .divider:
            Divider()

        case .spacer:
            Color.clear.frame(height: 16)

        case .unsupported:
            Label("Unsupported component", systemImage: "questionmark.square.dashed")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4])).foregroundStyle(.tertiary))
        }
    }

    private func validSymbol(_ name: String?) -> String? {
        guard let name, UIImage(systemName: name) != nil else { return nil }
        return name
    }
}

private struct ListRow: View {
    let node: UINode
    let index: Int
    let item: String
    let interaction: PreviewInteraction?
    let accent: Color

    private var key: String { "\(node.id)#\(index)" }

    var body: some View {
        let isChecked = interaction?.checked.contains(key) ?? false
        let symbol = node.symbol.flatMap { UIImage(systemName: $0) != nil ? $0 : nil } ?? "circle"
        Button {
            interaction?.toggle(key)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : symbol)
                    .foregroundStyle(isChecked ? accent : .secondary)
                    .frame(width: 20)
                Text(item)
                    .strikethrough(isChecked && symbol == "circle")
                    .foregroundStyle(isChecked ? Color.secondary : Color.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isChecked ? .isSelected : [])
    }
}

private struct SpecButtonStyle: ViewModifier {
    let secondary: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if secondary {
            content.buttonStyle(.bordered).controlSize(.large)
        } else {
            content.buttonStyle(.borderedProminent).controlSize(.large)
        }
    }
}

/// A small, still picture of a design for project cards and version history.
struct SpecThumbnail: View {
    let spec: UISpec
    /// The width the design is laid out at before being shrunk.
    var designWidth: CGFloat = 340

    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.width / designWidth
            SpecCanvas(spec: spec)
                .frame(width: designWidth, height: geo.size.height / max(scale, 0.01), alignment: .top)
                .clipped()
                .scaleEffect(scale, anchor: .topLeading)
        }
        .dynamicTypeSize(.medium)
        .allowsHitTesting(false)
        .clipped()
        .accessibilityHidden(true)
    }
}
