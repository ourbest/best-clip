import Foundation

private struct SettingsPayload: Codable {
    let provider: SettingsStore.Provider
    let modelName: String
    let apiKey: String
}

struct SettingsStore {
    enum Provider: String, Codable {
        case openAI
    }

    let fileURL: URL
    var provider: Provider = .openAI
    var modelName: String = "gpt-4o-mini"
    var apiKey: String = ""

    init(fileURL: URL) {
        self.fileURL = fileURL

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(SettingsPayload.self, from: data) {
            self.provider = decoded.provider
            self.modelName = decoded.modelName
            self.apiKey = decoded.apiKey
        }
    }

    func save() {
        let directoryURL = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)

        let payload = SettingsPayload(provider: provider, modelName: modelName, apiKey: apiKey)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
