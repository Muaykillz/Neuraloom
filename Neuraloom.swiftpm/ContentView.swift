import SwiftUI

enum AppDestination {
    case home
    case allPlaygrounds
    case playground
    case learn
    case docs
}

struct ContentView: View {
    @StateObject private var playgroundStore = PlaygroundStore()
    @StateObject private var canvasViewModel = CanvasViewModel()
    @State private var destination: AppDestination = .home
    @State private var selectedProject: PlaygroundProject?

    private func navigate(to dest: AppDestination) {
        withAnimation(.easeInOut(duration: 0.4)) { destination = dest }
    }

    private func saveCurrentPreview() {
        guard let project = selectedProject,
              let image = ScreenCapture.captureWindow()
        else { return }
        project.savePreviewImage(image)
        playgroundStore.touch(id: project.id)
    }

    var body: some View {
        ZStack {
            switch destination {
            case .home:
                HomeView(
                    onOpenPlayground: { navigate(to: .allPlaygrounds) },
                    onOpenLearn: { navigate(to: .learn) },
                    onOpenDocs: { navigate(to: .docs) }
                )
                .transition(.opacity)
            case .allPlaygrounds:
                AllPlaygroundsView(
                    store: playgroundStore,
                    onSelect: { project in
                        selectedProject = project
                        canvasViewModel.resetCanvas()
                        switch project.demoType {
                        case .xor:
                            canvasViewModel.setupMVPScenario()
                        case .linearRegression:
                            canvasViewModel.setupLinearRegressionDemo()
                        case nil:
                            break
                        }
                        navigate(to: .playground)
                    },
                    onDismiss: { navigate(to: .home) }
                )
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            case .playground:
                PlaygroundView(onDismiss: {
                    saveCurrentPreview()
                    navigate(to: .allPlaygrounds)
                })
                    .environmentObject(canvasViewModel)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            case .learn:
                StoryChapterListView(
                    onDismiss: { navigate(to: .home) }
                )
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            case .docs:
                DocsView(onDismiss: { navigate(to: .home) })
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
    }
}