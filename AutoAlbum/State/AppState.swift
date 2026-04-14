import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var currentRoute: AppRoute = .home
    @Published var isGenerating = false
    @Published var latestError: String? = nil
}
