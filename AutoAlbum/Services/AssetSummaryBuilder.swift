import Foundation

struct AssetSummaryBuilder {
    private let scorer: AssetQualityScorer
    private let selectionFilter: AssetSelectionFilter

    init(
        scorer: AssetQualityScorer = AssetQualityScorer(),
        selectionFilter: AssetSelectionFilter = AssetSelectionFilter()
    ) {
        self.scorer = scorer
        self.selectionFilter = selectionFilter
    }

    func build(from assets: [MediaAssetSnapshot]) -> AssetSummary {
        let eligibleAssets = selectionFilter.filter(assets)
        let orderedAssets = eligibleAssets
            .map { asset in
                (asset: asset, score: score(for: asset))
            }
            .sorted {
                if $0.score == $1.score {
                    if $0.asset.timestamp == $1.asset.timestamp {
                        return $0.asset.id < $1.asset.id
                    }
                    return $0.asset.timestamp < $1.asset.timestamp
                }
                return $0.score > $1.score
            }

        let highlightItems = orderedAssets.enumerated().map { index, scored in
            AssetSummaryItem(
                id: scored.asset.id,
                priority: index + 1,
                reason: reason(for: scored.asset)
            )
        }

        return AssetSummary(
            recommendedTheme: recommendedTheme(for: eligibleAssets),
            highlightItems: highlightItems
        )
    }

    private func score(for asset: MediaAssetSnapshot) -> Double {
        scorer.score(for: asset)
    }

    private func reason(for asset: MediaAssetSnapshot) -> String {
        if asset.kind == .photo {
            return "清晰稳定，适合作为开头"
        }

        if let motion = asset.motion, motion <= 0.25 {
            return "画面稳定，适合作为承接镜头"
        }

        return "有动作感，适合作为过渡"
    }

    private func recommendedTheme(for assets: [MediaAssetSnapshot]) -> String {
        guard !assets.isEmpty else { return "周末日常" }

        let photoCount = assets.filter { $0.kind == .photo }.count
        let videoCount = assets.count - photoCount

        if photoCount >= videoCount {
            return "周末日常"
        }

        return "朋友聚会"
    }
}
