import SwiftUI

struct StoryPlaygroundView: View {
    let tourSteps: [TourStep]
    let onFinish: () -> Void
    var onHome: (() -> Void)?

    @StateObject private var canvasViewModel = CanvasViewModel()
    @State private var currentTourStep = 0
    @State private var tourDismissed = false

    var body: some View {
        ZStack {
            PlaygroundView(onDismiss: onHome)
                .environmentObject(canvasViewModel)

            if !tourDismissed {
                TourMessageBoxView(
                    steps: tourSteps,
                    currentStep: $currentTourStep,
                    onDismiss: finishTour,
                    canvasViewModel: canvasViewModel
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
            canvasViewModel.fulfilledTourConditions = []
            applyHighlight(for: currentTourStep)
        }
        .onChange(of: currentTourStep) { _, newStep in
            clearHighlight(for: newStep == 0 ? 0 : newStep - 1)
            applyHighlight(for: newStep)
        }
        .onChange(of: canvasViewModel.selectedConnectionId) { _, newId in
            if newId != nil {
                canvasViewModel.fulfillTourCondition(.weightTapped)
            }
        }
    }

    // MARK: - Tour Lifecycle

    private func finishTour() {
        clearHighlight(for: currentTourStep)
        tourDismissed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onFinish()
        }
    }

    // MARK: - Highlight Orchestration

    private func applyHighlight(for stepIndex: Int) {
        guard stepIndex < tourSteps.count else { return }
        guard let target = tourSteps[stepIndex].highlightTarget else { return }

        switch target {
        case .node(let id):
            canvasViewModel.selectedNodeId = id

        case .connection(let id):
            canvasViewModel.selectedConnectionId = id
            // Compute screen-space midpoint for the weight popover
            if let conn = canvasViewModel.connections.first(where: { $0.id == id }),
               let sourceNode = canvasViewModel.nodes.first(where: { $0.id == conn.sourceNodeId }),
               let targetNode = canvasViewModel.nodes.first(where: { $0.id == conn.targetNodeId }) {
                let midCanvas = CGPoint(
                    x: (sourceNode.position.x + targetNode.position.x) / 2,
                    y: (sourceNode.position.y + targetNode.position.y) / 2
                )
                let screenPt = CGPoint(
                    x: midCanvas.x * canvasViewModel.scale + canvasViewModel.offset.width,
                    y: midCanvas.y * canvasViewModel.scale + canvasViewModel.offset.height
                )
                canvasViewModel.connectionTapGlobalLocation = screenPt
            }

        case .glowNodes(let ids):
            canvasViewModel.glowingNodeIds = ids
        }
    }

    private func clearHighlight(for stepIndex: Int) {
        guard stepIndex < tourSteps.count else { return }
        guard let target = tourSteps[stepIndex].highlightTarget else { return }

        switch target {
        case .node:
            canvasViewModel.selectedNodeId = nil

        case .connection:
            canvasViewModel.selectedConnectionId = nil
            canvasViewModel.connectionTapGlobalLocation = nil

        case .glowNodes:
            canvasViewModel.glowingNodeIds = []
        }
    }
}
