import SwiftUI

extension CanvasViewModel {

    // MARK: - Drawable Connections

    var drawableConnections: [DrawableConnection] {
        let bbox = neuronBoundingBox
        return connections.compactMap { conn in
            let toPoint: CGPoint
            if let portPos = lossPortPosition(portId: conn.targetNodeId) {
                toPoint = portPos
            } else if let portPos = scatterPlotPortPosition(portId: conn.targetNodeId) {
                toPoint = portPos
            } else if let toNode = nodes.first(where: { $0.id == conn.targetNodeId }) {
                toPoint = inputEdge(of: toNode)
            } else {
                return nil
            }

            if let portPos = columnPortPosition(portId: conn.sourceNodeId) {
                let dy = computeDetourY(from: portPos, to: toPoint, bbox: bbox)
                return DrawableConnection(id: conn.id, from: portPos, to: toPoint, value: conn.value, isUtilityLink: true, detourY: dy)
            }

            guard let fromNode = nodes.first(where: { $0.id == conn.sourceNodeId }) else { return nil }
            let targetIsLossPort = lossPortPosition(portId: conn.targetNodeId) != nil
                || scatterPlotPortPosition(portId: conn.targetNodeId) != nil
            let targetNode = nodes.first(where: { $0.id == conn.targetNodeId })
            let isUtility = fromNode.type != .neuron || targetNode?.type != .neuron || targetIsLossPort
            let fromPt = outputEdge(of: fromNode)
            let dy = isUtility ? computeDetourY(from: fromPt, to: toPoint, bbox: bbox) : nil
            return DrawableConnection(id: conn.id, from: fromPt, to: toPoint, value: conn.value, isUtilityLink: isUtility, detourY: dy)
        }
    }

    var temporaryWiringLine: (from: CGPoint, to: CGPoint)? {
        guard let sourceId = activeWiringSource,
              let targetPos = wiringTargetPosition else { return nil }

        let fromPoint: CGPoint
        if let sourceNode = nodes.first(where: { $0.id == sourceId }) {
            fromPoint = outputEdge(of: sourceNode)
        } else if let portPos = columnPortPosition(portId: sourceId) {
            fromPoint = portPos
        } else {
            return nil
        }

        if let hoveredId = hoveredNodeId,
           let hoveredNode = nodes.first(where: { $0.id == hoveredId }) {
            if hoveredNode.type == .loss, let config = hoveredNode.lossConfig {
                let canvasPt = convertToCanvasSpace(targetPos)
                let portId = closestLossPort(config: config, nodePosition: hoveredNode.position, to: canvasPt)
                if let portPos = lossPortPosition(portId: portId) {
                    return (fromPoint, portPos)
                }
            }
            if hoveredNode.type == .scatterPlot, let config = hoveredNode.scatterPlotConfig {
                let canvasPt = convertToCanvasSpace(targetPos)
                let portId = closestScatterPort(config: config, nodePosition: hoveredNode.position, to: canvasPt)
                if let portPos = scatterPlotPortPosition(portId: portId) {
                    return (fromPoint, portPos)
                }
            }
            return (fromPoint, inputEdge(of: hoveredNode))
        }

        return (fromPoint, convertToCanvasSpace(targetPos))
    }

    // MARK: - Edge Positions

    func outputEdge(of node: NodeViewModel) -> CGPoint {
        let p = node.position
        switch node.type {
        case .neuron:        return CGPoint(x: p.x + 25, y: p.y)
        case .loss:          return CGPoint(x: p.x + 60, y: p.y)
        case .visualization: return CGPoint(x: p.x + 109, y: p.y)
        case .outputDisplay: return CGPoint(x: p.x + 70, y: p.y)
        case .number:        return CGPoint(x: p.x + 50, y: p.y)
        case .scatterPlot:   return CGPoint(x: p.x + 120, y: p.y)
        default:             return p
        }
    }

