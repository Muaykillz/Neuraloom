import SwiftUI

private enum StoryPhase: Equatable {
    case cutscene(Int)
    case playground(Int)
}

struct StoryChapterListView: View {
    let onDismiss: () -> Void
    @StateObject private var progressManager = StoryProgressManager()
    @State private var appeared = false
    @State private var activePhase: StoryPhase?

    var body: some View {
        ZStack {
            // Chapter list
            if activePhase == nil {
                ZStack(alignment: .topLeading) {
                    DotGridView(dotSpacing: 24)
                        .ignoresSafeArea()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Let's learn")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)

                            // Chapter cards
                            ForEach(Array(StoryChapter.all.enumerated()), id: \.element.id) { index, chapter in
                                ChapterCardView(
                                    chapter: chapter,
                                    isCompleted: progressManager.isCompleted(chapter.id),
                                    delay: Double(index) * 0.05
                                ) {
                                    withAnimation(.easeInOut(duration: 0.4)) {
                                        if cutscenePages(for: chapter.id) != nil {
                                            activePhase = .cutscene(chapter.id)
                                        } else if tourSteps(for: chapter.id) != nil {
                                            activePhase = .playground(chapter.id)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 96)
                        .padding(.bottom, 24)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                }
                .overlay(alignment: .topLeading) {
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
                    .padding(24)
                }
                .transition(.opacity)
            }

            // Cutscene phase
            if case .cutscene(let chapterID) = activePhase,
               let pages = cutscenePages(for: chapterID) {
                StoryCutsceneFlowView(pages: pages) {
                    if tourSteps(for: chapterID) != nil {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            activePhase = .playground(chapterID)
                        }
                    } else {
                        progressManager.completedChapters.insert(chapterID)
                        withAnimation(.easeInOut(duration: 0.4)) {
                            activePhase = nil
                        }
                    }
                }
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }

            // Playground phase
            if case .playground(let chapterID) = activePhase,
               let tourSteps = tourSteps(for: chapterID) {
                StoryPlaygroundView(
                    tourSteps: tourSteps,
                    onFinish: {
                        progressManager.completedChapters.insert(chapterID)
                        withAnimation(.easeInOut(duration: 0.4)) {
                            activePhase = nil
                        }
                    },
                    onHome: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            activePhase = nil
                        }
                    },
                    canvasSetup: canvasSetup(for: chapterID)
                )
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .background(Color(UIColor.systemBackground))
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                appeared = true
            }
        }
    }

    private func cutscenePages(for chapterID: Int) -> [CutscenePage]? {
        switch chapterID {
        case 1: return ChapterContent.chapter1Cutscene
        case 2: return ChapterContent.chapter2Cutscene
        case 3: return nil  // No cutscene — straight to playground
        default: return nil
        }
    }

    private func tourSteps(for chapterID: Int) -> [TourStep]? {
        switch chapterID {
        case 1: return ChapterContent.chapter1Tour
        case 2: return ChapterContent.chapter2Tour
        case 3: return ChapterContent.chapter3Tour
        default: return nil
        }
    }

    private func canvasSetup(for chapterID: Int) -> ((CanvasViewModel) -> Void)? {
        switch chapterID {
        case 1: return { $0.setupChapter1Scenario() }
        case 2: return { $0.setupChapter2Scenario() }
        case 3: return { $0.setupChapter3Scenario() }
        default: return nil
        }
    }
}

// MARK: - Chapter Card

private struct ChapterCardView: View {
    let chapter: StoryChapter
    let isCompleted: Bool
    let delay: Double
    let onTap: () -> Void

    @State private var appeared = false

    private var accentColor: Color {
        chapter.isLocked ? .gray : .orange
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: chapter.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(accentColor)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(accentColor.opacity(0.1))
                    )

                // Text
                VStack(alignment: .leading, spacing: 3) {
                    Text(chapter.isLocked ? chapter.title : "Chapter \(chapter.id): \(chapter.title)")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(chapter.isLocked ? .secondary : .primary)

                    Text(chapter.subtitle)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                if isCompleted && !chapter.isLocked {
                    CompletionBadge()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(chapter.isLocked)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            withAnimation(.easeOut(duration: 0.35).delay(delay + 0.15)) {
                appeared = true
            }
        }
    }
}

// MARK: - Completion Badge

private struct CompletionBadge: View {
    var body: some View {
        ZStack {
            // Green triangle in top-right corner
            Triangle()
                .fill(.green)
                .frame(width: 44, height: 44)

            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .offset(x: 9, y: -9)
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
