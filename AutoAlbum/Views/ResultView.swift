import SwiftUI

struct ResultView: View {
    let exportURL: URL?
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("generation_complete")
                .font(.largeTitle.bold())
                .accessibilityIdentifier("generation_complete")

            if let exportURL {
                Text(exportURL.lastPathComponent)
                    .foregroundStyle(.secondary)
            }

            Button("完成", action: onDone)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
