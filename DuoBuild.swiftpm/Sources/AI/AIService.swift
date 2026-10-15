import Foundation

struct GenerationResult: Equatable {
    var spec: UISpec
    /// A short, honest note shown in the conversation.
    var summary: String
}

/// Anything that can turn words into a `UISpec`. Swap in a new one without touching the UI.
protocol AIService: Sendable {
    /// True when results are simulated and no real AI is called.
    var isDemo: Bool { get }

    func generate(name: String, prompt: String, progress: @escaping @Sendable (String) async -> Void) async throws -> GenerationResult

    func refine(spec: UISpec, instruction: String, history: [ChatMessage], progress: @escaping @Sendable (String) async -> Void) async throws -> GenerationResult
}

enum AIError: LocalizedError, Equatable {
    /// Demo mode could not match the request to anything it knows.
    case notUnderstood(suggestions: [String])
    case notConfigured
    case network(String)
    case server(status: Int, message: String?)
    case badResponse
    case invalidDesign(String)

    var errorDescription: String? {
        switch self {
        case .notUnderstood(let suggestions):
            "Demo mode didn't recognize that change, so nothing was changed. Try something like: "
                + suggestions.prefix(3).map { "“\($0)”" }.joined(separator: ", ") + "."
        case .notConfigured:
            "No AI backend is set up. Add one in Settings, or use Demo mode."
        case .network(let reason):
            "Couldn't reach the AI backend: \(reason)"
        case .server(let status, let message):
            "The AI backend returned an error (\(status))" + (message.map { ": \($0)" } ?? ".")
        case .badResponse:
            "The AI backend sent something DuoBuild couldn't read. Nothing was changed."
        case .invalidDesign(let reason):
            "The AI made a design DuoBuild can't safely show: \(reason) Nothing was changed."
        }
    }
}
