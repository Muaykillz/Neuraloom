import SwiftUI

struct AllPlaygroundsView: View {
    @ObservedObject var store: PlaygroundStore
    let onSelect: (PlaygroundProject) -> Void
    let onDismiss: () -> Void

    @State private var appeared = false

    private let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]

    var body: some View {
        ZStack {
            DotGridView(dotSpacing: 24)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 32)
                    .padding(.top, 24)
                    .padding(.bottom, 16)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        newPlaygroundCard
                        ForEach(store.projects) { project in
                            playgroundCard(project)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                }
            }
        }
        .background(Color(UIColor.systemBackground))
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                appeared = true
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                onDismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Home")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                }
                .foregroundStyle(.primary.opacity(0.7))
            }
            .buttonStyle(.plain)

            Spacer()

            Text("All Playgrounds")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Spacer()

            // Invisible spacer to balance the back button
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                Text("Home")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
            }
            .opacity(0)
        }
    }

    // MARK: - New Playground Card

    private var newPlaygroundCard: some View {
        Button {
            let project = store.create(name: "Playground \(store.projects.count)")
            onSelect(project)
        } label: {
            VStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(.secondary)
                Text("New Playground")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                    .foregroundStyle(.primary.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Playground Card

    private func playgroundCard(_ project: PlaygroundProject) -> some View {
        Button {
            onSelect(project)
        } label: {
            VStack(spacing: 0) {
                // Screenshot preview
                PlaygroundPreviewImage(project: project)
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .clipped()

                // Info bar
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(project.name)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            if project.isDemo {
                                Text("DEMO")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(.blue.opacity(0.7)))
                            }
                        }
                        Text(project.lastModifiedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .frame(height: 180, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !project.isDemo {
                Button(role: .destructive) {
                    store.delete(id: project.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Preview Image

private struct PlaygroundPreviewImage: View {
    let project: PlaygroundProject
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geo in
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            } else {
                ZStack {
                    Color.primary.opacity(0.03)
                    VStack(spacing: 6) {
                        Image(systemName: project.isDemo ? "sparkles" : "square.grid.3x3.topleft.filled")
                            .font(.system(size: 24, weight: .light))
                            .foregroundStyle(.quaternary)
                        if !project.isDemo {
                            Text("No preview yet")
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .foregroundStyle(.quaternary)
                        }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .onAppear {
            image = project.loadPreviewImage()
        }
    }
}
