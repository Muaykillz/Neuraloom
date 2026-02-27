import SwiftUI

enum AppDestination {
    case home
    case playground
    case learn
    case docs
}

struct ContentView: View {
    @StateObject var canvasViewModel = CanvasViewModel.init()
    @State private var destination: AppDestination = .home

    var body: some View {
        ZStack {
            switch destination {
            case .home:
                HomeView(
                    onOpenPlayground: { withAnimation(.easeInOut(duration: 0.4)) { destination = .playground } },
                    onOpenLearn: { withAnimation(.easeInOut(duration: 0.4)) { destination = .learn } },
                    onOpenDocs: { withAnimation(.easeInOut(duration: 0.4)) { destination = .docs } }
                )
                .transition(.opacity)
            case .playground:
                PlaygroundView(onDismiss: { withAnimation(.easeInOut(duration: 0.4)) { destination = .home } })
                    .environmentObject(canvasViewModel)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            case .learn:
                PlaceholderDestinationView(
                    title: "Learn Neural Networks",
                    icon: "brain.head.profile",
                    color: .blue,
                    onDismiss: { withAnimation(.easeInOut(duration: 0.4)) { destination = .home } }
                )
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            case .docs:
                PlaceholderDestinationView(
                    title: "Documentation",
                    icon: "book.closed.fill",
                    color: .purple,
                    onDismiss: { withAnimation(.easeInOut(duration: 0.4)) { destination = .home } }
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
