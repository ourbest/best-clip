import Foundation

struct RecommendationPrompt {
    static func make(from summary: AssetSummary) -> String {
        let highlights = summary.highlightItems
            .prefix(6)
            .map { item in
                "- \(item.id): \(item.reason)"
            }
            .joined(separator: "\n")

        return """
        你是一个相册视频剪辑助手。请根据素材摘要返回严格 JSON，禁止解释性文字、禁止 Markdown 代码块。

        输出字段：
        - theme
        - recommended_style
        - title
        - subtitle
        - highlight_items
        - music_style
        - transition_style
        - sharing_copy

        约束：
        - recommended_style 只能是：生活记录感、短视频爆款感、电影感纪念册
        - highlight_items 必须保持输入顺序或给出明确 priority
        - title 简短自然，不要夸张

        素材摘要：
        主题候选：\(summary.recommendedTheme)
        高光候选：
        \(highlights.isEmpty ? "- 无" : highlights)
        """
    }
}
