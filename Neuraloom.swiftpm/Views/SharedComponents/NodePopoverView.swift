import SwiftUI

struct NodePopoverView: View {
    @ObservedObject var viewModel: CanvasViewModel
    let node: NodeViewModel

    /// Always read live from the viewModel array
    private var liveNode: NodeViewModel {
        viewModel.nodes.first(where: { $0.id == node.id }) ?? node
    }

    var body: some View {
        let n = liveNode
        VStack(alignment: .leading, spacing: 16) {

            // Header
            HStack {
                Text(node.type.rawValue)
                    .font(.headline)
                Spacer()
                Button(role: .destructive) {
                    viewModel.clearGlow()
                    viewModel.selectedNodeId = nil
                    viewModel.deleteNode(id: node.id)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Loss node info
            if n.type == .loss {
                lossSection
            }

            // Inspect mode: computation breakdown (only when training data exists)
            if viewModel.inspectMode && n.type == .neuron && !viewModel.nodeOutputs.isEmpty {
                inspectSection(n: n)
            }

            // Neuron-only controls
            if n.type == .neuron {
                if viewModel.inspectMode {
                    neuronBadges(n: n)
                } else {
                    neuronControls(n: n)
                }
            }

            // Hint — shown once in inspect mode when computation data exists
            if viewModel.inspectMode && !viewModel.nodeOutputs.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "hand.tap")
                        .font(.system(size: 9))
                    Text("Tap boxed values to highlight their source on canvas")
                        .font(.system(size: 9))
                }
                .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .frame(width: 300)
    }

    // MARK: - Loss Section

    @ViewBuilder
    private var lossSection: some View {
        if viewModel.inspectMode {
            // Inspect mode: badge + unified loss display
            HStack(spacing: 6) {
                badge(viewModel.selectedLossFunction == .mse ? "MSE" : "Cross-Entropy", color: .red)
            }

            if let loss = viewModel.currentLoss {
                HStack {
                    Text("Current Loss (L)")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.6f", loss))
                        .font(.caption.monospaced().bold())
                }

                if let config = node.lossConfig {
                    lossComputation(config: config, loss: loss)
                }
            }
        } else {
            // Dev mode: picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Loss Function")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Picker("Loss", selection: $viewModel.selectedLossFunction) {
                    Text("MSE").tag(LossFunction.mse)
                    Text("Cross-Entropy").tag(LossFunction.crossEntropy)
                }
                .pickerStyle(.segmented)
            }

            if let loss = viewModel.currentLoss {
                Divider()
                HStack {
                    Text("Current Loss")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.6f", loss))
                        .font(.caption.monospaced().bold())
                }
            }
        }
    }

    // MARK: - Loss Computation (delegated to separate struct)

    @ViewBuilder
    private func lossComputation(config: LossNodeConfig, loss: Double) -> some View {
        LossComputationView(viewModel: viewModel, config: config, loss: loss)
    }

    // MARK: - Inspect Section

    @ViewBuilder
    private func inspectSection(n: NodeViewModel) -> some View {
        if let output = viewModel.nodeOutputs[node.id] {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Output")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.6f", output))
                        .font(.caption.monospaced().bold())
                }

                // Forward computation formula for hidden/output nodes
                if n.role != .input && n.role != .bias {
                    forwardFormula(n: n, output: output)
                }
            }

            // Error Signal (δ) section — only after backward pass
            if n.role != .bias && viewModel.stepPhase != .forward {
                DeltaSectionView(viewModel: viewModel, node: node, n: n, output: output)
            }

            Divider()
        } else if n.role == .bias {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Output")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("1 (constant)")
                        .font(.caption.monospaced().bold())
                }
            }
            Divider()
        }
    }

    // MARK: - Forward Formula

    @ViewBuilder
    private func forwardFormula(n: NodeViewModel, output: Double) -> some View {
        let incoming = viewModel.connections.filter { $0.targetNodeId == node.id }
        if !incoming.isEmpty {
            ForwardFormulaView(
                viewModel: viewModel,
                incoming: incoming,
                activation: n.activation,
                output: output
            )
        }
    }

    // Delta section is extracted to DeltaSectionView (below) to reduce type-checker complexity

    // MARK: - Neuron Badges (Inspect Mode)

    @ViewBuilder
    private func neuronBadges(n: NodeViewModel) -> some View {
        HStack(spacing: 6) {
            if n.role != .bias {
                badge(activationName(n.activation), color: .orange)
            }
            badge(roleName(n.role), color: roleColor(n.role))
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }

    // MARK: - Neuron Controls (Dev Mode)

    @ViewBuilder
    private func neuronControls(n: NodeViewModel) -> some View {
        // Activation (hidden for bias)
        if n.role != .bias {
            VStack(alignment: .leading, spacing: 8) {
                Text("Activation")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Picker("Activation", selection: Binding(
                    get: { n.activation },
                    set: { viewModel.updateActivation(id: node.id, activation: $0) }
                )) {
                    Text("ReLU").tag(ActivationType.relu)
                    Text("Sigmoid").tag(ActivationType.sigmoid)
                    Text("Linear").tag(ActivationType.linear)
                }
                .pickerStyle(.segmented)
            }

            Divider()
        }

        // Role
        VStack(alignment: .leading, spacing: 8) {
            Text("Role")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Toggle(isOn: Binding(
                    get: { n.role == .input },
                    set: { _ in viewModel.setRole(.input, for: node.id) }
                )) {
                    Label("In", systemImage: "arrow.right.circle")
                }
                .toggleStyle(.button)

                Toggle(isOn: Binding(
                    get: { n.role == .output },
                    set: { _ in viewModel.setRole(.output, for: node.id) }
                )) {
                    Label("Out", systemImage: "arrow.left.circle")
                }
                .toggleStyle(.button)

                Toggle(isOn: Binding(
                    get: { n.role == .bias },
                    set: { _ in viewModel.setRole(.bias, for: node.id) }
                )) {
                    Label("Bias", systemImage: "plusminus.circle")
                }
                .toggleStyle(.button)
            }
        }
    }

    // MARK: - Helpers

    private func fmt(_ v: Double) -> String {
        compactFmt(v)
    }

    private func activationName(_ act: ActivationType) -> String {
        switch act {
        case .relu:    return "relu"
        case .sigmoid: return "sigmoid"
        case .linear:  return "linear"
        }
    }

    private func roleName(_ role: NodeRole) -> String {
        switch role {
        case .input:  return "Input"
        case .output: return "Output"
        case .hidden: return "Hidden"
        case .bias:   return "Bias"
        }
    }

    private func roleColor(_ role: NodeRole) -> Color {
        switch role {
        case .input:  return .green
        case .output: return .blue
        case .hidden: return .orange
        case .bias:   return .purple
        }
    }

}

