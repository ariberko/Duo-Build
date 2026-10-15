import Foundation
import Observation

/// Which AI service DuoBuild uses. Kept apart from the UI and saved on this device only.
@Observable
final class AISettings {
    enum Mode: String, CaseIterable, Identifiable {
        case demo, backend
        var id: String { rawValue }
        var title: String { self == .demo ? "Demo" : "Your Backend" }
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

    private var storedMode: Mode
    private var storedAddress: String

    private let defaults: UserDefaults

    private enum Keys {
        static let mode = "ai.mode"
        static let address = "ai.backendAddress"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        storedMode = Mode(rawValue: defaults.string(forKey: Keys.mode) ?? "") ?? .demo
        // A build can ship a default address in Info.plist (DuoBuildBackendURL). Never a key.
        storedAddress = defaults.string(forKey: Keys.address)
            ?? (Bundle.main.object(forInfoDictionaryKey: "DuoBuildBackendURL") as? String) ?? ""
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
    var isDemo: Bool { mode == .demo || backendURL == nil }

    var statusText: String {
        switch mode {
        case .demo: "Demo mode · simulated AI"
        case .backend: backendURL == nil ? "Demo mode · backend address missing" : "Connected to your backend"
        }
    }

    func makeService() -> AIService {
        if mode == .backend, let url = backendURL {
            return BackendAIService(endpoint: url)
        }
        return DemoAIService()
    }
}
