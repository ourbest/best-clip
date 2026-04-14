import Foundation

struct ProjectHistoryItem: Codable, Equatable {
    let id: String
    let title: String
    let updatedAt: Date
}

struct ProjectHistoryStore {
    let fileURL: URL

    func save(_ items: [ProjectHistoryItem]) {
        let directoryURL = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)

        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func load() -> [ProjectHistoryItem] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([ProjectHistoryItem].self, from: data)) ?? []
    }
}
