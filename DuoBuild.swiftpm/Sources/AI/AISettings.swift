import Foundation
import Observation

/// Which AI service DuoBuild uses. Kept apart from the UI and saved on this device only.
@Observable
final class AISettings {
    enum Mode: String, CaseIterable, Identifiable {
        /// Built-in templates, no AI.
        case demo
        /// Claude, with the person's own API key.
        case claude
        /// A server the developer runs, which holds the key.
        case backend

        var id: String { rawValue }

        var title: String {
            switch self {
            case .demo: "Demo"
            case .claude: "Claude"
            case .backend: "Backend"
            }
        }
    }

    var mode: Mode {
        get { storedMode }
        set {
            storedMode = newValue
            defaults.set(newValue.rawValue, forKey: Keys.mode)
        }
    }

    var backendAddress: String {
        get { storedAddress }
        set {
            storedAddress = newValue
            defaults.set(newValue, forKey: Keys.address)
        }
    }

    var claudeModel: ClaudeAIService.Model {
        get { storedModel }
        set {
            storedModel = newValue
            defaults.set(newValue.rawValue, forKey: Keys.model)
        }
    }

    /// The last four characters of the saved key, to show which key is in use. Never the whole key.
    private(set) var claudeKeyHint: String?

    private var storedMode: Mode
    private var storedAddress: String
    private var storedModel: ClaudeAIService.Model

    private let defaults: UserDefaults

    private enum Keys {
        static let mode = "ai.mode"
        static let address = "ai.backendAddress"
        static let model = "ai.claudeModel"
        static let claudeKey = "claude-api-key"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        storedMode = Mode(rawValue: defaults.string(forKey: Keys.mode) ?? "") ?? .demo
        // A build can ship a default address in Info.plist (DuoBuildBackendURL). Never a key.
        storedAddress = defaults.string(forKey: Keys.address)
            ?? (Bundle.main.object(forInfoDictionaryKey: "DuoBuildBackendURL") as? String) ?? ""
        storedModel = ClaudeAIService.Model(rawValue: defaults.string(forKey: Keys.model) ?? "") ?? .opus
        claudeKeyHint = Keychain.read(account: Keys.claudeKey).map(Self.hint)
    }

    // MARK: Claude key

    var hasClaudeKey: Bool { claudeKeyHint != nil }

    /// The saved key, read from the Keychain only when a request needs it.
    func savedClaudeKey() -> String? {
        Keychain.read(account: Keys.claudeKey)
    }

    /// Saves the key in the Keychain on this device. It's never written to UserDefaults or the project file.
    func saveClaudeKey(_ key: String) throws {
        let clean = key.trimmingCharacters(in: .whitespacesAndNewlines)
        try Keychain.save(clean, account: Keys.claudeKey)
        claudeKeyHint = Self.hint(clean)
    }

    func removeClaudeKey() {
        Keychain.delete(account: Keys.claudeKey)
        claudeKeyHint = nil
    }

    private static func hint(_ key: String) -> String {
        "••••" + key.suffix(4)
    }

    /// A usable backend address, or nil. Needs https, except for a local test server.
    var backendURL: URL? {
        Self.validURL(backendAddress)
    }

    static func validURL(_ text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), let host = url.host, !host.isEmpty else { return nil }
        if scheme == "https" { return url }
        if scheme == "http", host == "localhost" || host == "127.0.0.1" { return url }
        return nil
    }

    /// True when generation will really be simulated.
    var isDemo: Bool {
        switch mode {
        case .demo: true
        case .claude: !hasClaudeKey
        case .backend: backendURL == nil
        }
    }

    var statusText: String {
        switch mode {
        case .demo: "Demo mode · simulated AI"
        case .claude: hasClaudeKey ? "\(claudeModel.title) · your API key" : "Demo mode · add your Claude API key"
        case .backend: backendURL == nil ? "Demo mode · backend address missing" : "Connected to your backend"
        }
    }

    func makeService() -> AIService {
        switch mode {
        case .claude:
            if let key = savedClaudeKey() {
                return ClaudeAIService(apiKey: key, model: claudeModel)
            }
        case .backend:
            if let url = backendURL { return BackendAIService(endpoint: url) }
        case .demo:
            break
        }
        return DemoAIService()
    }
}
