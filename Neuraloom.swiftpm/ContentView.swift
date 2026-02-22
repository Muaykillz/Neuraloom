import SwiftUI

struct ContentView: View {
    @StateObject var canvasViewModel = CanvasViewModel()
    
    var body: some View {
        PlaygroundView()
            .environmentObject(canvasViewModel)
    }
}
