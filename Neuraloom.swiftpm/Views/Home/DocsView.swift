import SwiftUI

struct DocsView: View {
    let onDismiss: () -> Void
    @State private var appeared = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            DotGridView(dotSpacing: 24)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Documentation")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("A quick guide to every component you can use on the canvas.")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)

                    // Neural Network
                    DocSectionView(title: "Neural Network", items: [
                        DocItem(
                            icon: .custom(AnyView(NeuronMiniIcon())),
                            color: .orange,
                            name: "Neuron",
                            description: "The fundamental building block. Receives inputs, multiplies by weights, sums them up, and applies an activation function to produce an output.",
                            details: [
                                "Roles: Input, Hidden, Output, or Bias",
                                "Activations: Linear, ReLU, Sigmoid",
                                "Tap to inspect value & gradient"
                            ]
                        ),
                        DocItem(
                            icon: .system("tablecells.fill"),
                            color: .blue,
                            name: "Dataset",
                            description: "Provides training data. Each row is a sample with input columns (X) and a target column (Y).",
                            details: [
                                "Presets: Linear, XOR, Circle, Spiral",
                                "Connect X ports to Input neurons",
                                "Connect Y port to Loss node"
                            ]
                        ),
                        DocItem(
                            icon: .system("target"),
                            color: .red,
                            name: "Loss",
                            description: "Measures how wrong the network's predictions are. Compares predicted output (y\u{0302}) against the true target (y).",
                            details: [
                                "Functions: MSE, Cross-Entropy",
                                "Lower loss = better predictions",
                                "Tap to see the loss formula breakdown"
                            ]
                        ),
                    ])

                    // Utilities
                    DocSectionView(title: "Utilities", items: [
                        DocItem(
                            icon: .system("eye.circle.fill"),
                            color: .green,
                            name: "Result",
                            description: "Displays the output value of a neuron during inference. Automatically placed when entering inference mode.",
                            details: [
                                "Shows predicted value in real-time",
                                "Useful for checking network output"
                            ]
                        ),
                        DocItem(
                            icon: .custom(AnyView(NumberMiniIcon())),
                            color: .teal,
                            name: "Number",
                            description: "A constant value node. Feeds a fixed number into any neuron — useful for manual testing.",
                            details: [
                                "Adjustable value via text field",
                                "Connect to an Input neuron"
                            ]
                        ),
                        DocItem(
                            icon: .system("note.text"),
                            color: .gray,
                            name: "Annotation",
                            description: "A sticky-note for the canvas. Add text labels to document your network design.",
                            details: [
                                "Editable text content",
                                "No data connections — visual only"
                            ]
                        ),
                    ])

                    // Analysis
                    DocSectionView(title: "Analysis", items: [
                        DocItem(
                            icon: .system("chart.line.uptrend.xyaxis"),
                            color: .purple,
                            name: "Visualization",
                            description: "Displays a live loss curve chart. Connect it to a Loss node to watch training progress over time.",
                            details: [
                                "X-axis: Epoch, Y-axis: Loss",
                                "Curve should trend downward during training"
                            ]
                        ),
                        DocItem(
                            icon: .system("chart.dots.scatter"),
                            color: .teal,
                            name: "Scatter Plot",
                            description: "Plots data points on a 2D chart. Shows real data vs. predictions side by side.",
                            details: [
                                "Blue dots: actual data",
                                "Orange dots: model predictions",
                                "Available in inference mode"
                            ]
                        ),
                    ])

                    // Concepts
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Key Concepts")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)

                        ConceptCardView(
                            term: "Weight",
                            icon: "line.diagonal",
                            color: .orange,
                            explanation: "A learnable parameter on each connection between neurons. During training, weights are adjusted to reduce the loss. Tap any connection line to inspect its weight value and gradient (dL/dw)."
                        )
                        ConceptCardView(
                            term: "Forward Pass",
                            icon: "arrow.right",
                            color: .blue,
                            explanation: "Data flows from input neurons through the network to produce a prediction. Each neuron computes: output = activation(sum of weighted inputs)."
                        )
                        ConceptCardView(
                            term: "Backward Pass",
                            icon: "arrow.left",
                            color: .red,
                            explanation: "After computing the loss, gradients flow backward through the network. Each weight learns how much it contributed to the error, so it can be adjusted."
                        )
                        ConceptCardView(
                            term: "Learning Rate (LR)",
                            icon: "speedometer",
                            color: .green,
                            explanation: "Controls how big each weight adjustment is. Too high and the model overshoots; too low and training is painfully slow. Common values: 0.01 – 0.1."
                        )
                        ConceptCardView(
                            term: "Epoch",
                            icon: "repeat",
                            color: .purple,
                            explanation: "One full pass through the entire dataset. Training typically runs for many epochs until the loss converges."
                        )
                    }

                    Spacer(minLength: 40)
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
        .background(Color(UIColor.systemBackground))
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                appeared = true
            }
        }
    }
}

// MARK: - Data Models

private enum IconType {
    case system(String)
    case custom(AnyView)
}

private struct DocItem: Identifiable {
    let id = UUID()
    let icon: IconType
    let color: Color
    let name: String
    let description: String
    let details: [String]
}

// MARK: - Section View

private struct DocSectionView: View {
    let title: String
    let items: [DocItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            ForEach(items) { item in
                DocCardView(item: item)
            }
        }
    }
}

// MARK: - Component Card

private struct DocCardView: View {
    let item: DocItem

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Icon
            Group {
                switch item.icon {
                case .system(let name):
                    Image(systemName: name)
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                case .custom(let view):
                    view
                }
            }
            .frame(width: 40, height: 40)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(item.color)
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(item.name)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(item.description)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 3) {
                    ForEach(item.details, id: \.self) { detail in
                        HStack(alignment: .top, spacing: 6) {
                            Text("·")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(item.color.opacity(0.7))
                            Text(detail)
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 0)
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
    }
}

// MARK: - Concept Card

private struct ConceptCardView: View {
    let term: String
    let icon: String
    let color: Color
    let explanation: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(color.opacity(0.1))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(term)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(explanation)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Mini Icons (matching sidebar style)

private struct NeuronMiniIcon: View {
    var body: some View {
        Text("N")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
    }
}

private struct NumberMiniIcon: View {
    var body: some View {
        Text("1.0")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
    }
}
