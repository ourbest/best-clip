import SwiftUI

struct AppRootView: View {
    @StateObject private var state = AppState()
    @StateObject private var flow = GenerationFlowViewModel()

    var body: some View {
        NavigationStack {
            switch state.currentRoute {
            case .home:
                HomeView(
                    onCreateMemoryVideo: { state.currentRoute = .selectMedia },
                    onOpenSettings: { state.currentRoute = .settings }
                )
            case .selectMedia:
                MediaPickerView(
                    assets: flow.availableAssets,
                    selectedAssetIDs: $flow.selectedAssetIDs,
                    onContinue: { state.currentRoute = .styleRecommendation }
                )
            case .styleRecommendation:
                StyleRecommendationView(
                    recommendation: flow.recommendation,
                    selectedStyle: $flow.selectedStyle,
                    onGenerate: { state.currentRoute = .generating },
                    onBack: { state.currentRoute = .selectMedia }
                )
            case .generating:
                GenerationProgressView(onFinished: {
                    flow.generatePreviewExport()
                    state.currentRoute = .result
                })
            case .result:
                ResultView(
                    exportURL: flow.exportURL,
                    onDone: { state.currentRoute = .home }
                )
            case .settings:
                SettingsView(onClose: { state.currentRoute = .home })
            }
        }
    }
}
