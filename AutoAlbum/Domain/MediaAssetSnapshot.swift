import Foundation

enum MediaAssetKind: String, Codable, Equatable {
    case photo
    case video
}

struct MediaAssetSnapshot: Identifiable, Codable, Equatable {
    let id: String
    let kind: MediaAssetKind
    let timestamp: Date
    let duration: Double?
    let faces: Int
    let scene: String
    let sharpness: Double
    let stability: Double
    let ocrText: String?
    let speechText: String?
    let sourceURL: URL? = nil
    let previewURL: URL? = nil
}
