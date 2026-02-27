import SwiftUI

extension CanvasViewModel {

    // MARK: - Node CRUD

    func addNode(type: NodeViewModel.NodeType, at screenPoint: CGPoint) {
        let initialPos = convertToCanvasSpace(screenPoint)
        let finalPos = findNonOverlappingPosition(near: initialPos)
        var newNode = NodeViewModel(id: UUID(), position: finalPos, type: type)
        if type == .dataset {
            newNode.datasetConfig = DatasetNodeConfig()
        }
        if type == .loss {
            newNode.lossConfig = LossNodeConfig()
        }
        if canvasMode == .inference {
            inferenceTemporaryNodeIds.insert(newNode.id)
        }
        withAnimation(.spring()) {
            nodes.append(newNode)
        }
    }

    func deleteNode(id: UUID) {
        let portIds: Set<UUID> = {
            guard let node = nodes.first(where: { $0.id == id }) else { return [] }
            var result = Set<UUID>()
            if let config = node.datasetConfig { result.formUnion(config.columnPortIds) }
            if let config = node.lossConfig { result.formUnion(config.inputPortIds) }
            return result
        }()
        withAnimation(.spring()) {
            nodes.removeAll { $0.id == id }
            connections.removeAll { conn in
                conn.sourceNodeId == id || conn.targetNodeId == id ||
                portIds.contains(conn.sourceNodeId) || portIds.contains(conn.targetNodeId)
            }
        }
    }

    func updateActivation(id: UUID, activation: ActivationType) {
        if let index = nodes.firstIndex(where: { $0.id == id }) {
            nodes[index].activation = activation
        }
    }

    func setRole(_ role: NodeRole, for id: UUID) {
        guard let index = nodes.firstIndex(where: { $0.id == id }) else { return }
        let newRole: NodeRole = nodes[index].role == role ? .hidden : role
        nodes[index].role = newRole
        if newRole == .bias {
            connections.removeAll { $0.targetNodeId == id }
            nodes[index].activation = .linear
        }
        trainingService.invalidateStepping()
    }

    func updateNodePosition(id: UUID, newPosition: CGPoint) {
        if let index = nodes.firstIndex(where: { $0.id == id }) {
            nodes[index].position = newPosition
        }
    }

    // MARK: - Connection CRUD

    func addConnection(from sourceId: UUID, to targetId: UUID) {
        guard sourceId != targetId else { return }
        if let target = nodes.first(where: { $0.id == targetId }), target.isBias {
            triggerToast("Bias nodes cannot receive connections.")
            return
        }
        let isDatasetPort = columnPortPosition(portId: sourceId) != nil
        let isLossPort = lossPortPosition(portId: targetId) != nil
        if !isDatasetPort && !isLossPort {
            if let target = nodes.first(where: { $0.id == targetId }), target.type == .dataset {
                triggerToast("Dataset nodes cannot receive connections.")
                return
            }
            if wouldCreateCycle(from: sourceId, to: targetId) {
                triggerToast("Cycle Detected: Feedforward networks must be acyclic.")
                return
            }
        }
        if !connections.contains(where: { $0.sourceNodeId == sourceId && $0.targetNodeId == targetId }) {
            let initVal: Double
            if isDatasetPort || isLossPort {
                initVal = 0.0
            } else if nodes.first(where: { $0.id == sourceId })?.isBias == true {
                initVal = 0.0
            } else {
                initVal = Double.random(in: -1.0...1.0)
            }
            let newConn = ConnectionViewModel(sourceNodeId: sourceId, targetNodeId: targetId, value: initVal)
            if canvasMode == .inference {
                inferenceTemporaryConnectionIds.insert(newConn.id)
            }
            connections.append(newConn)
        }
    }

    func deleteConnection(id: UUID) {
        withAnimation(.spring()) {
            connections.removeAll { $0.id == id }
        }
    }

    func updateConnectionValue(id: UUID, value: Double) {
        if let idx = connections.firstIndex(where: { $0.id == id }) {
            connections[idx].value = value
            if canvasMode == .inference {
                syncWeightToInferenceNetwork(connectionId: id, newValue: value)
            } else {
                trainingService.invalidateStepping()
            }
        }
    }

    func updateDatasetPreset(nodeId: UUID, preset: DatasetPreset) {
        guard let idx = nodes.firstIndex(where: { $0.id == nodeId }) else { return }
        let oldPortIds = Set(nodes[idx].datasetConfig?.columnPortIds ?? [])
        nodes[idx].datasetConfig?.updatePreset(preset)
        let newPortIds = Set(nodes[idx].datasetConfig?.columnPortIds ?? [])
        let removedPorts = oldPortIds.subtracting(newPortIds)
        if !removedPorts.isEmpty {
            connections.removeAll { removedPorts.contains($0.sourceNodeId) }
        }
        trainingService.invalidateStepping()
    }

    func clearCanvas() {
        withAnimation(.easeOut(duration: 0.2)) {
            canvasOpacity = 0.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }
            self.nodes.removeAll()
            self.connections.removeAll()
            self.selectedNodeId = nil
            self.selectedConnectionId = nil
            self.connectionTapGlobalLocation = nil
            self.resetTraining()
            self.canvasOpacity = 1.0
        }
    }

    // MARK: - Helpers

    private func findNonOverlappingPosition(near position: CGPoint) -> CGPoint {
        let minDistance: CGFloat = 80
        var candidatePos = position
        var attempts = 0

        while attempts < 100 {
            let overlaps = nodes.contains { node in
                let dx = node.position.x - candidatePos.x
                let dy = node.position.y - candidatePos.y
                return sqrt(dx * dx + dy * dy) < minDistance
            }
            if !overlaps { return candidatePos }

            attempts += 1
            let angle = Double(attempts) * 0.5
            let radius = Double(attempts) * 15.0
            candidatePos = CGPoint(
                x: position.x + CGFloat(cos(angle) * radius),
                y: position.y + CGFloat(sin(angle) * radius)
            )
        }
        return candidatePos
    }
}
