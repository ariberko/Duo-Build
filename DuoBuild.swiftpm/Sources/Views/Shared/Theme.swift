import SwiftUI
import UIKit

/// DuoBuild's look: neutral system surfaces, thin borders and one accent color.
enum Theme {
    /// The one accent. A calm indigo that works in light and dark.
    static let accent = Color(red: 0.36, green: 0.38, blue: 0.90)
    static let corner: CGFloat = 12
    static let border = Color(uiColor: .separator).opacity(0.6)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let canvas = Color(uiColor: .systemGroupedBackground)
    static let raised = Color(uiColor: .tertiarySystemFill)
}

extension View {
    /// A quiet card: system surface, rounded corners and a hairline border.
    func surfaceCard(padding: CGFloat = 14) -> some View {
        self
            .padding(padding)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).strokeBorder(Theme.border, lineWidth: 0.5))
    }
}

/// A small capsule label, like "DEMO" or "Version 3".
struct Tag: View {
    let text: String
    var symbol: String?
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol) }
            Text(text)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(tint.opacity(0.12), in: Capsule())
    }
}

/// A short message that slides in at the bottom and goes away by itself.
struct ToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 0.5))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
            .accessibilityAddTraits(.isStaticText)
    }
}

@MainActor
enum Haptics {
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func failure() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}