// MARK: - Forward Formula (wrapping flow layout)

struct ForwardFormulaView: View {
    @ObservedObject var viewModel: CanvasViewModel
    let incoming: [ConnectionViewModel]
    let activation: ActivationType
    let output: Double

    private var activationLabel: String {
        switch activation {
        case .relu: return "relu"
        case .sigmoid: return "sigmoid"
        case .linear: return "linear"
        }
    }

    var body: some View {
        WrappingHStack(spacing: 5) {
            Text("\(activationLabel)(")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.orange)

            ForEach(Array(incoming.enumerated()), id: \.element.id) { idx, conn in
                if idx > 0 {
                    ConceptOperator(symbol: "+")
                }
                ForwardTermBox(viewModel: viewModel, conn: conn)
            }

            Text(") = \(compactFmt(output))")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.orange)
        }
    }
}

/// A single [w×in] grouped box — tapping glows the source node + the connection
struct ForwardTermBox: View {
    @ObservedObject var viewModel: CanvasViewModel
    let conn: ConnectionViewModel

    private var srcVal: Double { viewModel.nodeOutputs[conn.sourceNodeId] ?? 0 }

    private var sourceColor: Color {
        guard let n = viewModel.nodes.first(where: { $0.id == conn.sourceNodeId }) else { return .orange }
        switch n.type {
        case .neuron:        return .orange
        case .dataset:       return .blue
        case .loss:          return .red
        case .visualization: return .purple
        case .annotation:    return .gray
        }
    }

