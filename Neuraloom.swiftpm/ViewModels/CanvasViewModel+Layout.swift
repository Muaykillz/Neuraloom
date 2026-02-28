import SwiftUI

extension CanvasViewModel {

    // MARK: - Fit to Screen

    func fitToScreen(in size: CGSize, insets: EdgeInsets) {
        let fitNodes = visibleNodes
        guard !fitNodes.isEmpty else { scale = 1.0; offset = .zero; return }
        let minX = fitNodes.map { $0.position.x }.min() ?? 0
        let maxX = fitNodes.map { $0.position.x }.max() ?? 0
        let minY = fitNodes.map { $0.position.y }.min() ?? 0
        let maxY = fitNodes.map { $0.position.y }.max() ?? 0
        let contentWidth = maxX - minX + 150
        let contentHeight = maxY - minY + 150
        let contentCenter = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        let availableWidth = size.width
        let availableHeight = size.height - insets.top - insets.bottom
        let scaleX = availableWidth / contentWidth
        let scaleY = availableHeight / contentHeight
        let newScale = min(min(scaleX, scaleY) * 0.8, 1.0)
        let clampedScale = max(newScale, 0.5)
        let screenCenter = CGPoint(
            x: insets.leading + size.width / 2,
            y: insets.top + availableHeight / 2
        )
        let newOffset = CGSize(
            width: screenCenter.x - (contentCenter.x * clampedScale),
            height: screenCenter.y - (contentCenter.y * clampedScale)
        )
        withAnimation(.spring()) { scale = clampedScale; offset = newOffset }
    }

    /// Zoom and center the viewport on a specific node.
    /// `verticalBias` shifts the node away from center: positive = push node toward bottom of screen.
    func zoomToNode(id: UUID, zoomScale: CGFloat = 1.5, verticalBias: CGFloat = 0) {
        guard let node = nodes.first(where: { $0.id == id }) else { return }
        let size = viewportSize
        guard size.width > 0 else { return }
        let availableHeight = size.height - viewportInsets.top - viewportInsets.bottom
        let screenCenter = CGPoint(
            x: viewportInsets.leading + size.width / 2,
            y: viewportInsets.top + availableHeight / 2 + verticalBias
        )
        let newOffset = CGSize(
            width: screenCenter.x - (node.position.x * zoomScale),
            height: screenCenter.y - (node.position.y * zoomScale)
        )
        withAnimation(.spring()) { scale = zoomScale; offset = newOffset }
    }

    /// Fit to screen using the stored viewport size.
    func fitToScreenStored() {
        guard viewportSize.width > 0 else { return }
        fitToScreen(in: viewportSize, insets: viewportInsets)
    }

    // MARK: - Auto Layout

