import SwiftUI

struct ContentView: View {
    @StateObject var canvasViewModel = CanvasViewModel()
    @State private var showPlayground = true

    var body: some View {
        if showPlayground {
            PlaygroundView(onDismiss: { showPlayground = false })
                .environmentObject(canvasViewModel)
        } else {
            HomeView(onOpenPlayground: { showPlayground = true })
        }
    }
}
