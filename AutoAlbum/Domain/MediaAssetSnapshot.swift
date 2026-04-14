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
    let motion: Double?
    let ocrText: String?
    let speechText: String?
    let sourceURL: URL?
    let previewURL: URL?

    init(
        id: String,
        kind: MediaAssetKind,
        timestamp: Date,
        duration: Double?,
        faces: Int,
        scene: String,
        sharpness: Double,
        stability: Double,
        motion: Double? = nil,
        ocrText: String?,
        speechText: String?,
        sourceURL: URL? = nil,
        previewURL: URL? = nil
    ) {
        self.id = id
        self.kind = kind
        self.timestamp = timestamp
        self.duration = duration
        self.faces = faces
        self.scene = scene
        self.sharpness = sharpness
        self.stability = stability
        self.motion = motion
        self.ocrText = ocrText
        self.speechText = speechText
        self.sourceURL = sourceURL
        self.previewURL = previewURL
    }
}
