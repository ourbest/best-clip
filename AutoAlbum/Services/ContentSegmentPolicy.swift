import Foundation

struct ContentSegmentPolicy {
    func contentScore(for asset: MediaAssetSnapshot) -> Double {
        let faceWeight = min(Double(asset.faces), 3.0) * 0.12
        let textWeight = (asset.ocrText?.isEmpty == false ? 0.18 : 0.0) + (asset.speechText?.isEmpty == false ? 0.24 : 0.0)
        return faceWeight + textWeight
    }

    func minimumSegmentDuration(for asset: MediaAssetSnapshot) -> Double {
        contentScore(for: asset) >= 0.5 ? 2.2 : 1.8
    }

    func motionPenaltyMultiplier(for asset: MediaAssetSnapshot) -> Double {
        contentScore(for: asset) >= 0.5 ? 0.55 : 0.95
    }
}
