import SwiftUI

/// A single styled span within a cutscene quote line.
struct CutsceneSpan {
    let text: String
    var bold: Bool = false
    var italic: Bool = false
    var accent: Bool = false
}

/// One page of a cutscene: optional hero image + styled quote text + button.
struct CutscenePage: Identifiable {
    let id = UUID()
    var imageName: String?
    var sfSymbol: String?
    let lines: [[CutsceneSpan]]
    var buttonLabel: String = "Continue"
    var typewriterLine: String?
}

// MARK: - Single page view

struct StoryCutsceneView: View {
    let page: CutscenePage
    let onContinue: () -> Void

    @State private var appeared = false
    @State private var typedText = ""
    @State private var typewriterDone = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero image (asset or SF Symbol)
            if let imageName = page.imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
//                    .padding(40)
                    .frame(maxWidth: 440)
                    .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                    .padding(.bottom, 48)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
            } else if let symbol = page.sfSymbol {
                Image(systemName: symbol)
                    .font(.system(size: 64))
                    .foregroundStyle(.orange)
                    .padding(.bottom, 40)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
            }

            // Quote text
            VStack(spacing: 4) {
                ForEach(Array(page.lines.enumerated()), id: \.offset) { _, spans in
                    buildLine(spans)
                }
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .padding(.horizontal, 32)

            // Typewriter line (optional)
            if let fullText = page.typewriterLine {
                HStack(spacing: 8) {
                    Text(typedText)
                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)

                    if !typewriterDone {
                        Rectangle()
                            .fill(.secondary)
                            .frame(width: 2, height: 20)
                            .opacity(appeared ? 1 : 0)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16))
                            .foregroundStyle(.orange)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.top, 24)
                .opacity(appeared ? 1 : 0)
                .onChange(of: appeared) { _, visible in
                    if visible {
                        startTypewriter(fullText)
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            Button(action: onContinue) {
                Text(page.buttonLabel)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(minWidth: 200)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(Color.primary, in: Capsule())
            }
            .buttonStyle(.plain)
            .opacity(appeared ? 1 : 0)
            .padding(.bottom, 48)
        }
        .background(Color(UIColor.systemBackground))
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.15)) {
                appeared = true
            }
        }
    }

    // MARK: - Rich text builder

    private func buildLine(_ spans: [CutsceneSpan]) -> some View {
        spans.reduce(Text("")) { result, span in
            var font: Font = .system(size: 40, design: .serif)
            if span.bold && span.italic {
                font = .system(size: 40, design: .serif).bold().italic()
            } else if span.bold {
                font = .system(size: 40, design: .serif).bold()
            } else if span.italic {
                font = .system(size: 40, design: .serif).italic()
            }

            let color: Color = span.accent ? .orange : .primary

            let styledSpan = Text(span.text)
                .font(font)
                .foregroundColor(color)

            return Text("\(result)\(styledSpan)")
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Typewriter

    private func startTypewriter(_ fullText: String) {
        typedText = ""
        typewriterDone = false
        let chars = Array(fullText)
        for (i, char) in chars.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.04) {
                typedText.append(char)
                if i == chars.count - 1 {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        typewriterDone = true
                    }
                }
            }
        }
    }
}

