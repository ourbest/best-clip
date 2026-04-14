import Foundation

enum RecommendedStyle: String, Codable, Equatable {
    case lifeLog = "生活记录感"
    case shortVideo = "短视频爆款感"
    case cinematic = "电影感纪念册"
}

struct RecommendationHighlightItem: Codable, Equatable {
    let id: String
    let priority: Int
    let reason: String
}

struct LLMRecommendation: Codable, Equatable {
    let theme: String
    let recommendedStyle: RecommendedStyle
    let title: String
    let subtitle: String
    let highlightItems: [RecommendationHighlightItem]
    let musicStyle: String
    let transitionStyle: String
    let sharingCopy: String
}
