import SwiftUI

struct ResultView: View {
    let exportURL: URL?
    let plan: CompositionPlan
    let summary: AssetSummary
    let clusters: [RecommendationCluster]
    let onDone: () -> Void
    let onSaveToPhotos: () -> Void
    let saveStatus: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                resultCard

                if let exportURL {
                    fileCard(exportURL: exportURL)

                    HStack(spacing: 12) {
                        ShareLink(item: exportURL) {
                            Label("分享视频", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button(action: onSaveToPhotos) {
                            Label("保存到相册", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .controlSize(.large)
                }

                if let saveStatus {
                    statusCard(text: saveStatus, systemImage: "checkmark.seal.fill")
                }

                if !clusters.isEmpty {
                    clusterCard
                }

                Button(action: onDone) {
                    Label("完成", systemImage: "house")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("generation_complete")
            }
            .padding()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("生成完成")
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text("结果已经导出，可以直接分享、保存，或者回到首页开始下一条回忆。")
                .foregroundStyle(.secondary)
        }
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(plan.title)
                        .font(.title2.bold())
                    Text(plan.subtitle)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }

            HStack(spacing: 8) {
                chip("\(plan.sections.count) 个片段")
                chip(plan.musicStyle)
                chip(plan.transitionStyle)
            }

            Text("已选择 \(summary.highlightItems.count) 个高光线索，输出为 \(plan.aspectRatio == .portrait9x16 ? "9:16 竖屏" : "自定义")。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func fileCard(exportURL: URL) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "film.stack.fill")
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(exportURL.lastPathComponent)
                    .font(.headline)
                Text(exportURL.path)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding()
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func statusCard(text: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
            Text(text)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.08), in: Capsule())
    }

    private var clusterCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("主题分组")
                    .font(.headline)
                Spacer()
                Text("\(clusters.count) 组")
                    .font(.caption.bold())
                    .foregroundStyle(Color.accentColor)
            }

            Text("按推荐高光和内容语义自动分组，优先展示最核心的主题。")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let primary = clusters.first {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(primary.title)
                                .font(.subheadline.bold())
                            Text(primary.reason)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(primary.itemCount) 项")
                            .font(.caption.bold())
                            .foregroundStyle(Color.accentColor)
                    }

                    Text("主分组覆盖 \(primary.itemCount) 个高光线索")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            if clusters.count > 1 {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(clusters.dropFirst()) { cluster in
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(cluster.title)
                                    .font(.subheadline.bold())
                                Text(cluster.reason)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(cluster.itemCount) 项")
                                .font(.caption.bold())
                                .foregroundStyle(Color.accentColor)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
