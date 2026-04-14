import SwiftUI

struct StyleRecommendationView: View {
    let recommendation: LLMRecommendation?
    @Binding var selectedStyle: RecommendedStyle
    let onGenerate: () -> Void
    let onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("风格推荐")
                    .font(.largeTitle.bold())

                Text(recommendation?.title ?? "等待推荐")
                    .font(.title2.bold())

                Text(recommendation?.subtitle ?? "系统会根据素材自动推荐一个默认风格。")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    styleButton(title: "生活记录感", style: .lifeLog)
                    styleButton(title: "短视频爆款感", style: .shortVideo)
                    styleButton(title: "电影感纪念册", style: .cinematic)
                }

                Button("generate_video", action: onGenerate)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("generate_video")

                Button("返回", action: onBack)
                    .buttonStyle(.bordered)
            }
            .padding()
        }
    }

    private func styleButton(title: String, style: RecommendedStyle) -> some View {
        Button {
            selectedStyle = style
        } label: {
            HStack {
                Text(title)
                Spacer()
                if selectedStyle == style {
                    Image(systemName: "checkmark.circle.fill")
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(selectedStyle == style ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
