import Foundation

struct CompositionPlanner {
    func buildPlan(recommendation: LLMRecommendation, assets: [MediaAssetSnapshot]) -> CompositionPlan {
        let orderedAssets = orderedAssets(for: recommendation, assets: assets)
        let sections = orderedAssets.enumerated().map { index, asset in
            CompositionSection(
                assetID: asset.id,
                startSeconds: 0,
                endSeconds: plannedDuration(for: asset, index: index, totalCount: orderedAssets.count)
            )
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

    private func plannedDuration(for asset: MediaAssetSnapshot, index: Int, totalCount: Int) -> Double {
        let baseDuration: Double

        switch asset.kind {
        case .photo:
            baseDuration = index == 0 ? 2.8 : 2.4
        case .video:
            let duration = min(asset.duration ?? 4.0, 5.0)
            let motion = min(max(asset.motion ?? max(0.0, 1.0 - asset.stability), 0.0), 1.0)
            let stabilityBonus = max(0.0, (asset.stability - 0.5) * 1.2)
            let contentBonus = asset.speechText != nil ? 0.3 : (asset.ocrText != nil ? 0.15 : 0.0)
            let motionPenalty = motion * 0.9
            baseDuration = max(1.8, min(duration + stabilityBonus + contentBonus - motionPenalty, 5.0))
        }

        if index == totalCount - 1 {
            return max(2.2, min(baseDuration + 0.4, 4.0))
        }

        return max(1.8, baseDuration)
    }
}
