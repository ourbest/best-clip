import SwiftUI

struct GenerationProgressView: View {
    let onFinished: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("正在生成")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            onFinished()
        }
    }
}
