import SwiftUI

@MainActor
class CanvasViewModel: ObservableObject {
    @Published var nodes: [NodeViewModel] = []
    @Published var connections: [ConnectionViewModel] = []

    @Published var scale: CGFloat = 1.0
    @Published var offset: CGSize = .zero

    @Published var activeWiringSource: UUID? = nil
    @Published var wiringTargetPosition: CGPoint? = nil
    @Published var hoveredNodeId: UUID? = nil

    @Published var selectedNodeId: UUID? = nil
    @Published var selectedConnectionId: UUID? = nil
    @Published var connectionTapGlobalLocation: CGPoint? = nil

    @Published var toastMessage: String? = nil

    // MARK: - Training State
    @Published var isTraining = false
    @Published var currentEpoch = 0
    @Published var totalEpochs = 500
    @Published var learningRate: Double = 0.1
    @Published var selectedLossFunction: LossFunction = .mse
    @Published var currentLoss: Double? = nil
    @Published var lossHistory: [Double] = []
    @Published var stepGranularity: StepGranularity = .epoch

    private let trainingService = TrainingService()

    // Internal state for smooth gestures
    private var lastMagnification: CGFloat = 1.0
    private var previousTranslation: CGSize = .zero
    
    init() {
        setupMVPScenario()
    }
    
    // MARK: - Node & Connection Management
    
    func addNode(type: NodeViewModel.NodeType, at screenPoint: CGPoint) {
        let initialPos = convertToCanvasSpace(screenPoint)
        let finalPos = findNonOverlappingPosition(near: initialPos)
        let newNode = NodeViewModel(id: UUID(), position: finalPos, type: type)
        withAnimation(.spring()) {
            nodes.append(newNode)
        }
    }

    private func findNonOverlappingPosition(near position: CGPoint) -> CGPoint {
        let minDistance: CGFloat = 80 // Minimum distance between nodes
        var candidatePos = position
        var offsetX: CGFloat = 0
        var offsetY: CGFloat = 0
        var attempts = 0
        let maxAttempts = 100

        while attempts < maxAttempts {
            let overlaps = nodes.contains { node in
                let dx = node.position.x - candidatePos.x
                let dy = node.position.y - candidatePos.y
                let distance = sqrt(dx * dx + dy * dy)
                return distance < minDistance
            }

            if !overlaps {
                return candidatePos
            }

            // Spiral pattern: move in a spiral to find free space
            attempts += 1
            let angle = Double(attempts) * 0.5
            let radius = Double(attempts) * 15.0
            offsetX = CGFloat(cos(angle) * radius)
            offsetY = CGFloat(sin(angle) * radius)
            candidatePos = CGPoint(x: position.x + offsetX, y: position.y + offsetY)
        }

        return candidatePos
    }
    
    func deleteNode(id: UUID) {
        withAnimation(.spring()) {
            // Remove the node
            nodes.removeAll { $0.id == id }
            // Remove all associated connections
            connections.removeAll { $0.sourceNodeId == id || $0.targetNodeId == id }
        }
    }
    
    func updateActivation(id: UUID, activation: ActivationType) {
        if let index = nodes.firstIndex(where: { $0.id == id }) {
            nodes[index].activation = activation
        }
    }

    func toggleInput(id: UUID) {
        if let index = nodes.firstIndex(where: { $0.id == id }) {
            nodes[index].isInput.toggle()
            if nodes[index].isInput { nodes[index].isOutput = false }
        }
    }

    func toggleOutput(id: UUID) {
        if let index = nodes.firstIndex(where: { $0.id == id }) {
            nodes[index].isOutput.toggle()
            if nodes[index].isOutput { nodes[index].isInput = false }
        }
    }

    func deleteConnection(id: UUID) {
        withAnimation(.spring()) {
            connections.removeAll { $0.id == id }
        }
    }
    
    func updateNodePosition(id: UUID, newPosition: CGPoint) {
        if let index = nodes.firstIndex(where: { $0.id == id }) {
            nodes[index].position = newPosition
        }
    }
    
    func addConnection(from sourceId: UUID, to targetId: UUID) {
        guard sourceId != targetId else { return }
        if wouldCreateCycle(from: sourceId, to: targetId) {
            triggerToast("Cycle Detected: Feedforward networks must be acyclic.")
            return
        }
        if !connections.contains(where: { $0.sourceNodeId == sourceId && $0.targetNodeId == targetId }) {
            connections.append(ConnectionViewModel(sourceNodeId: sourceId, targetNodeId: targetId))
        }
    }
    
    // MARK: - MVVM Helpers
    
    struct DrawableConnection: Identifiable {
        let id: UUID
        let from: CGPoint
        let to: CGPoint
        let value: Double
    }

