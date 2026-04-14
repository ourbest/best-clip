import Foundation

enum OutputAspectRatio: String, Codable, Equatable {
    case portrait9x16
}

struct CompositionSection: Codable, Equatable {
    let assetID: String
    let startSeconds: Double
    let endSeconds: Double
}

struct CompositionPlan: Codable, Equatable {
    let aspectRatio: OutputAspectRatio
    let title: String
    let subtitle: String
    let sections: [CompositionSection]
    let musicStyle: String
    let transitionStyle: String
}
