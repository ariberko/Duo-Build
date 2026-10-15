import Foundation
import Observation

/// Runs follow-up requests for one open project and tracks their state.
@MainActor
@Observable
final class WorkspaceModel {
    enum Phase: Equatable {
        case idle
        case working(String)
        case failed
    }

    var draft = ""
    var phase: Phase = .idle
    /// Set after a successful change, so a one-pane layout can offer a jump to the preview.
    var hasUnseenUpdate = false
    private(set) var failedInstruction: String?
    @ObservationIgnored private var task: Task<Void, Never>?

    var isWorking: Bool {
        if case .working = phase { return true }
        return false
    }

    var stageText: String? {
        if case .working(let text) = phase { return text }
        return nil
    }

    /// Sends the draft (or `text`) as a change request.
    func send(_ text: String? = nil, isRetry: Bool = false, projectID: UUID, store: ProjectStore, service: AIService) {
        let instruction = (text ?? draft).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !instruction.isEmpty, !isWorking, let project = store.project(id: projectID) else { return }
        if text == nil { draft = "" }
        failedInstruction = nil
        hasUnseenUpdate = false

        if !isRetry {
            store.update(projectID) { $0.messages.append(ChatMessage(role: .user, text: instruction)) }
        }
        phase = .working("Starting…")
        let spec = project.spec
        let history = project.messages

        task = Task {
            do {
                let result = try await service.refine(spec: spec, instruction: instruction, history: history) { [weak self] stage in
                    await self?.setStage(stage)
                }
                try Task.checkCancellation()
                store.update(projectID) { project in
                    let version = project.commit(result.spec, summary: result.summary)
                    project.messages.append(ChatMessage(role: .assistant, text: result.summary, versionID: version.id))
                }
                phase = .idle
                hasUnseenUpdate = true
                Haptics.success()
            } catch is CancellationError {
                store.update(projectID) { $0.messages.append(ChatMessage(role: .note, text: "Stopped. Nothing was changed.")) }
                phase = .idle
            } catch {
                store.update(projectID) { $0.messages.append(ChatMessage(role: .error, text: error.localizedDescription)) }
                failedInstruction = instruction
                phase = .failed
                Haptics.failure()
            }
        }
    }

    func retry(projectID: UUID, store: ProjectStore, service: AIService) {
        guard let instruction = failedInstruction else { return }
        send(instruction, isRetry: true, projectID: projectID, store: store, service: service)
    }

    func cancel() {
        task?.cancel()
    }

    private func setStage(_ text: String) {
        if isWorking { phase = .working(text) }
    }
}
