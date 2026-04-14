import Foundation

struct CompositionPlanner {
    func buildPlan(recommendation: LLMRecommendation, assets: [MediaAssetSnapshot]) -> CompositionPlan {
        let orderedAssets = orderedAssets(for: recommendation, assets: assets)
        let sections = orderedAssets.enumerated().flatMap { index, asset in
            sections(for: asset, isFirst: index == 0, isLast: index == orderedAssets.count - 1)
        }

        return CompositionPlan(
            aspectRatio: .portrait9x16,
            title: recommendation.title,
            subtitle: recommendation.subtitle,
            sections: sections,
            musicStyle: recommendation.musicStyle,
            transitionStyle: recommendation.transitionStyle
        )
    }

    private func orderedAssets(for recommendation: LLMRecommendation, assets: [MediaAssetSnapshot]) -> [MediaAssetSnapshot] {
        let byHighlight = recommendation.highlightItems.compactMap { highlight in
            assets.first(where: { $0.id == highlight.id })
        }

        if byHighlight.count == recommendation.highlightItems.count, !byHighlight.isEmpty {
            return byHighlight
        }

        return assets.sorted { $0.timestamp < $1.timestamp }
    }

    private func sections(for asset: MediaAssetSnapshot, isFirst: Bool, isLast: Bool) -> [CompositionSection] {
        switch asset.kind {
        case .photo:
            return [CompositionSection(
                assetID: asset.id,
                startSeconds: 0,
                endSeconds: photoDuration(for: asset, isFirst: isFirst, isLast: isLast)
            )]
        case .video:
            return videoSections(for: asset, isLast: isLast)
        }
    }

    private func photoDuration(for asset: MediaAssetSnapshot, isFirst: Bool, isLast: Bool) -> Double {
        let baseDuration = isFirst ? 2.8 : 2.4
        let duration = min(max(asset.duration ?? baseDuration, 1.8), 4.0)

        if isLast {
            return min(duration + 0.4, 4.0)
        }

        return duration
    }

    private func videoSections(for asset: MediaAssetSnapshot, isLast: Bool) -> [CompositionSection] {
        let sourceDuration = max(asset.duration ?? 0, 0)
        guard sourceDuration > 0 else { return [] }

        let count = videoSegmentCount(for: asset, sourceDuration: sourceDuration)
        let segmentDuration = videoSegmentDuration(for: asset, sourceDuration: sourceDuration, segmentCount: count)
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

    private func videoSegmentCount(for asset: MediaAssetSnapshot, sourceDuration: Double) -> Int {
        let motion = videoMotion(for: asset)
        let contentWeight = videoContentWeight(for: asset)
        let hasStrongContent = contentWeight >= 0.5

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

    private func videoSegmentDuration(for asset: MediaAssetSnapshot, sourceDuration: Double, segmentCount: Int) -> Double {
        let motion = videoMotion(for: asset)
        let stability = min(max(asset.stability, 0.0), 1.0)
        let contentWeight = videoContentWeight(for: asset)
        let motionPenalty = motion * (contentWeight >= 0.5 ? 0.55 : 0.95)
        let base = sourceDuration / Double(segmentCount)
        let adjusted = base + max(0.0, (stability - 0.5) * 1.1) + contentWeight - motionPenalty
        let upperBound = segmentCount == 1 ? sourceDuration : min(4.5, sourceDuration)

        return min(max(adjusted, contentWeight >= 0.5 ? 2.2 : 1.8), upperBound)
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

    private func videoMotion(for asset: MediaAssetSnapshot) -> Double {
        min(max(asset.motion ?? max(0.0, 1.0 - asset.stability), 0.0), 1.0)
    }

    private func videoContentWeight(for asset: MediaAssetSnapshot) -> Double {
        let faceWeight = min(Double(asset.faces), 3.0) * 0.12
        let textWeight = (asset.ocrText?.isEmpty == false ? 0.18 : 0.0) + (asset.speechText?.isEmpty == false ? 0.24 : 0.0)
        return faceWeight + textWeight
    }
}
