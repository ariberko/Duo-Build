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
    /// The model's safety checks declined the request.
    case declined

    var errorDescription: String? {
        switch self {
        case .notUnderstood(let suggestions):
            "Demo mode didn't recognize that change, so nothing was changed. Try something like: "
                + suggestions.prefix(3).map { "“\($0)”" }.joined(separator: ", ") + "."
        case .notConfigured:
            "No AI is set up. Add your Claude API key in Settings, or use Demo mode."
        case .network(let reason):
            "Couldn't reach the AI service: \(reason)"
        case .server(let status, let message):
            "The AI service returned an error (\(status))" + (message.map { ": \($0)" } ?? ".")
        case .badResponse:
            "The AI sent something DuoBuild couldn't read. Nothing was changed. Try again."
        case .invalidDesign(let reason):
            "The AI made a design DuoBuild can't safely show: \(reason) Nothing was changed."
        case .declined:
            "Claude declined this request, so nothing was changed. Try describing it differently."
        }
    }
}
