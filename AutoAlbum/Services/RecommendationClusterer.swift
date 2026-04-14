import Foundation

struct RecommendationCluster: Identifiable, Equatable, Codable {
    let id: String
    let title: String
    let itemIDs: [String]
    let reason: String

    var itemCount: Int {
        itemIDs.count
    }
}

struct RecommendationClusterer {
    func cluster(highlights: [RecommendationHighlightItem], summary: AssetSummary) -> [RecommendationCluster] {
        let orderedHighlights = highlights.sorted { lhs, rhs in
            if lhs.priority == rhs.priority {
                return lhs.id < rhs.id
            }
            return lhs.priority < rhs.priority
        }

        let grouped = Dictionary(grouping: orderedHighlights, by: { clusterKey(for: $0.reason) })
        let priorityOrder = ["开头", "承接", "收尾", "动作", "内容"]

        let clusters = priorityOrder.compactMap { key -> RecommendationCluster? in
            guard let items = grouped[key], !items.isEmpty else { return nil }
            return RecommendationCluster(
                id: key,
                title: key,
                itemIDs: items.map(\.id),
                reason: clusterReason(for: key, summary: summary)
            )
        }

        if !clusters.isEmpty {
            return clusters.sorted { lhs, rhs in
                rank(for: lhs.id, in: priorityOrder) < rank(for: rhs.id, in: priorityOrder)
            }
        }

        let fallbackIDs = orderedHighlights.prefix(3).map(\.id)
        guard !fallbackIDs.isEmpty else {
            return [
                RecommendationCluster(
                    id: summary.recommendedTheme,
                    title: summary.recommendedTheme,
                    itemIDs: [],
                    reason: "没有可分组的高光线索"
                )
            ]
        }

        return [
            RecommendationCluster(
                id: summary.recommendedTheme,
                title: summary.recommendedTheme,
                itemIDs: fallbackIDs,
                reason: "按主题兜底分组"
            )
        ]
    }

    private func clusterKey(for reason: String) -> String {
        let text = reason.lowercased()
        if containsAny(text, keywords: ["开头", "开始", "起始", "引子", "序"]) {
            return "开头"
        }
        if containsAny(text, keywords: ["承接", "过渡", "连接", "衔接", "中间"]) {
            return "承接"
        }
        if containsAny(text, keywords: ["收尾", "结尾", "结束", "落点"]) {
            return "收尾"
        }
        if containsAny(text, keywords: ["动作", "运动", "快节奏", "动态"]) {
            return "动作"
        }
        if containsAny(text, keywords: ["人物", "语音", "文字", "对话", "内容"]) {
            return "内容"
        }
        return "其他"
    }

    private func clusterReason(for key: String, summary: AssetSummary) -> String {
        switch key {
        case "开头":
            return "适合放在视频开头"
        case "承接":
            return "适合放在中段过渡"
        case "收尾":
            return "适合放在结尾"
        case "动作":
            return "适合做快节奏镜头"
        case "内容":
            return "包含人物、语音或文字"
        default:
            return summary.recommendedTheme
        }
    }

    private func containsAny(_ text: String, keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }

    private func rank(for key: String, in order: [String]) -> Int {
        order.firstIndex(of: key) ?? Int.max
    }
}