    var body: some View {
        Button {
            viewModel.toggleGlow(nodeIds: [conn.sourceNodeId], connectionIds: [conn.id])
        } label: {
            HStack(spacing: 3) {
                termColumn(value: conn.value, label: "w", tint: .orange)
                Text("\u{00D7}")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                termColumn(value: srcVal, label: "in", tint: sourceColor)
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.orange.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func termColumn(value: Double, label: String, tint: Color) -> some View {
        VStack(spacing: 0) {
            Text(compactFmt(value))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 7, weight: .medium))
                .foregroundStyle(tint.opacity(0.7))
        }
    }
}

/// A simple wrapping horizontal layout — lays out children horizontally, wrapping to next line when needed.
struct WrappingHStack: Layout {
    var spacing: CGFloat = 5

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var height: CGFloat = 0
        var maxWidth: CGFloat = 0
        for (ri, row) in rows.enumerated() {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            height += rowHeight + (ri > 0 ? spacing : 0)
            let rowWidth = row.enumerated().reduce(CGFloat(0)) { acc, item in
                acc + item.element.sizeThatFits(.unspecified).width + (item.offset > 0 ? spacing : 0)
            }
            maxWidth = max(maxWidth, rowWidth)
        }
        return CGSize(width: proposal.width ?? maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: ProposedViewSize(width: bounds.width, height: nil), subviews: subviews)
        var y = bounds.minY
        for row in rows {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            var x = bounds.minX
            for view in row {
                let size = view.sizeThatFits(.unspecified)
                view.place(at: CGPoint(x: x, y: y + (rowHeight - size.height) / 2), proposal: .unspecified)
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubviews.Element]] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[LayoutSubviews.Element]] = [[]]
        var currentWidth: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            let gap = rows.last!.isEmpty ? 0 : spacing
            if currentWidth + gap + size.width > maxWidth && !rows.last!.isEmpty {
                rows.append([view])
                currentWidth = size.width
            } else {
                rows[rows.count - 1].append(view)
                currentWidth += gap + size.width
            }
        }
        return rows
    }
}

// MARK: - Loss Computation (separate struct to reduce type-check complexity)

struct LossComputationView: View {
    @ObservedObject var viewModel: CanvasViewModel
    let config: LossNodeConfig
    let loss: Double

    private var predConn: ConnectionViewModel? {
        viewModel.connections.first(where: { $0.targetNodeId == config.predPortId })
    }

    private var trueConn: ConnectionViewModel? {
        viewModel.connections.first(where: { $0.targetNodeId == config.truePortId })
    }

    private var resolved: (yHat: Double, target: Double, predId: UUID)? {
        guard let pc = predConn,
              let yh = viewModel.nodeOutputs[pc.sourceNodeId] else { return nil }
        let nOut = max(1.0, Double(viewModel.nodes.filter(\.isOutput).count))
        let grad = viewModel.nodeGradients[pc.sourceNodeId] ?? 0

        let target: Double
        switch viewModel.selectedLossFunction {
        case .mse:
            target = yh - nOut * grad / 2.0
        case .crossEntropy:
            let p = max(1e-7, min(1.0 - 1e-7, yh))
            target = p - grad * p * (1.0 - p)
        }
        return (yh, target, pc.sourceNodeId)
    }

