import SwiftUI

struct SettingsView: View {
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("设置")
                .font(.largeTitle.bold())
            Text("将把素材摘要或关键帧发送给云端大模型，用于风格推荐和标题生成。")
                .foregroundStyle(.secondary)

            Button("完成", action: onClose)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
