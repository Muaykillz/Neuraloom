import SwiftUI

// MARK: - Sticker View

struct StickerView: View {
    let imageName: String
    let size: CGFloat
    let rotation: Double
    var delay: Double = 0

    @State private var floatOffset: CGFloat = 0
    @State private var appeared = false

    var body: some View {
        Image(imageName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.2), radius: 10, x: 3, y: 6)
            .rotationEffect(.degrees(rotation))
            .offset(y: floatOffset)
            .scaleEffect(appeared ? 1 : 0.3)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(delay)) {
                    appeared = true
                }
                withAnimation(
                    .easeInOut(duration: Double.random(in: 2.5...3.5))
                    .repeatForever(autoreverses: true)
                    .delay(delay + 0.5)
                ) {
                    floatOffset = CGFloat.random(in: 8...14) * (Bool.random() ? 1 : -1)
                }
            }
    }
}

// MARK: - Sticker Data

private struct StickerPlacement: Identifiable {
    let id = UUID()
    let imageName: String
    let size: CGFloat
    let rotation: Double
    let xFraction: CGFloat
    let yFraction: CGFloat
}

private let stickers: [StickerPlacement] = [
    StickerPlacement(imageName: "Neuraloom", size: 200, rotation: -5, xFraction: 0.15, yFraction: 0.25),
    StickerPlacement(imageName: "NeuralNetwork", size: 140, rotation: 6, xFraction: 0.82, yFraction: 0.18),
    StickerPlacement(imageName: "LossChart", size: 160, rotation: -3, xFraction: 0.20, yFraction: 0.75),
    StickerPlacement(imageName: "Sparkles", size: 140, rotation: 8, xFraction: 0.85, yFraction: 0.58),
    StickerPlacement(imageName: "Maginfying", size: 120, rotation: -4, xFraction: 0.75, yFraction: 0.78),
]

// MARK: - Home View

struct HomeView: View {
    var onOpenPlayground: () -> Void
    var onOpenLearn: () -> Void
    var onOpenDocs: () -> Void

    @State private var titleAppeared = false
    @State private var buttonsAppeared = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background dot grid
                DotGridView(dotSpacing: 24)
                    .ignoresSafeArea()

                // Floating stickers
                ForEach(Array(stickers.enumerated()), id: \.element.id) { index, sticker in
                    StickerView(
                        imageName: sticker.imageName,
                        size: sticker.size,
                        rotation: sticker.rotation,
                        delay: Double(index) * 0.08
                    )
                    .position(
                        x: geo.size.width * sticker.xFraction,
                        y: geo.size.height * sticker.yFraction
                    )
                }

                // Center content
                VStack(spacing: 12) {
                    Spacer()

                    // Title
                    Text("Neuraloom")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .opacity(titleAppeared ? 1 : 0)
                        .offset(y: titleAppeared ? 0 : 20)

                    Text("Drag, Drop, Draw — Neural Networks Made Simple")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .opacity(titleAppeared ? 1 : 0)
                        .offset(y: titleAppeared ? 0 : 12)

                    Spacer().frame(height: 40)

                    // Vertical minimal buttons
                    VStack(spacing: 12) {
                        HomeTextButton(title: "Learn Neural Networks", action: onOpenLearn)
                        HomeTextButton(title: "Open Playground", action: onOpenPlayground)
                        HomeTextButton(title: "Documentation", action: onOpenDocs)
                    }
                    .frame(width: 260)
                    .opacity(buttonsAppeared ? 1 : 0)
                    .offset(y: buttonsAppeared ? 0 : 16)

                    Spacer()
                }
            }
        }
        .background(Color(UIColor.systemBackground))
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                titleAppeared = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.45)) {
                buttonsAppeared = true
            }
        }
    }
}

// MARK: - Minimal Text Button

private struct HomeTextButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    Capsule()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
