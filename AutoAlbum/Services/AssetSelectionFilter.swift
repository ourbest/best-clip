import Foundation

struct AssetSelectionFilter {
    private let scorer: AssetQualityScorer
    private let minimumScore: Double

    init(scorer: AssetQualityScorer = AssetQualityScorer(), minimumScore: Double = 0.5) {
        self.scorer = scorer
        self.minimumScore = minimumScore
    }

    func filter(_ assets: [MediaAssetSnapshot]) -> [MediaAssetSnapshot] {
        let eligibleAssets = assets.filter { scorer.score(for: $0) >= minimumScore }
        return eligibleAssets.isEmpty ? assets : eligibleAssets
    }
}
