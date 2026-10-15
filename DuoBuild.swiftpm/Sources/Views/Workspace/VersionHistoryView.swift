import SwiftUI

/// Every saved version of a project, newest first. Restoring adds a new version, so nothing is lost.
struct VersionHistoryView: View {
    let project: Project
    let canRestore: Bool
    let onRestore: (ProjectVersion) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pendingRestore: ProjectVersion?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(project.versions.reversed()) { version in
                        row(version)
                    }
                } footer: {
                    Text("Restoring brings back an older design as a new version. Your later versions stay here.")
                }
            }
            .navigationTitle("Version History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Restore version \(pendingRestore?.number ?? 0)?",
                isPresented: Binding(get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } }),
                titleVisibility: .visible,
                presenting: pendingRestore
            ) { version in
                Button("Restore Version \(version.number)") {
                    onRestore(version)
                    dismiss()
                }
            } message: { _ in
                Text("The current design is kept in history.")
            }
        }
    }

    private func row(_ version: ProjectVersion) -> some View {
        let isCurrent = version.id == project.currentVersionID
        return HStack(alignment: .top, spacing: 12) {
            SpecThumbnail(spec: version.spec)
                .frame(width: 60, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.border, lineWidth: 0.5))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Version \(version.number)").font(.headline)
                    if isCurrent { Tag(text: "Current", tint: Theme.accent) }
                }
                Text(version.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                Text(version.date, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                if !isCurrent {
                    Button("Restore") { pendingRestore = version }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(!canRestore)
                        .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
