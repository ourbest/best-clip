import Foundation

struct AssetQualityScorer {
    func score(for asset: MediaAssetSnapshot) -> Double {
        var value = asset.sharpness * 0.4 + asset.stability * 0.4 + Double(asset.faces) * 0.1

        if asset.kind == .photo {
            value += 0.05
        } else {
            let motion = min(max(asset.motion ?? max(0.0, 1.0 - asset.stability), 0.0), 1.0)
            value += (1.0 - motion) * 0.12
        }

        if asset.ocrText != nil {
            value += 0.03
        }

        if asset.speechText != nil {
            value += 0.02
        }

        return value
    }
}
