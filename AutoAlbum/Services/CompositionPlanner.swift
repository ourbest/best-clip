import Foundation

struct CompositionPlanner {
    private let videoSegmentScorer: VideoSegmentScorer

    init(videoSegmentScorer: VideoSegmentScorer = VideoSegmentScorer()) {
        self.videoSegmentScorer = videoSegmentScorer
    }

    func buildPlan(recommendation: LLMRecommendation, assets: [MediaAssetSnapshot]) -> CompositionPlan {
        let orderedAssets = orderedAssets(for: recommendation, assets: assets)
        var sections: [CompositionSection] = []
        for (index, asset) in orderedAssets.enumerated() {
            let isFirst = index == 0
            let isLast = index == orderedAssets.count - 1
            sections.append(contentsOf: self.sections(for: asset, isFirst: isFirst, isLast: isLast))
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
            return videoSegmentScorer.sections(for: asset, isLast: isLast)
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

}
