import Foundation

private struct SettingsPayload: Codable {
    let provider: SettingsStore.Provider
    let modelName: String
}

struct SettingsStore {
    enum Provider: String, Codable {
        case openAI
    }

    let fileURL: URL
    private let secretStore: SecretStoring
    var provider: Provider = .openAI
    var modelName: String = "gpt-4o-mini"
    var apiKey: String = ""

    init(fileURL: URL, secretStore: SecretStoring = KeychainSecretStore()) {
        self.fileURL = fileURL
        self.secretStore = secretStore

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(SettingsPayload.self, from: data) {
            self.provider = decoded.provider
            self.modelName = decoded.modelName
            self.apiKey = secretStore.string(for: secretKey) ?? ""
        } else {
            self.apiKey = secretStore.string(for: secretKey) ?? ""
        }
    }

    func save() {
        let directoryURL = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)

        let payload = SettingsPayload(provider: provider, modelName: modelName)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: fileURL, options: .atomic)
        secretStore.setString(apiKey, for: secretKey)
    }

    private var secretKey: String {
        "autoalbum.settings.apiKey.\(fileURL.path)"
    }
}