    var drawableConnections: [DrawableConnection] {
        connections.compactMap { conn in
            guard let fromNode = nodes.first(where: { $0.id == conn.sourceNodeId }),
                  let toNode = nodes.first(where: { $0.id == conn.targetNodeId }) else { return nil }
            return DrawableConnection(id: conn.id, from: fromNode.position, to: toNode.position, value: conn.value)
        }
    }
    
    var temporaryWiringLine: (from: CGPoint, to: CGPoint)? {
        guard let sourceId = activeWiringSource,
              let sourceNode = nodes.first(where: { $0.id == sourceId }),
              let targetPos = wiringTargetPosition else { return nil }
        
        let fromPoint = CGPoint(x: sourceNode.position.x + 25, y: sourceNode.position.y)
        
        if let hoveredId = hoveredNodeId,
           let hoveredNode = nodes.first(where: { $0.id == hoveredId }) {
            return (fromPoint, hoveredNode.position)
        }
        
        return (fromPoint, convertToCanvasSpace(targetPos))
    }
    
    // MARK: - Gesture Handlers
    
    func handlePan(translation: CGSize) {
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
    
    func handleZoom(magnification: CGFloat, anchor: CGPoint) {
        let delta = magnification / lastMagnification
        lastMagnification = magnification
        
        let newScale = scale * delta
        offset.width = anchor.x - (anchor.x - offset.width) * delta
        offset.height = anchor.y - (anchor.y - offset.height) * delta
        scale = newScale
    }
    
    func endZoom(magnification: CGFloat, anchor: CGPoint) {
        lastMagnification = 1.0
        let targetScale = min(max(scale, 0.2), 5.0)
        if targetScale != scale {
            let delta = targetScale / scale
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                offset.width = anchor.x - (anchor.x - offset.width) * delta
                offset.height = anchor.y - (anchor.y - offset.height) * delta
                scale = targetScale
            }
        }
    }
    
