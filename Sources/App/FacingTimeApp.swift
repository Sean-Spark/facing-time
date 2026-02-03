import SwiftUI

@main
struct FacingTimeApp: App {
    @StateObject private var appState = AppState(networkService: NetworkService.shared)

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        #endif
    }
}
