import SwiftUI

struct HomeView: View {
    let onCreateMemoryVideo: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("相册回忆自动成片")
                    .font(.largeTitle.bold())
                Text("从照片和视频中自动生成一条可分享的回忆视频。")
                    .foregroundStyle(.secondary)

                Button(action: onCreateMemoryVideo) {
                    Text("new_memory_video")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("new_memory_video")

                Button("设置", action: onOpenSettings)
                    .buttonStyle(.bordered)
            }
            .padding()
        }
    }
}