    var body: some View {
        if let vals = resolved {
            VStack(alignment: .leading, spacing: 6) {
                if viewModel.selectedLossFunction == .mse {
                    Text("L = (\u{0177} \u{2212} y)\u{00B2} / n")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                } else {
                    Text("L = \u{2212}[y\u{00B7}ln(\u{0177}) + (1\u{2212}y)\u{00B7}ln(1\u{2212}\u{0177})]")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ConceptBoxView(value: fmt(loss), label: "L", tint: .red)
                        ConceptOperator(symbol: "=")
                        ConceptBoxView(value: fmt(vals.yHat), label: "\u{0177}", tint: .orange) {
                            var connIds: Set<UUID> = []
                            if let pc = predConn { connIds.insert(pc.id) }
                            viewModel.toggleGlow(nodeIds: [vals.predId], connectionIds: connIds)
                        }
                        ConceptOperator(symbol: "\u{2212}")
                        ConceptBoxView(value: fmt(vals.target), label: "y", tint: .blue) {
                            let dsNodes = viewModel.nodes.filter { $0.type == .dataset }
                            var connIds: Set<UUID> = []
                            if let tc = trueConn { connIds.insert(tc.id) }
                            viewModel.toggleGlow(nodeIds: Set(dsNodes.map(\.id)), connectionIds: connIds)
                        }
                    }
                }
            }
        }
    }

    private func fmt(_ v: Double) -> String {
        compactFmt(v)
    }
}

// MARK: - Delta Section (separate struct to reduce type-check complexity)

struct DeltaSectionView: View {
    @ObservedObject var viewModel: CanvasViewModel
    let node: NodeViewModel
    let n: NodeViewModel
    let output: Double

    @State private var dLdaExpanded = false
    @State private var fPrimeExpanded = false

    private var dLda: Double? { viewModel.nodeGradients[node.id] }
    private var fPrimeVal: Double { n.activation.backward(output) }
    private var deltaVal: Double? { dLda.map { $0 * fPrimeVal } }

    var body: some View {
        Divider()

        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("\u{03B4}")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if let d = deltaVal {
                    Text(String(format: "%.6f", d))
                        .font(.caption.monospaced().bold())
                }
            }

            Text("\u{03B4} = \u{2202}L/\u{2202}a \u{00D7} f\u{2032}(net)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)

            if let g = dLda {
                conceptRow(g: g)
            }

            // Expanded: ∂L/∂a derivation
            if dLdaExpanded, let g = dLda {
                DLdaBreakdownView(viewModel: viewModel, node: node, n: n, output: output, dLda: g)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Expanded: f'(net) derivation
            if fPrimeExpanded {
                FPrimeBreakdownView(viewModel: viewModel, nodeId: node.id, activation: n.activation, output: output, fPrimeVal: fPrimeVal)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder
    private func conceptRow(g: Double) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if let d = deltaVal {
                    ConceptBoxView(value: fmt(d), label: "\u{03B4}", tint: .orange) {
                        viewModel.toggleGlow(nodeIds: [node.id])
                    }
                    ConceptOperator(symbol: "=")
                }

                // ∂L/∂a — expandable
                dLdaConceptBox(g: g)

                ConceptOperator(symbol: "\u{00D7}")

                // f'(net) — expandable
                ConceptBoxView(value: fmt(fPrimeVal), label: "f\u{2032}(net)", tint: .orange) {
                    viewModel.toggleGlow(nodeIds: [node.id])
                    withAnimation(.easeInOut(duration: 0.25)) { fPrimeExpanded.toggle() }
                }
                .overlay(alignment: .topTrailing) {
                    Image(systemName: fPrimeExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.secondary)
                        .offset(x: -4, y: 3)
                }
            }
        }
    }

