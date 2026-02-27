import SwiftUI

extension CanvasViewModel {

    // MARK: - Pan & Zoom

    func handlePan(translation: CGSize) {
        if selectedConnectionId != nil || selectedNodeId != nil {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                selectedConnectionId = nil
                connectionTapGlobalLocation = nil
                selectedNodeId = nil
                clearGlow()
            }
        }

        let delta = CGSize(
            width: translation.width - previousTranslation.width,
            height: translation.height - previousTranslation.height
        )
        offset.width += delta.width
        offset.height += delta.height
        previousTranslation = translation
    }

    func endPan() {
        previousTranslation = .zero
    }

    private static let minScale: CGFloat = 0.3
    private static let maxScale: CGFloat = 5.0

    func handleZoom(magnification: CGFloat, anchor: CGPoint) {
        let delta = magnification / lastMagnification
        lastMagnification = magnification

        let newScale = min(max(scale * delta, Self.minScale), Self.maxScale)
        let actualDelta = newScale / scale
        offset.width = anchor.x - (anchor.x - offset.width) * actualDelta
        offset.height = anchor.y - (anchor.y - offset.height) * actualDelta
        scale = newScale
    }

    func endZoom(magnification: CGFloat, anchor: CGPoint) {
        lastMagnification = 1.0
        let targetScale = min(max(scale, Self.minScale), Self.maxScale)
        if targetScale != scale {
            let delta = targetScale / scale
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                offset.width = anchor.x - (anchor.x - offset.width) * delta
                offset.height = anchor.y - (anchor.y - offset.height) * delta
                scale = targetScale
            }
        }
    }

    // MARK: - Node Drag

    func handleNodeDrag(id: UUID, location: CGPoint) {
        let canvasPos = convertToCanvasSpace(location)
        updateNodePosition(id: id, newPosition: canvasPos)
    }

    // MARK: - Wiring

    func startWiring(sourceId: UUID, location: CGPoint) {
        activeWiringSource = sourceId
        updateWiringTarget(location: location)
    }

    func updateWiringTarget(location: CGPoint) {
        wiringTargetPosition = location
        if let target = findNode(at: location) {
            hoveredNodeId = target.id
        } else {
            hoveredNodeId = nil
        }
    }

    func endWiring(sourceId: UUID, location: CGPoint) {
        if let targetNode = findNode(at: location) {
            if targetNode.type == .loss, let config = targetNode.lossConfig {
                let canvasPt = convertToCanvasSpace(location)
                let targetId = closestLossPort(config: config, nodePosition: targetNode.position, to: canvasPt)
                addConnection(from: sourceId, to: targetId)
            } else {
                addConnection(from: sourceId, to: targetNode.id)
            }
        }
        activeWiringSource = nil
        wiringTargetPosition = nil
        hoveredNodeId = nil
    }

    // MARK: - Hit Testing

    func convertToCanvasSpace(_ screenPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: (screenPoint.x - offset.width) / scale,
            y: (screenPoint.y - offset.height) / scale
        )
    }

    func findNode(at screenPoint: CGPoint) -> NodeViewModel? {
        let canvasPoint = convertToCanvasSpace(screenPoint)
        return nodes.first { node in
            nodeHitRect(for: node).contains(canvasPoint)
        }
    }

    /// Generous hit rectangle per node type — includes ports area for easy wiring
    private func nodeHitRect(for node: NodeViewModel) -> CGRect {
        let p = node.position
        switch node.type {
        case .neuron:
            return CGRect(x: p.x - 35, y: p.y - 35, width: 70, height: 70)
        case .loss:
            return CGRect(x: p.x - 105, y: p.y - 45, width: 190, height: 90)
        case .visualization:
            return CGRect(x: p.x - 120, y: p.y - 80, width: 240, height: 160)
        case .dataset:
            let h = node.datasetConfig.map { DatasetNodeLayout.height(for: $0) } ?? 120
            return CGRect(x: p.x - DatasetNodeLayout.width / 2 - 10, y: p.y - h / 2 - 10,
                          width: DatasetNodeLayout.width + 50, height: h + 20)
        case .outputDisplay:
            return CGRect(x: p.x - 80, y: p.y - 50, width: 160, height: 100)
        case .number:
            return CGRect(x: p.x - 60, y: p.y - 40, width: 120, height: 80)
        case .annotation:
            return CGRect(x: p.x - 70, y: p.y - 18, width: 140, height: 36)
        }
    }

    // MARK: - Cycle Detection

    func wouldCreateCycle(from sourceId: UUID, to targetId: UUID) -> Bool {
        return isReachable(from: targetId, to: sourceId)
    }

    private func isReachable(from startId: UUID, to endId: UUID) -> Bool {
        if startId == endId { return true }
        let outgoing = connections.filter { $0.sourceNodeId == startId }
        for connection in outgoing {
            if isReachable(from: connection.targetNodeId, to: endId) { return true }
        }
        return false
    }

    // MARK: - Toast

    func triggerToast(_ message: String) {
        withAnimation(.spring()) { toastMessage = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeInOut) {
                if self.toastMessage == message { self.toastMessage = nil }
            }
        }
    }

    // MARK: - Loss Port Helpers

    func closestLossPort(config: LossNodeConfig, nodePosition: CGPoint, to point: CGPoint) -> UUID {
        let totalH = CGFloat(config.inputPortIds.count - 1) * DatasetNodeLayout.portSpacing
        let startY = nodePosition.y - totalH / 2
        var bestId = config.inputPortIds[0]
        var bestDist = CGFloat.infinity
        for (pi, portId) in config.inputPortIds.enumerated() {
            let portY = startY + CGFloat(pi) * DatasetNodeLayout.portSpacing
            let dist = abs(point.y - portY)
            if dist < bestDist { bestDist = dist; bestId = portId }
        }
        return bestId
    }
}
