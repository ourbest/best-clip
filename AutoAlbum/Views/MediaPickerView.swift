import SwiftUI

struct MediaPickerView: View {
    let assets: [MediaAssetSnapshot]
    @Binding var selectedAssetIDs: Set<String>
    let onContinue: () -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("选择照片和视频")
                    .font(.largeTitle.bold())

                Text("先选一批素材，系统会自动识别高光和风格。")
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(assets) { asset in
                        Button {
                            toggle(asset)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(asset.kind == .photo ? "照片" : "视频")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                Text(asset.scene)
                                    .font(.headline)
                                Text(asset.id)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
                            .padding()
                            .background(selectedAssetIDs.contains(asset.id) ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("asset_\(asset.id)")
                    }
                }

                Button("continue_to_style", action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedAssetIDs.isEmpty)
                    .accessibilityIdentifier("continue_to_style")
            }
            .padding()
        }
    }

    private func toggle(_ asset: MediaAssetSnapshot) {
        if selectedAssetIDs.contains(asset.id) {
            selectedAssetIDs.remove(asset.id)
        } else {
            selectedAssetIDs.insert(asset.id)
        }
    }
}
