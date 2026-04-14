import SwiftUI

struct SettingsView: View {
    @Binding var modelName: String
    @Binding var apiKey: String
    let statusMessage: String?
    let onSave: () -> Void
    let onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                VStack(alignment: .leading, spacing: 12) {
                    Text("模型配置")
                        .font(.headline)
                    TextField("gpt-4o-mini", text: $modelName)
                        .textFieldStyle(.roundedBorder)

                    Text("OpenAI API Key")
                        .font(.headline)
                    SecureField("sk-...", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text("说明")
                        .font(.headline)
                    Text("API Key 会保存在本地 Keychain 中，不会写入明文设置文件。模型只接收摘要和关键帧，不会把整套相册上传。")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                if let statusMessage {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.accent)
                        Text(statusMessage)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding()
                    .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                HStack(spacing: 12) {
                    Button(action: onSave) {
                        Label("保存设置", systemImage: "tray.and.arrow.down.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: onClose) {
                        Label("完成", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.large)
            }
            .padding()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("设置")
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text("把模型名和 API Key 配好后，生成按钮就会走真实推荐和导出流程。")
                .foregroundStyle(.secondary)
        }
    }
}
