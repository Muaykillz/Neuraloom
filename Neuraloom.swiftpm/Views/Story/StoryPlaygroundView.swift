import SwiftUI

struct StoryPlaygroundView: View {
    let tourSteps: [TourStep]
    let onFinish: () -> Void
    var onHome: (() -> Void)?
    var canvasSetup: ((CanvasViewModel) -> Void)?

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
            if let setup = canvasSetup {
                setup(canvasViewModel)
            } else {
                canvasViewModel.setupMVPScenario()
            }
            canvasViewModel.fulfilledTourConditions = []
            applyHighlight(for: currentTourStep)
            // Delay initial onEnter so PlaygroundView has time to set viewportSize
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                tourSteps[currentTourStep].onEnter?(canvasViewModel)
            }
        }
        .onChange(of: currentTourStep) { _, newStep in
            clearHighlight(for: newStep == 0 ? 0 : newStep - 1)
            applyHighlight(for: newStep)
            tourSteps[newStep].onEnter?(canvasViewModel)
        }
        .onChange(of: canvasViewModel.learningRate) { _, _ in
            canvasViewModel.storyLRChanged = true
        }
        .onChange(of: canvasViewModel.selectedConnectionId) { _, newId in
            guard let connId = newId else { return }
            canvasViewModel.fulfillTourCondition(.weightTapped())
            canvasViewModel.fulfillTourCondition(.weightTapped(connectionId: connId))
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

        case .connection(let id), .weight(let id):
            canvasViewModel.selectedConnectionId = id
            setConnectionPopoverLocation(for: id)

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

        case .connection, .weight:
            canvasViewModel.selectedConnectionId = nil
            canvasViewModel.connectionTapGlobalLocation = nil

        case .glowNodes:
            canvasViewModel.glowingNodeIds = []
        }
    }

    private func setConnectionPopoverLocation(for connectionId: UUID) {
        guard let conn = canvasViewModel.connections.first(where: { $0.id == connectionId }),
              let sourceNode = canvasViewModel.nodes.first(where: { $0.id == conn.sourceNodeId }),
              let targetNode = canvasViewModel.nodes.first(where: { $0.id == conn.targetNodeId }) else { return }

        let midCanvas = CGPoint(
            x: (sourceNode.position.x + targetNode.position.x) / 2,
            y: (sourceNode.position.y + targetNode.position.y) / 2
        )
        canvasViewModel.connectionTapGlobalLocation = CGPoint(
            x: midCanvas.x * canvasViewModel.scale + canvasViewModel.offset.width,
            y: midCanvas.y * canvasViewModel.scale + canvasViewModel.offset.height
        )
    }
}
