import PhotosUI
import SwiftUI

extension PhotosPickerItem: MediaSelectionItem {
    func loadFileURL() async throws -> URL? {
        try await loadTransferable(type: URL.self)
    }

    func loadData() async throws -> Data? {
        try await loadTransferable(type: Data.self)
    }
}

struct MediaPickerView: View {
    let assets: [MediaAssetSnapshot]
    @Binding var selectedAssetIDs: Set<String>
    let onContinue: () -> Void
    let onImportSelection: ([PhotosPickerItem]) async -> Void
    let importError: String?
    let isImporting: Bool
    let thumbnailCache: any ThumbnailCaching = ThumbnailCache.shared

    @State private var pickerItems: [PhotosPickerItem] = []

    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                summaryCard

                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: 30,
                    matching: .any(of: [.images, .videos])
                ) {
                    Label("从系统相册选择素材", systemImage: "photo.on.rectangle.angled")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    Task {
                        await onImportSelection(pickerItems)
                    }
                } label: {
                    Label("导入所选 \(pickerItems.count) 项", systemImage: "tray.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(pickerItems.isEmpty || isImporting)

                if isImporting {
                    statusBanner(title: "正在导入素材", subtitle: "分析照片、视频和关键帧，准备生成。")
                }

                if let importError {
                    statusBanner(title: "导入失败", subtitle: importError, isError: true)
                }

                if assets.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(assets) { asset in
                            Button {
                                toggle(asset)
                            } label: {
                                assetCard(for: asset)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("asset_\(asset.id)")
                        }
                    }
                }

                Button(action: onContinue) {
                    Label("继续到风格推荐", systemImage: "arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(selectedAssetIDs.isEmpty)
                .accessibilityIdentifier("continue_to_style")
            }
            .padding()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("步骤 1 / 3")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text("选择照片和视频")
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text("建议选择 5 到 20 个素材，系统会自动识别照片、视频、文字和高光场景。")
                .foregroundStyle(.secondary)
        }
    }

    private var summaryCard: some View {
        let selectedCount = selectedAssetIDs.count
        let photoCount = assets.filter { $0.kind == .photo }.count
        let videoCount = assets.filter { $0.kind == .video }.count

        return HStack(spacing: 12) {
            metricCard(title: "已导入", value: "\(assets.count)")
            metricCard(title: "已选中", value: "\(selectedCount)")
            metricCard(title: "照片 / 视频", value: "\(photoCount)/\(videoCount)")
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statusBanner(title: String, subtitle: String, isError: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "arrow.down.circle.fill")
                .foregroundStyle(isError ? .red : Color.accentColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background((isError ? Color.red.opacity(0.10) : Color.accentColor.opacity(0.10)), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "photo.stack")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            Text("还没有导入素材")
                .font(.headline)
            Text("先从系统相册导入照片和视频，再继续风格推荐。")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func assetCard(for asset: MediaAssetSnapshot) -> some View {
        let isSelected = selectedAssetIDs.contains(asset.id)

        return VStack(alignment: .leading, spacing: 10) {
            ThumbnailPreviewView(
                previewURL: asset.previewURL,
                kind: asset.kind,
                cache: thumbnailCache,
                maxDimension: 320
            )
                .frame(height: 108)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            HStack {
                Label(asset.kind == .photo ? "照片" : "视频", systemImage: asset.kind == .photo ? "photo" : "video")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }

            Text(asset.scene)
                .font(.headline)
                .lineLimit(2)

            Text(asset.kind == .photo ? "人脸 \(asset.faces) · 清晰度 \(asset.sharpness, specifier: "%.2f")" : "稳定度 \(asset.stability, specifier: "%.2f") · 时长 \(asset.duration ?? 0, specifier: "%.0f")s")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                tag(asset.kind == .photo ? "静态片段" : "动态片段")
                if asset.ocrText?.isEmpty == false {
                    tag("含文字")
                }
                if asset.speechText?.isEmpty == false {
                    tag("含语音")
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.55) : Color.clear, lineWidth: 1.5)
        )
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.10), in: Capsule())
    }

    private func toggle(_ asset: MediaAssetSnapshot) {
        if selectedAssetIDs.contains(asset.id) {
            selectedAssetIDs.remove(asset.id)
        } else {
            selectedAssetIDs.insert(asset.id)
        }
    }
}
