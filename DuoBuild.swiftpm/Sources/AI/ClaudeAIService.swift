import Foundation

/// Calls the Claude API directly with the person's own API key.
/// The key comes from the Keychain and is sent only to api.anthropic.com.
/// Usage is billed to the person's own Anthropic account.
struct ClaudeAIService: AIService {
    enum Model: String, CaseIterable, Identifiable {
        case opus = "claude-opus-5-5"
        case sonnet = "claude-sonnet-5-5"
        case haiku = "claude-haiku-5-5"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .opus: "Claude Opus 5.5"
            case .sonnet: "Claude Sonnet 5.5"
            case .haiku: "Claude Haiku 5.5"
            }
        }

        var note: String {
            switch self {
            case .opus: "Best results"
            case .sonnet: "Fast and capable"
            case .haiku: "Fastest, lowest cost"
            }
        }

        /// Opus and Sonnet can retry a declined request on another model, server side.
        var supportsFallbacks: Bool { self != .haiku }
    }

    let apiKey: String
    var model: Model = .opus
    var session: URLSession = .shared

    var isDemo: Bool { false }

    static let messagesURL = URL(string: "https://api.anthropic.com/v1/messages")!
    static let modelsURL = URL(string: "https://api.anthropic.com/v1/models")!
    static let apiVersion = "2023-06-01"

    func generate(name: String, prompt: String, progress: @escaping @Sendable (String) async -> Void) async throws -> GenerationResult {
        await progress("Asking \(model.title)…")
        let text = SpecPrompt.generateRequest(name: name, prompt: prompt)
        return try await send(text, progress: progress)
    }

    func refine(spec: UISpec, instruction: String, history: [ChatMessage], progress: @escaping @Sendable (String) async -> Void) async throws -> GenerationResult {
        await progress("Asking \(model.title)…")
        let text = SpecPrompt.refineRequest(spec: spec, instruction: instruction, history: history)
        return try await send(text, progress: progress)
    }

    // MARK: Request

    func makeRequest(userText: String) throws -> URLRequest {
        var body: [String: Any] = [
            "model": model.rawValue,
            "max_tokens": 16000,
            "system": SpecPrompt.system,
            // A small design doesn't need deep thinking. Low effort keeps it quick and cheap.
            "output_config": ["effort": "low"],
            "messages": [["role": "user", "content": userText]],
        ]
        var request = URLRequest(url: Self.messagesURL, timeoutInterval: 180)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        if model.supportsFallbacks {
            body["fallbacks"] = "default"
            request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func send(_ userText: String, progress: @escaping @Sendable (String) async -> Void) async throws -> GenerationResult {
        let request = try makeRequest(userText: userText)
        let result: (Data, URLResponse)
        do {
            result = try await session.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw AIError.network(error.localizedDescription)
        }
        let (data, response) = result
        guard let http = response as? HTTPURLResponse else { throw AIError.badResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw Self.apiError(status: http.statusCode, data: data)
        }
        await progress("Checking the design…")
        return try Self.parse(data)
    }

    // MARK: Response

    struct MessageResponse: Decodable {
        struct Block: Decodable {
            let type: String
            let text: String?
        }

        let content: [Block]
        let stop_reason: String?
    }

    struct ErrorResponse: Decodable {
        struct Detail: Decodable {
            let type: String?
            let message: String?
        }

        let error: Detail?
    }

    /// Reads a Messages API response into a checked design.
    static func parse(_ data: Data) throws -> GenerationResult {
        guard let message = try? JSONDecoder().decode(MessageResponse.self, from: data) else { throw AIError.badResponse }
        switch message.stop_reason {
        case "refusal":
            throw AIError.declined
        case "max_tokens":
            throw AIError.invalidDesign("The answer was too long and got cut off.")
        default:
            break
        }
        let text = message.content.filter { $0.type == "text" }.compactMap(\.text).joined()
        return try SpecPrompt.parseAnswer(text)
    }

    static func apiError(status: Int, data: Data) -> AIError {
        let detail = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.error?.message
        switch status {
        case 401: return .server(status: status, message: "Your API key wasn't accepted. Check it in Settings.")
        case 403: return .server(status: status, message: "Your API key can't use this model.")
        case 429: return .server(status: status, message: "Too many requests or no credit left on your Anthropic account. Try again soon.")
        case 529: return .server(status: status, message: "Claude is busy right now. Try again in a moment.")
        default: return .server(status: status, message: detail)
        }
    }

    /// Checks a key with the free model list call. Nothing is generated or billed.
    static func testKey(_ key: String, session: URLSession = .shared) async -> Result<Void, AIError> {
        var request = URLRequest(url: modelsURL, timeoutInterval: 20)
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        do {
            let (data, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            return (200..<300).contains(status) ? .success(()) : .failure(apiError(status: status, data: data))
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }
}

/// The instructions every real AI gets, and the code that reads its answer.
enum SpecPrompt {
    static let system = """
    You design simple mobile app screens for DuoBuild, an iPhone app that previews them live.
    You never write code. You answer with one JSON object and nothing else:
    {"summary": "<one or two plain sentences saying what you built or changed>", "spec": <UI spec>}

    UI spec format:
    {"title": String, "theme": {"accent": Color, "background": "system"|"grouped"|"tinted"|"dark", "spacing": "none"|"small"|"medium"|"large"}, "nodes": [Node]}

    Node types (field "type"):
    - "text": "text", "style" ("largeTitle"|"title"|"headline"|"body"|"caption"), optional "color"
    - "button": "text", "message" (shown when tapped in the preview), optional "style":"caption" for a secondary button, optional "color"
    - "card": "text" (title), optional "detail", "symbol", "color", "children"
    - "image": "symbol" (an SF Symbol name, e.g. "photo", "fork.knife"), "size" ("small"|"medium"|"large"), optional "color"
    - "list": "items" (array of strings), optional "symbol" for each row
    - "input": "text" (placeholder)
    - "stack": "axis" ("vertical"|"horizontal"), optional "spacing", "children"
    - "divider", "spacer": no fields
    Every node has a short unique "id". Color is one of: blue indigo purple pink red orange yellow green mint teal brown gray primary secondary.

    Rules:
    - Use only the types and fields above. Images are SF Symbols only, never URLs.
    - At most 60 nodes and 4 levels of nesting. Horizontal stacks hold 2 or 3 items.
    - Use realistic, specific sample content, not lorem ipsum.
    - When changing a design, keep everything the person didn't ask to change, including ids.
    - If a request can't be shown with these parts, do the closest thing and say so in the summary.
    """

    static func generateRequest(name: String, prompt: String) -> String {
        "Create a new screen for a project named \"\(name)\".\n\nWhat the person wants:\n\(prompt)"
    }

    static func refineRequest(spec: UISpec, instruction: String, history: [ChatMessage]) -> String {
        let specJSON = (try? JSONEncoder().encode(spec)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        let recent = history
            .filter { $0.role == .user || $0.role == .assistant }
            .suffix(10)
            .map { "\($0.role == .user ? "Person" : "You"): \($0.text)" }
            .joined(separator: "\n")
        return """
        Current design:
        \(specJSON)

        Conversation so far:
        \(recent.isEmpty ? "(none)" : recent)

        Change requested now:
        \(instruction)
        """
    }

    struct Answer: Decodable {
        let summary: String?
        let spec: UISpec
    }

    /// Finds the JSON object in the model's text, decodes it and checks it.
    static func parseAnswer(_ text: String) throws -> GenerationResult {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end,
              let answer = try? JSONDecoder().decode(Answer.self, from: Data(text[start...end].utf8)) else {
            throw AIError.badResponse
        }
        do {
            let spec = try SpecValidator.validate(answer.spec)
            return GenerationResult(spec: spec, summary: answer.summary ?? "Updated the design.")
        } catch {
            throw AIError.invalidDesign(error.localizedDescription)
        }
    }
}