    @ViewBuilder
    private func dLdaConceptBox(g: Double) -> some View {
        let tint: Color = n.role == .output ? .red : downstreamColor
        ConceptBoxView(value: fmt(g), label: "\u{2202}L/\u{2202}a", tint: tint) {
            if n.role == .output {
                let lossNodes = viewModel.nodes.filter { $0.type == .loss }
                let outgoing = viewModel.connections.filter { $0.sourceNodeId == node.id }
                viewModel.toggleGlow(nodeIds: Set(lossNodes.map(\.id)), connectionIds: Set(outgoing.map(\.id)))
            } else {
                let outgoing = viewModel.connections.filter { $0.sourceNodeId == node.id }
                viewModel.toggleGlow(nodeIds: Set(outgoing.map(\.targetNodeId)), connectionIds: Set(outgoing.map(\.id)))
            }
            withAnimation(.easeInOut(duration: 0.25)) { dLdaExpanded.toggle() }
        }
        .overlay(alignment: .topTrailing) {
            Image(systemName: dLdaExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(.secondary)
                .offset(x: -4, y: 3)
        }
    }

    private var downstreamColor: Color {
        let outgoing = viewModel.connections.filter { $0.sourceNodeId == node.id }
        if let firstDown = outgoing.first?.targetNodeId,
           let dn = viewModel.nodes.first(where: { $0.id == firstDown }) {
            return nodeColor(for: dn)
        }
        return .orange
    }

    private func nodeColor(for node: NodeViewModel) -> Color {
        switch node.type {
        case .neuron:        return .orange
        case .dataset:       return .blue
        case .loss:          return .red
        case .visualization: return .purple
        case .annotation:    return .gray
        }
    }

    private func fmt(_ v: Double) -> String {
        compactFmt(v)
    }
}

// MARK: - ∂L/∂a Breakdown (separate struct)

struct DLdaBreakdownView: View {
    @ObservedObject var viewModel: CanvasViewModel
    let node: NodeViewModel
    let n: NodeViewModel
    let output: Double
    let dLda: Double

    var body: some View {
        Divider()

        VStack(alignment: .leading, spacing: 6) {
            if n.role == .output {
                outputBreakdown
            } else {
                hiddenBreakdown
            }
        }
    }

    @ViewBuilder
    private var outputBreakdown: some View {
        let lf = viewModel.selectedLossFunction
        let nOutputs = Double(viewModel.nodes.filter(\.isOutput).count)

        switch lf {
        case .mse:
            let target = output - nOutputs * dLda / 2.0
            Text("\u{2202}L/\u{2202}a = 2(\u{0177} \u{2212} y) / n")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ConceptBoxView(value: fmt(dLda), label: "\u{2202}L/\u{2202}a", tint: .red) {
                        let lossNodes = viewModel.nodes.filter { $0.type == .loss }
                        viewModel.toggleGlow(nodeIds: Set(lossNodes.map(\.id)))
                    }
                    ConceptOperator(symbol: "=")
                    ConceptBoxView(value: "2", label: "", tint: .gray)
                    ConceptOperator(symbol: "\u{00D7}")
                    ConceptBoxView(value: fmt(output), label: "\u{0177}", tint: .orange) {
                        viewModel.toggleGlow(nodeIds: [node.id])
                    }
                    ConceptOperator(symbol: "\u{2212}")
                    ConceptBoxView(value: fmt(target), label: "y", tint: .blue) {
                        let dsNodes = viewModel.nodes.filter { $0.type == .dataset }
                        viewModel.toggleGlow(nodeIds: Set(dsNodes.map(\.id)))
                    }
                    ConceptOperator(symbol: "\u{00F7}")
                    ConceptBoxView(value: String(format: "%.0f", nOutputs), label: "n", tint: .gray)
                }
            }

        case .crossEntropy:
            let pClamped = max(1e-7, min(1.0 - 1e-7, output))
            let target = pClamped - dLda * pClamped * (1.0 - pClamped)

