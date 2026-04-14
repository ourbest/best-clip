import Foundation

struct AssetSelectionFilter {
    private let scorer: AssetQualityScorer
    private let minimumScore: Double

    init(scorer: AssetQualityScorer = AssetQualityScorer(), minimumScore: Double = 0.5) {
        self.scorer = scorer
        self.minimumScore = minimumScore
    }

    func filter(_ assets: [MediaAssetSnapshot]) -> [MediaAssetSnapshot] {
        let rankedAssets = assets
            .map { asset in (asset: asset, score: scorer.score(for: asset)) }
            .sorted {
                if $0.score == $1.score {
                    if $0.asset.timestamp == $1.asset.timestamp {
                        return $0.asset.id < $1.asset.id
                    }
                    return $0.asset.timestamp < $1.asset.timestamp
                }
                return $0.score > $1.score
            }

        let eligibleAssets = rankedAssets
            .filter { $0.score >= minimumScore }
            .map(\.asset)

        if !eligibleAssets.isEmpty {
            return eligibleAssets
        }

        return Array(rankedAssets.prefix(1).map(\.asset))
    }
}
