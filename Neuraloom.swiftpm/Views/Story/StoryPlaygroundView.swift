import SwiftUI

struct StoryPlaygroundView: View {
    let tourSteps: [TourStep]
    let onFinish: () -> Void

    @StateObject private var canvasViewModel = CanvasViewModel()
    @State private var currentTourStep = 0
    @State private var tourDismissed = false

    var body: some View {
        ZStack {
            PlaygroundView()
                .environmentObject(canvasViewModel)

            if !tourDismissed {
                TourMessageBoxView(
                    steps: tourSteps,
                    currentStep: $currentTourStep,
                    onDismiss: finishTour
                )
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: tourDismissed)
        .onAppear {
            canvasViewModel.setupMVPScenario()
        }
    }

    private func finishTour() {
        tourDismissed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onFinish()
        }
    }
}
