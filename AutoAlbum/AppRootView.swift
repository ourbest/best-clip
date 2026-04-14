import SwiftUI

struct AppRootView: View {
    @StateObject private var state = AppState()
    @StateObject private var flow = GenerationFlowViewModel()

    var body: some View {
        ZStack {
            ProductBackdrop()

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
                        onContinue: { state.currentRoute = .styleRecommendation },
                        onImportSelection: { items in
                            await flow.importSelection(items)
                        },
                        importError: flow.importError,
                        isImporting: flow.isImporting
                    )
                case .styleRecommendation:
                    StyleRecommendationView(
                        recommendation: flow.recommendation,
                        selectedStyle: $flow.selectedStyle,
                        onGenerate: { state.currentRoute = .generating },
                        onBack: { state.currentRoute = .selectMedia }
                    )
                case .generating:
                    GenerationProgressView(stage: flow.generationStage, onGenerate: {
                        await flow.generatePreviewExportAsync()
                        if flow.exportURL != nil {
                            await MainActor.run {
                                state.currentRoute = .result
                            }
                        }
                    })
                case .result:
                    ResultView(
                        exportURL: flow.exportURL,
                        plan: flow.plan(),
                        summary: flow.summary(),
                        onDone: { state.currentRoute = .home },
                        onSaveToPhotos: {
                            flow.saveExportToPhotos()
                        },
                        saveStatus: flow.saveStatus
                    )
                case .settings:
                    SettingsView(
                        modelName: $flow.settingsModelName,
                        apiKey: $flow.settingsAPIKey,
                        statusMessage: flow.saveStatus,
                        onSave: { flow.saveSettings() },
                        onClose: { state.currentRoute = .home }
                    )
                }
            }
        }
    }
}

private struct ProductBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.95, blue: 0.90),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.orange.opacity(0.16))
                .frame(width: 260, height: 260)
                .blur(radius: 80)
                .offset(x: -150, y: -220)

            Circle()
                .fill(Color.blue.opacity(0.12))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: 170, y: 280)
        }
        .ignoresSafeArea()
    }
}
