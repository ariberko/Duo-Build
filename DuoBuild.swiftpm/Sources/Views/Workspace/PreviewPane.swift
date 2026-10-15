import SwiftUI

/// Preview sizes. "Fit" fills the pane. The others mimic common iPhone widths.
enum PreviewDevice: String, CaseIterable, Identifiable {
    case fit, phone, small

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fit: "Fit to Pane"
        case .phone: "iPhone"
        case .small: "Small iPhone"
        }
    }

    var symbol: String {
        switch self {
        case .fit: "rectangle.expand.vertical"
        case .phone: "iphone"
        case .small: "iphone.gen1"
        }
    }

    /// Points, or nil to fill the pane.
    var size: CGSize? {
        switch self {
        case .fit: nil
        case .phone: CGSize(width: 393, height: 852)
        case .small: CGSize(width: 320, height: 568)
        }
    }
}

struct PreviewOptions: Equatable {
    var device: PreviewDevice = .fit
    /// Changing this rebuilds the preview from the saved design.
    var reloadToken = UUID()
}

/// The right pane: draws the current design in a safe, sandboxed preview.
struct PreviewPane: View {
    let project: Project
    let interaction: PreviewInteraction
    @Binding var options: PreviewOptions
    let isUpdating: Bool

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            GeometryReader { geo in
                deviceFrame(in: geo.size)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Theme.canvas)
        }
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Preview").font(.subheadline.weight(.semibold))
                Text("Not an installed app")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)

            Menu {
                Picker("Preview Size", selection: $options.device) {
                    ForEach(PreviewDevice.allCases) { device in
                        Label(device.title, systemImage: device.symbol).tag(device)
                    }
                }
            } label: {
                Label(options.device.title, systemImage: options.device.symbol)
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 32, minHeight: 32)
            }
            .accessibilityLabel("Preview size: \(options.device.title)")

            Button {
                options.reloadToken = UUID()
                interaction.show("Preview refreshed")
            } label: {
                Image(systemName: "arrow.clockwise").frame(minWidth: 32, minHeight: 32)
            }
            .accessibilityLabel("Refresh Preview")
            .help("Redraw the preview from the saved design")

            Button {
                interaction.reset()
                options.reloadToken = UUID()
                interaction.show("Preview reset")
            } label: {
                Image(systemName: "arrow.counterclockwise").frame(minWidth: 32, minHeight: 32)
            }
            .accessibilityLabel("Reset Preview")
            .help("Clear typed text and checked items")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: Device frame

    private func deviceFrame(in available: CGSize) -> some View {
        let maxWidth = max(available.width - 32, 200)
        let maxHeight = max(available.height - 32, 200)
        let width = options.device.size.map { min($0.width, maxWidth) } ?? maxWidth
        let height = options.device.size.map { min($0.height, maxHeight) } ?? maxHeight

        return VStack(spacing: 0) {
            HStack(spacing: 6) {
                Circle().fill(Color.secondary.opacity(0.4)).frame(width: 6, height: 6)
                Text("PREVIEW · \(project.spec.title)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let version = project.currentVersion {
                    Text("v\(version.number)").font(.caption2.monospacedDigit()).foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color(uiColor: .secondarySystemBackground))

            ScrollView {
                SpecCanvas(spec: project.spec, interaction: interaction)
                    .transition(.opacity)
            }
            .id(options.reloadToken)
            .background(Color(uiColor: .systemBackground))
            .animation(.smooth, value: project.spec)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        .opacity(isUpdating ? 0.55 : 1)
        .overlay(alignment: .top) {
            if isUpdating {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Updating preview…").font(.footnote.weight(.medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: Capsule())
                .padding(.top, 40)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isUpdating)
        .animation(.snappy, value: options.device)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Preview of \(project.spec.title)")
    }
}