    func handleNodeDrag(id: UUID, location: CGPoint) {
        let canvasPos = convertToCanvasSpace(location)
        updateNodePosition(id: id, newPosition: canvasPos)
    }
    
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
            addConnection(from: sourceId, to: targetNode.id)
        }
        activeWiringSource = nil
        wiringTargetPosition = nil
        hoveredNodeId = nil
    }
    
    // MARK: - Utilities
    
    func convertToCanvasSpace(_ screenPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: (screenPoint.x - offset.width) / scale,
            y: (screenPoint.y - offset.height) / scale
        )
    }
    
    func findNode(at screenPoint: CGPoint) -> NodeViewModel? {
        let canvasPoint = convertToCanvasSpace(screenPoint)
        return nodes.first { node in
            let dist = sqrt(pow(node.position.x - canvasPoint.x, 2) + pow(node.position.y - canvasPoint.y, 2))
            return dist < 30
        }
    }
    
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
    
    func triggerToast(_ message: String) {
        withAnimation(.spring()) { toastMessage = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeInOut) {
                if self.toastMessage == message { self.toastMessage = nil }
            }
        }
    }
    
    func setupMVPScenario() {
        let i1Id = UUID(); let i2Id = UUID(); let h1Id = UUID(); let h2Id = UUID(); let o1Id = UUID()
        nodes = [
            NodeViewModel(id: i1Id, position: CGPoint(x: 100, y: 200), type: .neuron, activation: .linear, isInput: true),
            NodeViewModel(id: i2Id, position: CGPoint(x: 100, y: 400), type: .neuron, activation: .linear, isInput: true),
            NodeViewModel(id: h1Id, position: CGPoint(x: 300, y: 200), type: .neuron, activation: .relu),
            NodeViewModel(id: h2Id, position: CGPoint(x: 300, y: 400), type: .neuron, activation: .relu),
            NodeViewModel(id: o1Id, position: CGPoint(x: 500, y: 300), type: .neuron, activation: .sigmoid, isOutput: true)
        ]
        addConnection(from: i1Id, to: h1Id); addConnection(from: i1Id, to: h2Id)
        addConnection(from: i2Id, to: h1Id); addConnection(from: i2Id, to: h2Id)
        addConnection(from: h1Id, to: o1Id); addConnection(from: h2Id, to: o1Id)
    }

    // MARK: - Training

    func startTraining() {
        guard !isTraining else { return }
        let compiled: TrainingService.CompiledNetwork
        do { compiled = try trainingService.buildNetwork(nodes: nodes, connections: connections) }
        catch { triggerToast(error.localizedDescription); return }

        isTraining = true
        currentEpoch = 0
        lossHistory = []
        currentLoss = nil

        let config = TrainingConfig(
            learningRate: learningRate,
            lossFunction: selectedLossFunction,
            totalEpochs: totalEpochs,
            batchSize: 4
        )
        trainingService.startTraining(compiled: compiled, config: config) { [weak self] update in
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.currentEpoch = update.epoch
                self.currentLoss = update.loss
                self.lossHistory.append(update.loss)
                self.applyWeightSync(update.weightSync)
            }
        } onComplete: { [weak self] in
            await MainActor.run { self?.isTraining = false }
        }
    }

    func stopTraining() {
        trainingService.stopTraining()
        isTraining = false
    }

    func stepTraining() {
        guard !isTraining else { return }
        let config = TrainingConfig(
            learningRate: learningRate,
            lossFunction: selectedLossFunction,
            totalEpochs: totalEpochs,
            batchSize: 4
        )
        trainingService.stepTraining(
            granularity: stepGranularity,
            nodes: nodes,
            connections: connections,
            config: config
        ) { [weak self] update in
            guard let self else { return }
            self.currentEpoch = update.epoch
            self.currentLoss = update.loss
            self.lossHistory.append(update.loss)
            self.applyWeightSync(update.weightSync)
        }
    }

    func resetTraining() {
        trainingService.resetTraining()
        isTraining = false
        lossHistory = []
        currentEpoch = 0
        currentLoss = nil
        for i in connections.indices {
            connections[i].value = 0.0
            connections[i].gradient = 0.0
        }
    }

    func updateConnectionValue(id: UUID, value: Double) {
        if let idx = connections.firstIndex(where: { $0.id == id }) {
            connections[idx].value = value
            trainingService.invalidateStepping()
        }
    }

    private func applyWeightSync(_ sync: [UUID: (value: Double, gradient: Double)]) {
        for (connId, vals) in sync {
            if let ci = connections.firstIndex(where: { $0.id == connId }) {
                connections[ci].value = vals.value
                connections[ci].gradient = vals.gradient
            }
        }
    }
    
    func fitToScreen(in size: CGSize, insets: EdgeInsets) {
        guard !nodes.isEmpty else { scale = 1.0; offset = .zero; return }
        let minX = nodes.map { $0.position.x }.min() ?? 0
        let maxX = nodes.map { $0.position.x }.max() ?? 0
        let minY = nodes.map { $0.position.y }.min() ?? 0
        let maxY = nodes.map { $0.position.y }.max() ?? 0
        let contentWidth = maxX - minX + 150
        let contentHeight = maxY - minY + 150
        let contentCenter = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        let availableWidth = size.width
        let availableHeight = size.height - insets.top - insets.bottom
        let scaleX = availableWidth / contentWidth
        let scaleY = availableHeight / contentHeight
        let newScale = min(min(scaleX, scaleY) * 0.8, 2.0)
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
    
    func autoLayout() {
        var nodeDepths: [UUID: Int] = [:]
        let inputs = nodes.filter { node in !connections.contains(where: { $0.targetNodeId == node.id }) }
        for input in inputs { nodeDepths[input.id] = 0 }
        var changed = true
        while changed {
            changed = false
            for connection in connections {
                if let sourceDepth = nodeDepths[connection.sourceNodeId] {
                    let targetDepth = nodeDepths[connection.targetNodeId]
                    if targetDepth == nil || targetDepth! < sourceDepth + 1 {
                        nodeDepths[connection.targetNodeId] = sourceDepth + 1
                        changed = true
                    }
                }
            }
        }
        let maxDepth = nodeDepths.values.max() ?? 0
        var layers: [[NodeViewModel]] = Array(repeating: [], count: maxDepth + 1)
        for node in nodes { layers[nodeDepths[node.id] ?? 0].append(node) }
        withAnimation(.spring()) {
            for (layerIndex, layerNodes) in layers.enumerated() {
                let startLayerY = CGFloat(100) + (CGFloat(200) - CGFloat(layerNodes.count - 1) * CGFloat(150) / CGFloat(2))
                for (nodeIndex, node) in layerNodes.enumerated() {
                    let newX = CGFloat(100) + CGFloat(layerIndex) * CGFloat(200)
                    let newY = startLayerY + CGFloat(nodeIndex) * CGFloat(150)
                    if let index = nodes.firstIndex(where: { $0.id == node.id }) { nodes[index].position = CGPoint(x: newX, y: newY) }
                }
            }
        }
    }
}

struct NodeViewModel: Identifiable {
    enum NodeType: String, CaseIterable {
        case neuron = "Neuron"
        case dataset = "Dataset"
        case visualization = "Viz"
        case annotation = "Note"

        var icon: String {
            switch self {
            case .neuron: return "circle.grid.3x3.fill"
            case .dataset: return "tablecells.fill"
            case .visualization: return "chart.line.uptrend.xyaxis"
            case .annotation: return "note.text"
            }
        }
    }
    let id: UUID
    var position: CGPoint
    var type: NodeType
    var activation: ActivationType = .relu
    var isInput: Bool = false
    var isOutput: Bool = false
}

struct ConnectionViewModel: Identifiable {
    let id: UUID = UUID()
    var sourceNodeId: UUID
    var targetNodeId: UUID
    var value: Double = 0.0
    var gradient: Double = 0.0
}

enum StepGranularity: String, CaseIterable {
    case sample = "Sample"
    case epoch  = "Epoch"
}
