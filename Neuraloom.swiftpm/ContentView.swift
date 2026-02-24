import SwiftUI

struct ContentView: View {
    @StateObject var canvasViewModel = CanvasViewModel()
    
    var body: some View {
        PlaygroundView()
            .environmentObject(canvasViewModel)
            .task {
                guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
                runAllCoreEngineTests()
                await runCanvasIntegrationTests()
            }
    }
}