    func inputEdge(of node: NodeViewModel) -> CGPoint {
        let p = node.position
        switch node.type {
        case .neuron:        return p
        case .loss:          return CGPoint(x: p.x - 63, y: p.y)
        case .visualization: return CGPoint(x: p.x - 109, y: p.y)
        case .outputDisplay: return CGPoint(x: p.x - 70, y: p.y)
        case .number:        return CGPoint(x: p.x - 50, y: p.y)
        case .scatterPlot:   return CGPoint(x: p.x - 123, y: p.y)
        default:             return p
        }
    }

    // MARK: - Port Positions

    func lossPortPosition(portId: UUID) -> CGPoint? {
        for node in nodes where node.type == .loss {
            guard let config = node.lossConfig else { continue }
            if let pi = config.inputPortIds.firstIndex(of: portId) {
                let totalH = CGFloat(config.inputPortIds.count - 1) * DatasetNodeLayout.portSpacing
                let startY = node.position.y - totalH / 2
                return CGPoint(
                    x: node.position.x - 63,
                    y: startY + CGFloat(pi) * DatasetNodeLayout.portSpacing
                )
            }
        }
        return nil
    }

    func scatterPlotPortPosition(portId: UUID) -> CGPoint? {
        for node in nodes where node.type == .scatterPlot {
            guard let config = node.scatterPlotConfig else { continue }
            if let pi = config.inputPortIds.firstIndex(of: portId) {
                let totalH = CGFloat(config.inputPortIds.count - 1) * DatasetNodeLayout.portSpacing
                let startY = node.position.y - totalH / 2
                return CGPoint(
                    x: node.position.x - 123,
                    y: startY + CGFloat(pi) * DatasetNodeLayout.portSpacing
                )
            }
        }
        return nil
    }

    func columnPortPosition(portId: UUID) -> CGPoint? {
        for node in nodes where node.type == .dataset {
            guard let config = node.datasetConfig else { continue }
            if let ci = config.columnPortIds.firstIndex(of: portId) {
                if canvasMode == .inference && inferenceInputSource == .manual {
                    let inputCount = config.preset.inputColumnCount
                    guard ci < inputCount else { return nil }
                    return DatasetNodeLayout.portPosition(
                        nodePosition: node.position,
                        columnIndex: ci,
                        totalColumns: inputCount,
                        nodeHeight: DatasetNodeLayout.height(for: config)
                    )
                }
                let h = DatasetNodeLayout.height(for: config)
                return DatasetNodeLayout.portPosition(
                    nodePosition: node.position,
                    columnIndex: ci,
                    totalColumns: config.columnPortIds.count,
                    nodeHeight: h
                )
            }
        }
        return nil
    }

    // MARK: - Detour Routing

    /// Bounding box of all neuron nodes (captures the neural network area including weight lines)
    private var neuronBoundingBox: CGRect? {
        let neurons = nodes.filter { $0.type == .neuron }
        guard !neurons.isEmpty else { return nil }
        let xs = neurons.map(\.position.x)
        let ys = neurons.map(\.position.y)
        let padding: CGFloat = 60
        return CGRect(
            x: xs.min()! - padding, y: ys.min()! - padding,
            width: xs.max()! - xs.min()! + padding * 2,
            height: ys.max()! - ys.min()! + padding * 2
        )
    }

    /// If a utility link's direct path would cut through the neuron network bbox,
    /// return a Y value to push bezier control points below the network.
    private func computeDetourY(from src: CGPoint, to dst: CGPoint, bbox: CGRect?) -> CGFloat? {
        guard let bbox else { return nil }

        let minX = min(src.x, dst.x)
        let maxX = max(src.x, dst.x)
        guard minX < bbox.midX && maxX > bbox.midX else { return nil }

        let midY = (src.y + dst.y) / 2
        guard midY > bbox.minY && midY < bbox.maxY else { return nil }

        let spanX = maxX - minX
        let margin = max(80, spanX * 0.15)
        return bbox.maxY + margin
    }
}
