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
                        if project.isDemo {
                            canvasViewModel.setupMVPScenario()
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
                PlaceholderDestinationView(
                    title: "Documentation",
                    icon: "book.closed.fill",
                    color: .purple,
                    onDismiss: { navigate(to: .home) }
                )
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
    }
}

struct PlaceholderDestinationView: View {
    let title: String
    let icon: String
    let color: Color
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundStyle(color)

            Text(title)
                .font(.system(size: 32, weight: .bold, design: .rounded))

            Text("Coming Soon")
                .font(.title3)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                onDismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                    Text("Back to Home")
                        .font(.body.bold())
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(color, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }
}
