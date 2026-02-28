import SwiftUI

struct WeightPopoverView: View {
    @ObservedObject var viewModel: CanvasViewModel
    let connection: ConnectionViewModel
    @State private var editingValue: String = ""
    @State private var sliderValue: Double = 0.0
    @State private var gradientExpanded = false
    @FocusState private var fieldFocused: Bool

    private var isInference: Bool { viewModel.canvasMode == .inference }

    /// Always read live from the viewModel array — never stale
    private var liveConn: ConnectionViewModel {
        viewModel.connections.first(where: { $0.id == connection.id }) ?? connection
    }

    private var sourceNode: NodeViewModel? {
        viewModel.nodes.first(where: { $0.id == connection.sourceNodeId })
    }

    private var targetNode: NodeViewModel? {
        viewModel.nodes.first(where: { $0.id == connection.targetNodeId })
    }

    var body: some View {
        let conn = liveConn
        VStack(alignment: .leading, spacing: 12) {

            // Header
            HStack {
                Text("Weight")
                    .font(.headline)
                Spacer()
                if !isInference {
                    Button(role: .destructive) {
                        viewModel.clearGlow()
                        viewModel.selectedConnectionId = nil
                        viewModel.deleteConnection(id: connection.id)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    viewModel.clearGlow()
                    viewModel.selectedConnectionId = nil
                    viewModel.connectionTapGlobalLocation = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Value (editable)
            HStack {
                Text("Value")
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("0.0", text: $editingValue)
                    .keyboardType(.decimalPad)
                    .font(.caption.monospaced())
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                    .focused($fieldFocused)
                    .onChange(of: editingValue) { _, v in
                        if let d = Double(v) {
                            viewModel.updateConnectionValue(id: connection.id, value: d)
                            if isInference {
                                sliderValue = d
                                viewModel.runAutoPredict()
                            }
                        }
                    }
                    .onChange(of: conn.value) { _, newVal in
                        if !fieldFocused {
                            editingValue = String(format: "%.4f", newVal)
                        }
                        if isInference { sliderValue = newVal }
                    }
                    .onAppear {
                        editingValue = String(format: "%.4f", conn.value)
                        sliderValue = conn.value
                    }
            }

            if isInference {
                HStack(spacing: 8) {
                    Text(String(format: "%.2f", sliderValue))
                        .font(.caption.monospaced())
                        .frame(width: 44)
                    Slider(value: $sliderValue, in: -3...3, step: 0.01)
                        .tint(.orange)
                        .onChange(of: sliderValue) { _, newVal in
                            editingValue = String(format: "%.4f", newVal)
                            viewModel.updateConnectionValue(id: connection.id, value: newVal)
                            viewModel.runAutoPredict()
                        }
                }
            }

            if !isInference {
                if viewModel.inspectMode && viewModel.stepPhase != .forward {
                    inspectSection(conn: conn)

                    HStack(spacing: 4) {
                        Image(systemName: "hand.tap")
                            .font(.system(size: 9))
                        Text("Tap boxed values to highlight their source on canvas")
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(.tertiary)
                } else if !viewModel.inspectMode {
                    HStack {
                        Text("Gradient")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(compactFmt(conn.gradient))
                            .fontDesign(.monospaced)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .frame(width: 260)
    }

    // MARK: - Inspect Mode Section

    @ViewBuilder
    private func inspectSection(conn: ConnectionViewModel) -> some View {
        let lr = viewModel.learningRate
        let grad = conn.gradient
        let wOld = conn.value
        let delta = -lr * grad

        Divider()

        VStack(alignment: .leading, spacing: 6) {
            Text("Weight Update")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Formula notation
            HStack(spacing: 0) {
                Text("w")
                    .font(.system(size: 10, design: .monospaced))
                Text("new")
                    .font(.system(size: 7, design: .monospaced))
                    .baselineOffset(-3)
                Text(" = w")
                    .font(.system(size: 10, design: .monospaced))
                Text("old")
                    .font(.system(size: 7, design: .monospaced))
                    .baselineOffset(-3)
                Text(" \u{2212} lr \u{00D7} \u{2202}L/\u{2202}w")
                    .font(.system(size: 10, design: .monospaced))
            }
            .foregroundStyle(.tertiary)

            // Concept boxes — wrapping
            WrappingHStack(spacing: 4) {
                ConceptBoxView(value: compactFmt(wOld + delta), label: "w\u{2099}", tint: .orange)
                ConceptOperator(symbol: "=")
                ConceptBoxView(value: compactFmt(wOld), label: "w", tint: .orange)
                ConceptOperator(symbol: "\u{2212}")
                ConceptBoxView(value: compactFmt(lr), label: "lr", tint: .gray)
                ConceptOperator(symbol: "\u{00D7}")
                ConceptBoxView(value: compactFmt(grad), label: "\u{2202}L/\u{2202}w", tint: targetNodeColor) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        gradientExpanded.toggle()
                    }
                }
                .overlay(alignment: .topTrailing) {
                    Image(systemName: gradientExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundStyle(.secondary)
                        .offset(x: -3, y: 2)
                }
            }
        }

        // Gradient Breakdown (expandable)
        if gradientExpanded {
            WeightGradientBreakdownView(viewModel: viewModel, conn: conn, targetNode: targetNode, sourceNode: sourceNode)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - Helpers

    private var targetNodeColor: Color {
        guard let t = targetNode else { return .orange }
        switch t.type {
        case .neuron:        return .orange
        case .dataset:       return .blue
        case .loss:          return .red
        case .visualization: return .purple
        case .outputDisplay: return .green
        case .number:        return .teal
        case .annotation:    return .gray
        case .scatterPlot:   return .teal
        }
    }
}

// MARK: - Gradient Breakdown (separate struct)

struct WeightGradientBreakdownView: View {
    @ObservedObject var viewModel: CanvasViewModel
    let conn: ConnectionViewModel
    let targetNode: NodeViewModel?
    let sourceNode: NodeViewModel?

    private var delta: Double? {
        guard let tgtGrad = viewModel.nodeGradients[conn.targetNodeId],
              let tgtOutput = viewModel.nodeOutputs[conn.targetNodeId] else { return nil }
        let fp = (targetNode?.activation ?? .relu).backward(tgtOutput)
        return fp * tgtGrad
    }

    var body: some View {
        Divider()

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 0) {
                Text("\u{2202}L/\u{2202}w = \u{03B4}")
                    .font(.system(size: 10, design: .monospaced))
                Text("tgt")
                    .font(.system(size: 7, design: .monospaced))
                    .baselineOffset(-3)
                Text(" \u{00D7} out")
                    .font(.system(size: 10, design: .monospaced))
                Text("src")
                    .font(.system(size: 7, design: .monospaced))
                    .baselineOffset(-3)
            }
            .foregroundStyle(.tertiary)

            if let d = delta, let sv = viewModel.nodeOutputs[conn.sourceNodeId] {
                WrappingHStack(spacing: 4) {
                    ConceptBoxView(value: compactFmt(conn.gradient), label: "\u{2202}L/\u{2202}w", tint: targetColor)
                    ConceptOperator(symbol: "=")
                    ConceptBoxView(value: compactFmt(d), label: "\u{03B4}", tint: targetColor) {
                        if let tId = targetNode?.id {
                            viewModel.toggleGlow(nodeIds: [tId])
                        }
                    }
                    ConceptOperator(symbol: "\u{00D7}")
                    ConceptBoxView(value: compactFmt(sv), label: "out", tint: sourceColor) {
                        if let sId = sourceNode?.id {
                            viewModel.toggleGlow(nodeIds: [sId])
                        }
                    }
                }
            } else {
                Text("\u{2202}L/\u{2202}w = \(compactFmt(conn.gradient))")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var targetColor: Color {
        guard let t = targetNode else { return .orange }
        switch t.type {
        case .neuron: return .orange
        case .loss:   return .red
        default:      return .orange
        }
    }

    private var sourceColor: Color {
        guard let s = sourceNode else { return .orange }
        switch s.type {
        case .neuron:  return .orange
        case .dataset: return .blue
        default:       return .orange
        }
    }
}

// MARK: - Smart number formatting (shared)

/// Compact formatter: trims trailing zeros, caps at 4 decimal places.
/// Clips to ±9999 to prevent display overflow.
func compactFmt(_ v: Double) -> String {
    if v == 0 { return "0" }
    if v.isNaN { return "NaN" }
    if v.isInfinite { return v > 0 ? "∞" : "-∞" }
    if v > 9999 { return ">9999" }
    if v < -9999 { return "<-9999" }
    let s = String(format: "%.4f", v)
    var trimmed = s
    if trimmed.contains(".") {
        while trimmed.hasSuffix("0") { trimmed.removeLast() }
        if trimmed.hasSuffix(".") { trimmed.removeLast() }
    }
    return trimmed
}

/// Format a Double for display, clipped to ±9999.
func clippedFmt(_ v: Double, decimals: Int = 4) -> String {
    if v.isNaN { return "NaN" }
    if v.isInfinite { return v > 0 ? "∞" : "-∞" }
    if v > 9999 { return ">9999" }
    if v < -9999 { return "<-9999" }
    return String(format: "%.\(decimals)f", v)
}
