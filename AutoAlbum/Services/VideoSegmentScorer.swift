import Foundation

struct VideoSegmentScorer {
    private let motionPolicy: MotionSegmentPolicy
    private let contentPolicy: ContentSegmentPolicy

    init(
        motionPolicy: MotionSegmentPolicy = MotionSegmentPolicy(),
        contentPolicy: ContentSegmentPolicy = ContentSegmentPolicy()
    ) {
        self.motionPolicy = motionPolicy
        self.contentPolicy = contentPolicy
    }

    func sections(for asset: MediaAssetSnapshot, isLast: Bool) -> [CompositionSection] {
        let sourceDuration = max(asset.duration ?? 0, 0)
        guard sourceDuration > 0 else { return [] }

        let contentScore = contentPolicy.contentScore(for: asset)
        let count = motionPolicy.segmentCount(for: asset, sourceDuration: sourceDuration, contentScore: contentScore)
        let segmentDuration = preferredSegmentDuration(
            for: asset,
            sourceDuration: sourceDuration,
            segmentCount: count,
            contentScore: contentScore
        )
        let windows = segmentWindows(sourceDuration: sourceDuration, segmentDuration: segmentDuration, segmentCount: count)

        return windows.enumerated().map { index, window in
            let adjustedEnd = isLast && index == windows.count - 1
                ? min(window.end + 0.4, sourceDuration)
                : window.end

            return CompositionSection(
                assetID: asset.id,
                startSeconds: window.start,
                endSeconds: max(window.start, adjustedEnd)
            )
        }
    }

    private func preferredSegmentDuration(
        for asset: MediaAssetSnapshot,
        sourceDuration: Double,
        segmentCount: Int,
        contentScore: Double
    ) -> Double {
        let motion = motionPolicy.motionScore(for: asset)
        let stability = min(max(asset.stability, 0.0), 1.0)
        let motionPenalty = motion * contentPolicy.motionPenaltyMultiplier(for: asset)
        let base = sourceDuration / Double(segmentCount)
        let adjusted = base + max(0.0, (stability - 0.5) * 1.1) + contentScore - motionPenalty
        let upperBound = segmentCount == 1 ? sourceDuration : min(4.5, sourceDuration)

        return min(max(adjusted, contentPolicy.minimumSegmentDuration(for: asset)), upperBound)
    }

    private func segmentWindows(sourceDuration: Double, segmentDuration: Double, segmentCount: Int) -> [(start: Double, end: Double)] {
        guard segmentCount > 1 else {
            return [(0, min(segmentDuration, sourceDuration))]
        }

        let availableSpan = max(sourceDuration - segmentDuration, 0)
        return (0..<segmentCount).map { index in
            let fraction = Double(index) / Double(segmentCount - 1)
            let start = availableSpan * fraction
            let end = min(start + segmentDuration, sourceDuration)
            return (start, end)
        }
    }

}
