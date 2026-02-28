import SwiftUI

struct StoryCutsceneFlowView: View {
    let pages: [CutscenePage]
    let onFinish: () -> Void

    @State private var currentIndex = 0

    var body: some View {
        ZStack {
            StoryCutsceneView(
                page: pages[currentIndex],
                onContinue: advance
            )
            .id(currentIndex)
            .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.5), value: currentIndex)
    }

    private func advance() {
        if currentIndex < pages.count - 1 {
            currentIndex += 1
        } else {
            onFinish()
        }
    }
}
