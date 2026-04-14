import SwiftUI
import UIKit

struct ThumbnailPreviewView: View {
    let previewURL: URL?
    let kind: MediaAssetKind
    let cache: any ThumbnailCaching
    var maxDimension: CGFloat = 320

    @State private var thumbnailData: Data?
    @State private var isLoading = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            previewContent

            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.26)],
                startPoint: .top,
                endPoint: .bottom
            )

            HStack(spacing: 6) {
                Image(systemName: kind == .photo ? "photo" : "video.fill")
                Text(kind == .photo ? "照片封面" : "视频封面")
            }
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(8)
        }
        .clipped()
        .task(id: taskKey) {
            await loadThumbnailIfNeeded()
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        if let thumbnailData, let image = UIImage(data: thumbnailData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.18),
                    Color.orange.opacity(0.14),
                    Color.secondary.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if isLoading {
                ProgressView()
                    .tint(.white)
            }
        }
    }

    private var taskKey: String {
        previewURL?.path ?? "placeholder-\(kind.rawValue)"
    }

    @MainActor
    private func loadThumbnailIfNeeded() async {
        guard thumbnailData == nil, !isLoading else { return }
        guard let previewURL else { return }

        isLoading = true
        defer { isLoading = false }

        thumbnailData = await cache.thumbnailData(for: previewURL, maxDimension: maxDimension)
    }
}
