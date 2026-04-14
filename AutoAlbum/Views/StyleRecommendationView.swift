import SwiftUI

struct StyleRecommendationView: View {
    let recommendation: LLMRecommendation?
    @Binding var selectedStyle: RecommendedStyle
    let onGenerate: () -> Void
    let onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                recommendationCard

                VStack(alignment: .leading, spacing: 12) {
                    Text("生成风格")
                        .font(.headline)
                    styleButton(
                        title: "生活记录感",
                        subtitle: "真实、轻松、适合日常碎片",
                        style: .lifeLog
                    )
                    styleButton(
                        title: "短视频爆款感",
                        subtitle: "节奏更快，标题和转场更有冲击力",
                        style: .shortVideo
                    )
                    styleButton(
                        title: "电影感纪念册",
                        subtitle: "更安静、更完整，强调氛围和情绪",
                        style: .cinematic
                    )
                }

                if let highlights = recommendation?.highlightItems, !highlights.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("推荐理由")
                            .font(.headline)
                        ForEach(Array(highlights.prefix(3)), id: \.id) { item in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "sparkle")
                                    .foregroundStyle(Color.accentColor)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("素材 \(item.id)")
                                        .font(.subheadline.bold())
                                    Text(item.reason)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                }

                Button(action: onGenerate) {
                    Label("开始生成视频", systemImage: "wand.and.stars")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("generate_video")

                Button(action: onBack) {
                    Label("返回选择素材", systemImage: "arrow.left")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("步骤 2 / 3")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text("风格推荐")
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text(recommendation?.subtitle ?? "系统会根据素材摘要自动推荐一个默认风格。")
                .foregroundStyle(.secondary)
        }
    }

    private var recommendationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(recommendation?.title ?? "等待推荐")
                        .font(.title2.bold())
                    Text(recommendation?.theme ?? "正在整理素材信息")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "film.stack")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }

            HStack(spacing: 8) {
                chip(recommendation?.recommendedStyle.rawValue ?? "默认风格")
                chip(recommendation?.musicStyle ?? "温暖轻快")
                chip(recommendation?.transitionStyle ?? "柔和转场")
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func styleButton(title: String, subtitle: String, style: RecommendedStyle) -> some View {
        Button {
            selectedStyle = style
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if selectedStyle == style {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(selectedStyle == style ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(selectedStyle == style ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: 1.2)
            )
        }
        .buttonStyle(.plain)
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.08), in: Capsule())
    }
}
