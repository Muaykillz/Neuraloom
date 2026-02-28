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
                Image(systemName: "house.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
                    .glassEffect(in: .circle)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("All Playgrounds")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Spacer()

            Color.clear
                .frame(width: 44, height: 44)
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
            .frame(height: 240)
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
                    .frame(height: 180)
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

                    if !project.isDemo {
                        Menu {
                            Button(role: .destructive) {
                                store.delete(id: project.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .frame(height: 240, alignment: .top)
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
                    if project.isDemo {
                        LinearGradient(
                            colors: [.blue.opacity(0.08), .purple.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        VStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 28, weight: .light))
                                .foregroundStyle(.blue.opacity(0.5))
                            Text(project.name)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.blue.opacity(0.5))
                        }
                    } else {
                        Color.primary.opacity(0.03)
                        VStack(spacing: 6) {
                            Image(systemName: "square.grid.3x3.topleft.filled")
                                .font(.system(size: 24, weight: .light))
                                .foregroundStyle(.quaternary)
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
