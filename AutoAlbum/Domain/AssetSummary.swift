import Foundation

struct AssetSummaryItem: Codable, Equatable {
    let id: String
    let priority: Int
    let reason: String
}

struct AssetSummary: Codable, Equatable {
    let recommendedTheme: String
    let highlightItems: [AssetSummaryItem]
}
