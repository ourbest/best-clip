import Foundation

private struct SettingsPayload: Codable {
    let provider: SettingsStore.Provider
    let baseURL: String?
    let modelName: String
}

struct SettingsStore {
    enum Provider: String, Codable {
        case openAI
        case anthropic

        var defaultBaseURL: String {
            switch self {
            case .openAI:
                return "https://api.openai.com"
            case .anthropic:
                return "https://api.anthropic.com"
            }
        }
    }

    let fileURL: URL
    private let secretStore: SecretStoring
    var provider: Provider = .openAI
    var baseURL: String = Provider.openAI.defaultBaseURL
    var modelName: String = "gpt-4o-mini"
    var apiKey: String = ""

    init(fileURL: URL, secretStore: SecretStoring = KeychainSecretStore()) {
        self.fileURL = fileURL
        self.secretStore = secretStore

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(SettingsPayload.self, from: data) {
            self.provider = decoded.provider
            self.baseURL = decoded.baseURL?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? decoded.provider.defaultBaseURL
            self.modelName = decoded.modelName
            self.apiKey = secretStore.string(for: secretKey) ?? ""
        } else {
            self.apiKey = secretStore.string(for: secretKey) ?? ""
        }
    }

    func save() {
        let directoryURL = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)

        var sanitized = self
        sanitized.applyProviderDefaults()

        let payload = SettingsPayload(provider: sanitized.provider, baseURL: sanitized.baseURL, modelName: sanitized.modelName)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: fileURL, options: .atomic)
        secretStore.setString(apiKey, for: secretKey)
    }

    mutating func applyProviderDefaults() {
        baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if baseURL.isEmpty {
            baseURL = provider.defaultBaseURL
        }
    }

    private var secretKey: String {
        "autoalbum.settings.apiKey.\(fileURL.path)"
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
