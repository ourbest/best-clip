import SwiftUI

struct GenerationProgressView: View {
    let stage: GenerationStage
    let onGenerate: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("步骤 3 / 3")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                Text("正在生成")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text(stage.subtitle)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                ProgressView(value: stage.progress)
                HStack {
                    Text(stage.title)
                        .font(.headline)
                    Spacer()
                    Text("\(Int(stage.progress * 100))%")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

            VStack(alignment: .leading, spacing: 12) {
                flowStep(title: "分析素材", detail: "整理照片、视频和文字线索")
                flowStep(title: "调用推荐", detail: "根据摘要生成标题和风格")
                flowStep(title: "导出视频", detail: "用本地 AVFoundation 渲染成片")
            }
            .padding()
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .padding()
        .task {
            await onGenerate()
        }
    }

    private func flowStep(title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: stepSymbol(for: title))
                .foregroundStyle(stepColor(for: title))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func stepSymbol(for title: String) -> String {
        switch title {
        case "分析素材":
            return stage == .idle ? "circle" : "checkmark.circle.fill"
        case "调用推荐":
            switch stage {
            case .idle, .preparing:
                return stage == .preparing ? "arrow.right.circle.fill" : "circle"
            default:
                return "checkmark.circle.fill"
            }
        case "导出视频":
            switch stage {
            case .finished:
                return "checkmark.circle.fill"
            case .exporting:
                return "arrow.triangle.2.circlepath.circle.fill"
            default:
                return "circle"
            }
        default:
            return "circle"
        }
    }

    private func stepColor(for title: String) -> Color {
        switch title {
        case "分析素材":
            return stage == .idle ? .secondary : .accent
        case "调用推荐":
            switch stage {
            case .idle:
                return .secondary
            case .preparing:
                return .accent
            default:
                return .accent
            }
        case "导出视频":
            switch stage {
            case .exporting, .finished:
                return .accent
            default:
                return .secondary
            }
        default:
            return .secondary
        }
    }
}
