import SwiftUI

struct HomeView: View {
    let onCreateMemoryVideo: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("相册回忆自动成片")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("从照片和视频中自动生成一条可分享的回忆视频。")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                heroCard

                VStack(alignment: .leading, spacing: 12) {
                    Text("工作流")
                        .font(.headline)
                    workflowStep(number: "1", title: "导入素材", subtitle: "从系统相册选出照片和视频")
                    workflowStep(number: "2", title: "风格推荐", subtitle: "LLM 根据素材摘要生成建议")
                    workflowStep(number: "3", title: "生成并分享", subtitle: "本地导出后可直接分享或保存")
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                Button(action: onCreateMemoryVideo) {
                    Label("开始生成回忆视频", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("new_memory_video")

                Button(action: onOpenSettings) {
                    Label("设置模型与 API Key", systemImage: "gearshape")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding()
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("智能生成")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text("把相册里最值得留住的片段，整理成一条可以直接分享的视频。")
                        .font(.headline)
                }
                Spacer()
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.accent)
            }

            HStack(spacing: 8) {
                statusChip(title: "导入相册")
                statusChip(title: "LLM 推荐")
                statusChip(title: "一键导出")
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.16),
                    Color.orange.opacity(0.10),
                    Color.secondary.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
    }

    private func workflowStep(number: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.subheadline.bold())
                .frame(width: 28, height: 28)
                .foregroundStyle(.accent)
                .background(Color.accentColor.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func statusChip(title: String) -> some View {
        Text(title)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.08), in: Capsule())
    }
}
