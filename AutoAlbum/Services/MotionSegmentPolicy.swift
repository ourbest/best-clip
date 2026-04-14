import Foundation

struct MotionSegmentPolicy {
    func segmentCount(for asset: MediaAssetSnapshot, sourceDuration: Double, contentScore: Double) -> Int {
        let motion = motionScore(for: asset)
        let hasStrongContent = contentScore >= 0.5

        if sourceDuration < 6 {
            return 1
        }

        if hasStrongContent, sourceDuration <= 12 {
            return 1
        }

        if hasStrongContent {
            return 2
        }

        if sourceDuration >= 16, motion >= 0.55 {
            return 3
        }

        if sourceDuration >= 10, motion >= 0.35 {
            return 2
        }

        return motion > 0.65 ? 2 : 1
    }

    func motionScore(for asset: MediaAssetSnapshot) -> Double {
        min(max(asset.motion ?? max(0.0, 1.0 - asset.stability), 0.0), 1.0)
    }
}