            Text("\u{2202}L/\u{2202}a = (\u{0177} \u{2212} y) / (\u{0177}(1 \u{2212} \u{0177}))")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ConceptBoxView(value: fmt(dLda), label: "\u{2202}L/\u{2202}a", tint: .red) {
                        let lossNodes = viewModel.nodes.filter { $0.type == .loss }
                        viewModel.toggleGlow(nodeIds: Set(lossNodes.map(\.id)))
                    }
                    ConceptOperator(symbol: "=")
                    ConceptBoxView(value: fmt(output - target), label: "\u{0177}\u{2212}y", tint: .orange)
                    ConceptOperator(symbol: "\u{00F7}")
                    ConceptBoxView(
                        value: fmt(pClamped * (1.0 - pClamped)),
                        label: "\u{0177}(1\u{2212}\u{0177})",
                        tint: .orange
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var hiddenBreakdown: some View {
        HStack(spacing: 0) {
            Text("\u{2202}L/\u{2202}a = \u{03A3}(w")
                .font(.system(size: 11, design: .monospaced))
            Text("k")
                .font(.system(size: 8, design: .monospaced))
                .baselineOffset(-4)
            Text(" \u{00D7} \u{03B4}")
                .font(.system(size: 11, design: .monospaced))
            Text("k")
                .font(.system(size: 8, design: .monospaced))
                .baselineOffset(-4)
            Text(")")
                .font(.system(size: 11, design: .monospaced))
        }
        .foregroundStyle(.secondary)

        let outgoing = viewModel.connections.filter { $0.sourceNodeId == node.id }
        ForEach(outgoing) { conn in
            HiddenTermRow(viewModel: viewModel, conn: conn)
        }

        Text(String(format: "\u{03A3} = %@", fmt(dLda)))
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(.orange)
    }

    private func fmt(_ v: Double) -> String {
        compactFmt(v)
    }
}

// MARK: - Hidden node ∂L/∂a term row

struct HiddenTermRow: View {
    @ObservedObject var viewModel: CanvasViewModel
    let conn: ConnectionViewModel

    var body: some View {
        let tgtNode = viewModel.nodes.first(where: { $0.id == conn.targetNodeId })
        let tgtOutput = viewModel.nodeOutputs[conn.targetNodeId]
        let tgtGrad = viewModel.nodeGradients[conn.targetNodeId]
        let tgtFPrime = tgtOutput.map { (tgtNode?.activation ?? .relu).backward($0) }
        let tgtDelta: Double? = {
            guard let g = tgtGrad, let fp = tgtFPrime else { return nil }
            return g * fp
        }()

        if let delta = tgtDelta {
            Text(String(format: "%@ \u{00D7} %@ = %@",
                        fmt(conn.value), fmt(delta), fmt(conn.value * delta)))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func fmt(_ v: Double) -> String {
        compactFmt(v)
    }
}

// MARK: - f'(net) Breakdown (separate struct)

struct FPrimeBreakdownView: View {
    @ObservedObject var viewModel: CanvasViewModel
    let nodeId: UUID
    let activation: ActivationType
    let output: Double
    let fPrimeVal: Double

    var body: some View {
        Divider()

        VStack(alignment: .leading, spacing: 6) {
            activationBadge

            switch activation {
            case .sigmoid:
                sigmoidBreakdown
            case .relu:
                reluBreakdown
            case .linear:
                Text("f\u{2032}(net) = 1")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var activationBadge: some View {
        let name: String = switch activation {
        case .relu: "relu"
        case .sigmoid: "sigmoid"
        case .linear: "linear"
        }
        return Text(name)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.orange.opacity(0.12), in: Capsule())
    }

    @ViewBuilder
    private var sigmoidBreakdown: some View {
        Text("f\u{2032}(net) = out \u{00D7} (1 \u{2212} out)")
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.secondary)

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ConceptBoxView(value: fmt(fPrimeVal), label: "f\u{2032}(net)", tint: .orange)
                ConceptOperator(symbol: "=")
                ConceptBoxView(value: fmt(output), label: "out", tint: .orange) {
                    viewModel.toggleGlow(nodeIds: [nodeId])
                }
                ConceptOperator(symbol: "\u{00D7}")
                ConceptBoxView(value: fmt(1.0 - output), label: "1\u{2212}out", tint: .orange)
            }
        }
    }

    @ViewBuilder
    private var reluBreakdown: some View {
        Text("f\u{2032}(net) = out > 0 ? 1 : 0")
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.secondary)

        Text(String(format: "out = %@ \u{2192} f\u{2032} = %@",
                    fmt(output), output > 0 ? "1" : "0"))
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(.orange)
    }

    private func fmt(_ v: Double) -> String {
        compactFmt(v)
    }
}
