import SwiftUI

// MARK: - Tour Rich Text

struct TourSpan {
    let text: String
    var bold: Bool = false
    var italic: Bool = false
    var accent: Bool = false
    var mono: Bool = false
    var color: Color? = nil
}

// MARK: - Tour Completion Conditions

enum TourCompletionCondition: Equatable {
    case inspectModeOpened
    case weightChanged(connectionId: UUID? = nil)
    case weightTapped(connectionId: UUID? = nil)
    case trainingStepRun
    case trainStarted
    case nodeAdded
    case connectionMade
    case custom(id: String)

    var key: String {
        switch self {
        case .inspectModeOpened: return "inspectModeOpened"
        case .weightChanged(let id): return id.map { "weightChanged.\($0)" } ?? "weightChanged"
        case .weightTapped(let id): return id.map { "weightTapped.\($0)" } ?? "weightTapped"
        case .trainingStepRun: return "trainingStepRun"
        case .trainStarted: return "trainStarted"
        case .nodeAdded: return "nodeAdded"
        case .connectionMade: return "connectionMade"
        case .custom(let id): return "custom.\(id)"
        }
    }
}

// MARK: - Tour Highlight Target

enum TourHighlightTarget {
    case node(id: UUID)
    case connection(id: UUID)
    case weight(id: UUID)
    case glowNodes(ids: Set<UUID>)
}

// MARK: - Tour Step

struct TourStep {
    let title: String
    let richBody: [[TourSpan]]
    var completionCondition: TourCompletionCondition?
    var highlightTarget: TourHighlightTarget?
    var buttonLabel: String?
    var onEnter: (@MainActor @Sendable (CanvasViewModel) -> Void)?

    /// Convenience init that keeps existing plain-text callers compiling.
    init(title: String, body: String) {
        self.title = title
        self.richBody = [[TourSpan(text: body)]]
    }

    init(
        title: String,
        body: [[TourSpan]],
        completionCondition: TourCompletionCondition? = nil,
        highlightTarget: TourHighlightTarget? = nil,
        buttonLabel: String? = nil,
        onEnter: (@MainActor @Sendable (CanvasViewModel) -> Void)? = nil
    ) {
        self.title = title
        self.richBody = body
        self.completionCondition = completionCondition
        self.highlightTarget = highlightTarget
        self.buttonLabel = buttonLabel
        self.onEnter = onEnter
    }
}

// MARK: - Tour Message Box View

struct TourMessageBoxView: View {
    let steps: [TourStep]
    @Binding var currentStep: Int
    let onDismiss: () -> Void
    var canvasViewModel: CanvasViewModel?

    @State private var isCollapsed = false

    private var step: TourStep { steps[currentStep] }
    private var isFirst: Bool { currentStep == 0 }
    private var isLast: Bool { currentStep == steps.count - 1 }

    private var isNextLocked: Bool {
        guard let condition = step.completionCondition,
              let vm = canvasViewModel else { return false }
        return !vm.fulfilledTourConditions.contains(condition.key)
    }

    private var nextLabel: String {
        if let custom = step.buttonLabel, isLast { return custom }
        return isLast ? "Done" : "Next"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title row (always visible)
            HStack(alignment: .top) {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 10, height: 10)
                    .padding(.top, 5)

                Text(step.title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isCollapsed.toggle()
                    }
                } label: {
                    Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if !isCollapsed {
                // Body — rich text
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(step.richBody.enumerated()), id: \.offset) { _, spans in
                        buildTourLine(spans)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)

                // Footer navigation
                HStack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            currentStep -= 1
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isFirst ? .tertiary : .primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(isFirst)

                    Spacer()

                    Text("\(currentStep + 1) of \(steps.count)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        if isLast {
                            onDismiss()
                        } else {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                currentStep += 1
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if isNextLocked {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            Text(nextLabel)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                            if !isLast && !isNextLocked {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isNextLocked ? .gray : .orange)
                    .disabled(isNextLocked)
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 12)
    }

    // MARK: - Rich text builder

    private func buildTourLine(_ spans: [TourSpan]) -> some View {
        spans.reduce(Text("")) { result, span in
            var font: Font
            if span.mono {
                font = .system(size: 15, design: .monospaced)
            } else {
                font = .system(size: 15, design: .rounded)
            }

            if span.bold && span.italic {
                font = font.bold().italic()
            } else if span.bold {
                font = font.bold()
            } else if span.italic {
                font = font.italic()
            }

            let color: Color = span.color ?? (span.accent ? .orange : .secondary)

            let styledSpan = Text(span.text)
                .font(font)
                .foregroundColor(color)

            return Text("\(result)\(styledSpan)")
        }
    }
}