    func autoLayout() {
        let hSpacing: CGFloat = 250
        let vSpacing: CGFloat = 200
        let startX: CGFloat = 100

        let regularNeurons = nodes.filter { $0.type == .neuron && !$0.isBias }
        let regularNeuronIds = Set(regularNeurons.map { $0.id })
        let neuronConns = connections.filter { regularNeuronIds.contains($0.sourceNodeId) && regularNeuronIds.contains($0.targetNodeId) }

        var nodeDepths: [UUID: Int] = [:]
        let inputs = regularNeurons.filter { n in n.isInput || !neuronConns.contains(where: { $0.targetNodeId == n.id }) }
        for input in inputs { nodeDepths[input.id] = 0 }

        var changed = true
        while changed {
            changed = false
            for conn in neuronConns {
                if let sourceDepth = nodeDepths[conn.sourceNodeId] {
                    let targetDepth = nodeDepths[conn.targetNodeId]
                    if targetDepth == nil || targetDepth! <= sourceDepth {
                        nodeDepths[conn.targetNodeId] = sourceDepth + 1
                        changed = true
                    }
                }
            }
        }

        let maxDepth = nodeDepths.values.max() ?? 0
        var layers: [[NodeViewModel]] = Array(repeating: [], count: maxDepth + 1)
        for node in regularNeurons {
            if let depth = nodeDepths[node.id], depth <= maxDepth {
                layers[depth].append(node)
            }
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            let networkCenterY = layers.isEmpty ? 300 : layers.flatMap { $0.map(\.position.y) }.reduce(0, +) / CGFloat(regularNeurons.count)

            for (layerIndex, layerNodes) in layers.enumerated() {
                let layerHeight = CGFloat(layerNodes.count - 1) * vSpacing
                let startY = networkCenterY - layerHeight / 2
                for (nodeIndex, node) in layerNodes.enumerated() {
                    if let index = nodes.firstIndex(where: { $0.id == node.id }) {
                        nodes[index].position = CGPoint(
                            x: startX + CGFloat(layerIndex) * hSpacing,
                            y: startY + CGFloat(nodeIndex) * vSpacing
                        )
                    }
                }
            }

            let biasNodes = nodes.filter { $0.isBias }
            for biasNode in biasNodes {
                let targetIds = connections.filter { $0.sourceNodeId == biasNode.id }.map(\.targetNodeId)
                let targetNodes = nodes.filter { targetIds.contains($0.id) }

                if !targetNodes.isEmpty {
                    let avgPos = targetNodes.reduce(CGPoint.zero) { acc, node in
                        let nodePosition = nodes.first(where: { $0.id == node.id })?.position ?? .zero
                        return CGPoint(x: acc.x + nodePosition.x, y: acc.y + nodePosition.y)
                    }
                    let finalAvgPos = CGPoint(x: avgPos.x / CGFloat(targetNodes.count), y: avgPos.y / CGFloat(targetNodes.count))

                    if let index = nodes.firstIndex(where: { $0.id == biasNode.id }) {
                        nodes[index].position = CGPoint(x: finalAvgPos.x - hSpacing, y: finalAvgPos.y + vSpacing)
                    }
                }
            }

            let networkLeftX = startX
            let networkRightX = startX + CGFloat(maxDepth) * hSpacing
            let pipelineGap: CGFloat = 250

            let datasetNodes = nodes.filter { $0.type == .dataset }
            if !datasetNodes.isEmpty {
                let dsX = networkLeftX - pipelineGap
                let totalH = CGFloat(datasetNodes.count - 1) * 150
                let dsStartY = networkCenterY - totalH / 2
                for (i, ds) in datasetNodes.enumerated() {
                    if let idx = nodes.firstIndex(where: { $0.id == ds.id }) {
                        nodes[idx].position = CGPoint(x: dsX, y: dsStartY + CGFloat(i) * 150)
                    }
                }
            }

            let lossNodes = nodes.filter { $0.type == .loss }
            if !lossNodes.isEmpty {
                let lossX = networkRightX + pipelineGap
                let totalH = CGFloat(lossNodes.count - 1) * 150
                let lossStartY = networkCenterY - totalH / 2
                for (i, ln) in lossNodes.enumerated() {
                    if let idx = nodes.firstIndex(where: { $0.id == ln.id }) {
                        nodes[idx].position = CGPoint(x: lossX, y: lossStartY + CGFloat(i) * 150)
                    }
                }
            }

            let vizNodes = nodes.filter { $0.type == .visualization }
            if !vizNodes.isEmpty {
                let vizAnchorX = lossNodes.isEmpty ? networkRightX : networkRightX + pipelineGap
                let vizX = vizAnchorX + pipelineGap
                let totalH = CGFloat(vizNodes.count - 1) * 150
                let vizStartY = networkCenterY - totalH / 2
                for (i, vn) in vizNodes.enumerated() {
                    if let idx = nodes.firstIndex(where: { $0.id == vn.id }) {
                        nodes[idx].position = CGPoint(x: vizX, y: vizStartY + CGFloat(i) * 150)
                    }
                }
            }
        }
    }
}
