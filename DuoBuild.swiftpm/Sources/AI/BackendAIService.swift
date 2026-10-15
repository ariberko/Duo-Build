import Foundation

/// Talks to your own backend, which holds the AI provider's key.
/// DuoBuild never stores or sends an API key. See docs/BACKEND.md for the contract.
struct BackendAIService: AIService {
    let endpoint: URL
    var session: URLSession = .shared

    var isDemo: Bool { false }

    struct Request: Encodable {
        struct Message: Encodable {
            let role: String
            let text: String
        }

        var schemaVersion = 1
        let action: String
        let projectName: String?
        let prompt: String
        let spec: UISpec?
        let history: [Message]
    }

    struct Response: Decodable {
        let spec: UISpec
        let summary: String?
    }

    struct ErrorBody: Decodable {
        let error: String?
    }

    func generate(name: String, prompt: String, progress: @escaping @Sendable (String) async -> Void) async throws -> GenerationResult {
        await progress("Sending your description to the AI…")
        let request = Request(action: "generate", projectName: name, prompt: prompt, spec: nil, history: [])
        return try await send(request, progress: progress)
    }

    func refine(spec: UISpec, instruction: String, history: [ChatMessage], progress: @escaping @Sendable (String) async -> Void) async throws -> GenerationResult {
        await progress("Sending your change to the AI…")
        let recent = history.filter { $0.role == .user || $0.role == .assistant }.suffix(12)
        let request = Request(
            action: "refine", projectName: nil, prompt: instruction, spec: spec,
            history: recent.map { .init(role: $0.role.rawValue, text: $0.text) }
        )
        return try await send(request, progress: progress)
    }

    private func send(_ body: Request, progress: @escaping @Sendable (String) async -> Void) async throws -> GenerationResult {
        var request = URLRequest(url: endpoint, timeoutInterval: 90)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(body)

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
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error
            throw AIError.server(status: http.statusCode, message: message)
        }

        await progress("Checking the design…")
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data) else { throw AIError.badResponse }
        do {
            let spec = try SpecValidator.validate(decoded.spec)
            return GenerationResult(spec: spec, summary: decoded.summary ?? "Updated the design.")
        } catch {
            throw AIError.invalidDesign(error.localizedDescription)
        }
    }
}
