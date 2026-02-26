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
    @Published var activeSampleIndex: Int? = nil
    @Published var stepCount = 0
    @Published var playgroundMode: PlaygroundMode = .dev {
        didSet { clearGlow() }
    }
    var inspectMode: Bool { playgroundMode == .inspect }
    @Published var nodeOutputs: [UUID: Double] = [:]
    @Published var nodeGradients: [UUID: Double] = [:]
    @Published var stepPhase: StepPhase? = nil
    @Published var glowingNodeIds: Set<UUID> = []
    @Published var glowingConnectionIds: Set<UUID> = []
    private var sampleLossAccumulator: [Double] = []

    // MARK: - Inference Mode State
    @Published var canvasMode: CanvasMode = .train
    @Published var inferenceInputs: [UUID: Double] = [:]
    @Published var inferenceInputInfos: [InferenceInputInfo] = []
    @Published var inferenceOutputNodeIds: [UUID] = []
    @Published var autoOutputDisplayIds: [UUID] = []
    private var savedPlaygroundMode: PlaygroundMode = .dev
    private var savedSelectedNodeId: UUID?
    private var savedSelectedConnectionId: UUID?
    private var compiledInferenceNetwork: TrainingService.CompiledNetwork?

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
        var newNode = NodeViewModel(id: UUID(), position: finalPos, type: type)
        if type == .dataset {
            newNode.datasetConfig = DatasetNodeConfig()
        }
        if type == .loss {
            newNode.lossConfig = LossNodeConfig()
        }
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
        // Collect synthetic port IDs for dataset and loss nodes
        let portIds: Set<UUID> = {
            guard let node = nodes.first(where: { $0.id == id }) else { return [] }
            var ids = Set<UUID>()
            if let dsConfig = node.datasetConfig { ids.formUnion(dsConfig.columnPortIds) }
            if let lConfig = node.lossConfig { ids.formUnion(lConfig.inputPortIds) }
            return ids
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
        if let target = nodes.first(where: { $0.id == targetId }), target.isBias {
            triggerToast("Bias nodes cannot receive connections.")
            return
        }
        // Dataset port connections don't need cycle check (always source-only)
        let isDatasetPort = columnPortPosition(portId: sourceId) != nil
        // Loss input port connections skip cycle check (utility links)
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
                initVal = 0.0  // utility links — not real weights
            } else if nodes.first(where: { $0.id == sourceId })?.isBias == true {
                initVal = 0.0  // bias → target: standard 0 init
            } else {
                initVal = Double.random(in: -1.0...1.0)  // Xavier-ish
            }
            connections.append(ConnectionViewModel(sourceNodeId: sourceId, targetNodeId: targetId, value: initVal))
        }
    }

    func updateDatasetPreset(nodeId: UUID, preset: DatasetPreset) {
        guard let idx = nodes.firstIndex(where: { $0.id == nodeId }) else { return }
        let oldPortIds = Set(nodes[idx].datasetConfig?.columnPortIds ?? [])
        nodes[idx].datasetConfig?.updatePreset(preset)
        // Remove connections from ports that no longer exist
        let newPortIds = Set(nodes[idx].datasetConfig?.columnPortIds ?? [])
        let removedPorts = oldPortIds.subtracting(newPortIds)
        if !removedPorts.isEmpty {
            connections.removeAll { removedPorts.contains($0.sourceNodeId) }
        }
        trainingService.invalidateStepping()
    }
    
    // MARK: - MVVM Helpers
    
    struct DrawableConnection: Identifiable {
        let id: UUID
        let from: CGPoint
        let to: CGPoint
        let value: Double
        let isUtilityLink: Bool   // dashed style for non-neural connections
        var detourY: CGFloat?     // when set, bezier control points are pushed to this Y
    }

    var drawableConnections: [DrawableConnection] {
        let bbox = neuronBoundingBox
        return connections.compactMap { conn in
            // Resolve target: loss input port or regular node
            let toPoint: CGPoint
            if let portPos = lossPortPosition(portId: conn.targetNodeId) {
                toPoint = portPos
            } else if let toNode = nodes.first(where: { $0.id == conn.targetNodeId }) {
                toPoint = inputEdge(of: toNode)
            } else {
                return nil
            }

            // Resolve source: dataset column port or regular node
            if let portPos = columnPortPosition(portId: conn.sourceNodeId) {
                let dy = computeDetourY(from: portPos, to: toPoint, bbox: bbox)
                return DrawableConnection(id: conn.id, from: portPos, to: toPoint, value: conn.value, isUtilityLink: true, detourY: dy)
            }

            guard let fromNode = nodes.first(where: { $0.id == conn.sourceNodeId }) else { return nil }
            let targetIsLossPort = lossPortPosition(portId: conn.targetNodeId) != nil
            let targetNode = nodes.first(where: { $0.id == conn.targetNodeId })
            let isUtility = fromNode.type != .neuron || targetNode?.type != .neuron || targetIsLossPort
            let fromPt = outputEdge(of: fromNode)
            let dy = isUtility ? computeDetourY(from: fromPt, to: toPoint, bbox: bbox) : nil
            return DrawableConnection(id: conn.id, from: fromPt, to: toPoint, value: conn.value, isUtilityLink: isUtility, detourY: dy)
        }
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
    /// return a Y value to push bezier control points to (smooth arc below network).
    private func computeDetourY(from src: CGPoint, to dst: CGPoint, bbox: CGRect?) -> CGFloat? {
        guard let bbox else { return nil }

        // Only detour if the line spans across the bbox horizontally
        let minX = min(src.x, dst.x)
        let maxX = max(src.x, dst.x)
        guard minX < bbox.midX && maxX > bbox.midX else { return nil }

        // Check if the direct midpoint would fall inside the bbox vertically
        let midY = (src.y + dst.y) / 2
        guard midY > bbox.minY && midY < bbox.maxY else { return nil }

        // Scale margin with horizontal span so wider networks get more clearance
        let spanX = maxX - minX
        let margin = max(80, spanX * 0.15)
        return bbox.maxY + margin
    }

    /// Output handle position (right edge) per node type
    private func outputEdge(of node: NodeViewModel) -> CGPoint {
        let p = node.position
        switch node.type {
        case .neuron:        return CGPoint(x: p.x + 25, y: p.y)
        case .loss:          return CGPoint(x: p.x + 60, y: p.y)
        case .visualization: return CGPoint(x: p.x + 109, y: p.y)
        case .outputDisplay: return CGPoint(x: p.x + 70, y: p.y)
        default:             return p
        }
    }

    /// Input edge position (left edge) per node type
    private func inputEdge(of node: NodeViewModel) -> CGPoint {
        let p = node.position
        switch node.type {
        case .neuron:        return p
        case .loss:          return CGPoint(x: p.x - 63, y: p.y)
        case .visualization: return CGPoint(x: p.x - 109, y: p.y)
        case .outputDisplay: return CGPoint(x: p.x - 70, y: p.y)
        default:             return p
        }
    }

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

    func columnPortPosition(portId: UUID) -> CGPoint? {
        for node in nodes where node.type == .dataset {
            guard let config = node.datasetConfig else { continue }
            if let ci = config.columnPortIds.firstIndex(of: portId) {
                if canvasMode == .inference {
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
    
    var temporaryWiringLine: (from: CGPoint, to: CGPoint)? {
        guard let sourceId = activeWiringSource,
              let targetPos = wiringTargetPosition else { return nil }

        // Resolve source: node output edge or dataset column port
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
            // Loss node: snap preview to nearest input port
            if hoveredNode.type == .loss, let config = hoveredNode.lossConfig {
                let canvasPt = convertToCanvasSpace(targetPos)
                let portId = closestLossPort(config: config, nodePosition: hoveredNode.position, to: canvasPt)
                if let portPos = lossPortPosition(portId: portId) {
                    return (fromPoint, portPos)
                }
            }
            return (fromPoint, inputEdge(of: hoveredNode))
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
            // If target is a loss node with ports, snap to nearest input port
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

    /// Find which loss input port is closest to a canvas point
    private func closestLossPort(config: LossNodeConfig, nodePosition: CGPoint, to point: CGPoint) -> UUID {
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
            let hitRect = nodeHitRect(for: node)
            return hitRect.contains(canvasPoint)
        }
    }

    /// Generous hit rectangle per node type — includes ports area for easy wiring
    private func nodeHitRect(for node: NodeViewModel) -> CGRect {
        let p = node.position
        switch node.type {
        case .neuron:
            // Circle r=25 + port handles
            return CGRect(x: p.x - 35, y: p.y - 35, width: 70, height: 70)
        case .loss:
            // Card 120×72 + input ports extending left (~40pt) + output port right
            return CGRect(x: p.x - 105, y: p.y - 45, width: 190, height: 90)
        case .visualization:
            // Card 210×148 + input port left
            return CGRect(x: p.x - 120, y: p.y - 80, width: 240, height: 160)
        case .dataset:
            let h = node.datasetConfig.map { DatasetNodeLayout.height(for: $0) } ?? 120
            return CGRect(x: p.x - DatasetNodeLayout.width / 2 - 10, y: p.y - h / 2 - 10,
                          width: DatasetNodeLayout.width + 50, height: h + 20)
        case .outputDisplay:
            return CGRect(x: p.x - 80, y: p.y - 50, width: 160, height: 100)
        case .annotation:
            return CGRect(x: p.x - 70, y: p.y - 18, width: 140, height: 36)
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
        let dsId = UUID(); let lossId = UUID(); let vizId = UUID()
        let dsConfig = DatasetNodeConfig(preset: .xor)
        let lossConfig = LossNodeConfig()

        nodes = [
            NodeViewModel(id: i1Id, position: CGPoint(x: 100, y: 200), type: .neuron, activation: .linear, role: .input),
            NodeViewModel(id: i2Id, position: CGPoint(x: 100, y: 400), type: .neuron, activation: .linear, role: .input),
            NodeViewModel(id: h1Id, position: CGPoint(x: 300, y: 200), type: .neuron, activation: .relu),
            NodeViewModel(id: h2Id, position: CGPoint(x: 300, y: 400), type: .neuron, activation: .relu),
            NodeViewModel(id: o1Id, position: CGPoint(x: 500, y: 300), type: .neuron, activation: .sigmoid, role: .output),
            {
                var n = NodeViewModel(id: dsId, position: CGPoint(x: -150, y: 300), type: .dataset)
                n.datasetConfig = dsConfig
                return n
            }(),
            {
                var n = NodeViewModel(id: lossId, position: CGPoint(x: 700, y: 300), type: .loss)
                n.lossConfig = lossConfig
                return n
            }(),
            NodeViewModel(id: vizId, position: CGPoint(x: 950, y: 300), type: .visualization)
        ]

        // Internal Network connections
        addConnection(from: i1Id, to: h1Id); addConnection(from: i1Id, to: h2Id)
        addConnection(from: i2Id, to: h1Id); addConnection(from: i2Id, to: h2Id)
        addConnection(from: h1Id, to: o1Id); addConnection(from: h2Id, to: o1Id)

        // Dataset X1, X2 -> Inputs
        addConnection(from: dsConfig.columnPortIds[0], to: i1Id)
        addConnection(from: dsConfig.columnPortIds[1], to: i2Id)

        // Output Neuron -> Loss ŷ (Prediction port)
        addConnection(from: o1Id, to: lossConfig.predPortId)

        // Dataset Y -> Loss y (Target port)
        addConnection(from: dsConfig.columnPortIds[2], to: lossConfig.truePortId)

        // Loss -> Visualization
        addConnection(from: lossId, to: vizId)
    }

    // MARK: - Training

    func startTraining() {
        guard !isTraining else { return }

        isTraining = true
        
        // Only reset if we are at the very beginning
        if currentEpoch == 0 && stepCount == 0 {
            lossHistory = []
            sampleLossAccumulator = []
            currentLoss = nil
        }
        activeSampleIndex = nil

        if stepGranularity == .epoch {
            startEpochTraining()
        } else {
            startSampleTraining()
        }
    }

    private func startEpochTraining() {
        let compiled: TrainingService.CompiledNetwork
        if let existing = trainingService.currentSteppingNetwork() {
            compiled = existing
        } else {
            do { compiled = try trainingService.buildNetwork(nodes: nodes, connections: connections) }
            catch { triggerToast(error.localizedDescription); isTraining = false; return }
        }

        let config = TrainingConfig(
            learningRate: learningRate,
            lossFunction: selectedLossFunction,
            totalEpochs: totalEpochs,
            batchSize: 4
        )
        // Pass currentEpoch as the starting point
        trainingService.startTraining(compiled: compiled, config: config, startEpoch: currentEpoch) { [weak self] update in
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.currentEpoch = update.epoch
                self.currentLoss = update.loss
                self.lossHistory.append(update.loss)
                self.applyWeightSync(update.weightSync)
                self.applyNodeSync(update.nodeSync)
            }
        } onComplete: { [weak self] in
            await MainActor.run { self?.isTraining = false }
        }
    }

    private var sampleTrainingTimer: Timer?

    private func startSampleTraining() {
        let target = totalEpochs  // in sample mode, the input = total steps
        sampleTrainingTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isTraining else {
                    self?.sampleTrainingTimer?.invalidate()
                    self?.sampleTrainingTimer = nil
                    return
                }
                if self.stepCount >= target {
                    self.sampleTrainingTimer?.invalidate()
                    self.sampleTrainingTimer = nil
                    self.isTraining = false
                    return
                }
                self.performOneStep()
            }
        }
    }

    func stopTraining() {
        trainingService.stopTraining()
        sampleTrainingTimer?.invalidate()
        sampleTrainingTimer = nil
        isTraining = false
        activeSampleIndex = nil
    }

    func stepTraining() {
        guard !isTraining else { return }
        performOneStep()
    }

    private func performOneStep() {
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
            let prevEpoch = self.currentEpoch
            self.currentEpoch = update.epoch
            self.currentLoss = update.loss
            self.stepCount += 1

            if self.stepGranularity == .epoch {
                self.lossHistory.append(update.loss)
            } else {
                self.sampleLossAccumulator.append(update.loss)
                if update.epoch > prevEpoch && !self.sampleLossAccumulator.isEmpty {
                    let avg = self.sampleLossAccumulator.reduce(0, +) / Double(self.sampleLossAccumulator.count)
                    self.lossHistory.append(avg)
                    self.sampleLossAccumulator = []
                }
            }
            self.applyWeightSync(update.weightSync)
            self.applyNodeSync(update.nodeSync)
            self.stepPhase = update.phase
            self.activeSampleIndex = update.sampleIndex
        }
    }

    func resetTraining() {
        trainingService.resetTraining()
        sampleTrainingTimer?.invalidate()
        sampleTrainingTimer = nil
        isTraining = false
        lossHistory = []
        sampleLossAccumulator = []
        currentEpoch = 0
        stepCount = 0
        currentLoss = nil
        activeSampleIndex = nil
        nodeOutputs = [:]
        nodeGradients = [:]
        stepPhase = nil
        clearGlow()
        for i in connections.indices {
            let src = connections[i].sourceNodeId
            let isBias = nodes.first(where: { $0.id == src })?.isBias == true
            let isUtility = columnPortPosition(portId: src) != nil
                || lossPortPosition(portId: connections[i].targetNodeId) != nil
            connections[i].value = (isBias || isUtility) ? 0.0 : Double.random(in: -1.0...1.0)
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

    private func applyNodeSync(_ sync: [UUID: (value: Double, gradient: Double)]) {
        for (nodeId, vals) in sync {
            nodeOutputs[nodeId] = vals.value
            nodeGradients[nodeId] = vals.gradient
        }
    }

    // MARK: - Glow (concept box tap → highlight on canvas)

    func toggleGlow(nodeIds: Set<UUID> = [], connectionIds: Set<UUID> = []) {
        if glowingNodeIds == nodeIds && glowingConnectionIds == connectionIds {
            clearGlow()
        } else {
            glowingNodeIds = nodeIds
            glowingConnectionIds = connectionIds
        }
    }

    func clearGlow() {
        glowingNodeIds = []
        glowingConnectionIds = []
    }

    // MARK: - Inference Mode

    func enterInferenceMode() {
        guard canvasMode == .train else { return }
        stopTraining()

        do {
            compiledInferenceNetwork = try trainingService.buildNetwork(nodes: nodes, connections: connections)
        } catch {
            triggerToast("Cannot enter inference: \(error.localizedDescription)")
            return
        }

        savedPlaygroundMode = playgroundMode
        savedSelectedNodeId = selectedNodeId
        savedSelectedConnectionId = selectedConnectionId

        inferenceInputInfos = []
        inferenceInputs = [:]
        if let dsNode = nodes.first(where: { $0.type == .dataset }),
           let config = dsNode.datasetConfig {
            let preset = config.preset
            let ranges = preset.inputRanges
            let inputCols = preset.inputColumns
            for i in 0..<inputCols.count {
                let portId = config.columnPortIds[i]
                let range = i < ranges.count ? ranges[i] : (min: 0.0, max: 1.0)
                let mid = (range.min + range.max) / 2.0
                inferenceInputInfos.append(InferenceInputInfo(
                    label: inputCols[i],
                    portId: portId,
                    range: range.min...range.max
                ))
                inferenceInputs[portId] = mid
            }
        }

        inferenceOutputNodeIds = nodes.filter { $0.type == .neuron && $0.isOutput }.map(\.id)

        autoOutputDisplayIds = []
        for outId in inferenceOutputNodeIds {
            if let outNode = nodes.first(where: { $0.id == outId }) {
                let displayId = UUID()
                var displayNode = NodeViewModel(
                    id: displayId,
                    position: CGPoint(x: outNode.position.x + 150, y: outNode.position.y),
                    type: .outputDisplay
                )
                displayNode.outputDisplayValue = nodeOutputs[outId]
                nodes.append(displayNode)
                connections.append(ConnectionViewModel(sourceNodeId: outId, targetNodeId: displayId))
                autoOutputDisplayIds.append(displayId)
            }
        }

        playgroundMode = .inspect
        selectedNodeId = nil
        selectedConnectionId = nil
        connectionTapGlobalLocation = nil

        withAnimation(.spring()) {
            canvasMode = .inference
        }

        runInference()
    }

    func exitInferenceMode() {
        guard canvasMode == .inference else { return }

        let autoIds = Set(autoOutputDisplayIds)
        nodes.removeAll { autoIds.contains($0.id) }
        connections.removeAll { autoIds.contains($0.sourceNodeId) || autoIds.contains($0.targetNodeId) }

        playgroundMode = savedPlaygroundMode
        selectedNodeId = savedSelectedNodeId
        selectedConnectionId = savedSelectedConnectionId

        inferenceInputInfos = []
        inferenceInputs = [:]
        inferenceOutputNodeIds = []
        autoOutputDisplayIds = []
        compiledInferenceNetwork = nil

        withAnimation(.spring()) {
            canvasMode = .train
        }
    }

    func runInference() {
        guard var net = compiledInferenceNetwork else { return }

        let inputNeuronIds = nodes.filter { $0.type == .neuron && $0.isInput }.map(\.id)
        var inputValues: [Double] = []

        for neuronId in inputNeuronIds {
            var value = 0.0
            for conn in connections {
                if conn.targetNodeId == neuronId,
                   let v = inferenceInputs[conn.sourceNodeId] {
                    value = v
                    break
                }
            }
            inputValues.append(value)
        }

        ExecutionEngine.predict(model: &net.model, input: inputValues)
        compiledInferenceNetwork = net

        for (vmId, idx) in net.nodeVMIdToNodeIdx {
            nodeOutputs[vmId] = net.model.nodeValues[idx]
        }

        for (i, outNeuronId) in inferenceOutputNodeIds.enumerated() {
            let value = nodeOutputs[outNeuronId] ?? 0
            if i < autoOutputDisplayIds.count {
                if let idx = nodes.firstIndex(where: { $0.id == autoOutputDisplayIds[i] }) {
                    nodes[idx].outputDisplayValue = value
                }
            }
        }
    }

    // MARK: - Visible Nodes/Connections (filtered by mode)

    var visibleNodes: [NodeViewModel] {
        if canvasMode == .train { return nodes }
        return nodes.filter { node in
            switch node.type {
            case .loss, .visualization: return false
            default: return true
            }
        }
    }

    var visibleConnections: [DrawableConnection] {
        if canvasMode == .train { return drawableConnections }
        let hiddenNodeIds = Set(nodes.filter { $0.type == .loss || $0.type == .visualization }.map(\.id))
        let hiddenPortIds: Set<UUID> = Set(nodes.compactMap { $0.lossConfig }.flatMap { $0.inputPortIds })
        return drawableConnections.filter { conn in
            let rawConn = connections.first(where: { $0.id == conn.id })
            guard let raw = rawConn else { return true }
            if hiddenNodeIds.contains(raw.sourceNodeId) || hiddenNodeIds.contains(raw.targetNodeId) { return false }
            if hiddenPortIds.contains(raw.sourceNodeId) || hiddenPortIds.contains(raw.targetNodeId) { return false }
            return true
        }
    }
    
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
        // Only layout neuron nodes — leave dataset, loss, viz, annotation in place
        let neuronIds = Set(nodes.filter { $0.type == .neuron }.map { $0.id })
        let neuronConns = connections.filter { neuronIds.contains($0.sourceNodeId) && neuronIds.contains($0.targetNodeId) }

        // Compute depths via BFS on neuron-only subgraph
        var nodeDepths: [UUID: Int] = [:]
        let inputs = nodes.filter { node in node.type == .neuron && !neuronConns.contains(where: { $0.targetNodeId == node.id }) }
        for input in inputs { nodeDepths[input.id] = 0 }
        var changed = true
        while changed {
            changed = false
            for conn in neuronConns {
                if let sourceDepth = nodeDepths[conn.sourceNodeId] {
                    let targetDepth = nodeDepths[conn.targetNodeId]
                    if targetDepth == nil || targetDepth! < sourceDepth + 1 {
                        nodeDepths[conn.targetNodeId] = sourceDepth + 1
                        changed = true
                    }
                }
            }
        }

        let maxDepth = nodeDepths.values.max() ?? 0
        var layers: [[NodeViewModel]] = Array(repeating: [], count: maxDepth + 1)
        for node in nodes where node.type == .neuron {
            layers[nodeDepths[node.id] ?? 0].append(node)
        }

        // Compute network center Y for vertical centering
        let neuronPositions = nodes.filter { $0.type == .neuron }.map { $0.position }
        let centerY = neuronPositions.isEmpty ? 300.0
            : (neuronPositions.map(\.y).min()! + neuronPositions.map(\.y).max()!) / 2

        let hSpacing: CGFloat = 250
        let vSpacing: CGFloat = 200
        let startX: CGFloat = 100

        withAnimation(.spring()) {
            // 1. Layout neuron layers
            for (layerIndex, layerNodes) in layers.enumerated() {
                let layerHeight = CGFloat(layerNodes.count - 1) * vSpacing
                let startY = centerY - layerHeight / 2
                for (nodeIndex, node) in layerNodes.enumerated() {
                    let newX = startX + CGFloat(layerIndex) * hSpacing
                    let newY = startY + CGFloat(nodeIndex) * vSpacing
                    if let index = nodes.firstIndex(where: { $0.id == node.id }) {
                        nodes[index].position = CGPoint(x: newX, y: newY)
                    }
                }
            }

            // 2. Layout pipeline nodes relative to the network
            let networkLeftX = startX
            let networkRightX = startX + CGFloat(maxDepth) * hSpacing
            let pipelineGap: CGFloat = 250

            // Dataset nodes → left of input layer
            let datasetNodes = nodes.filter { $0.type == .dataset }
            if !datasetNodes.isEmpty {
                let dsX = networkLeftX - pipelineGap
                let totalH = CGFloat(datasetNodes.count - 1) * vSpacing
                let dsStartY = centerY - totalH / 2
                for (i, ds) in datasetNodes.enumerated() {
                    if let idx = nodes.firstIndex(where: { $0.id == ds.id }) {
                        nodes[idx].position = CGPoint(x: dsX, y: dsStartY + CGFloat(i) * vSpacing)
                    }
                }
            }

            // Loss nodes → right of output layer
            let lossNodes = nodes.filter { $0.type == .loss }
            if !lossNodes.isEmpty {
                let lossX = networkRightX + pipelineGap
                let totalH = CGFloat(lossNodes.count - 1) * vSpacing
                let lossStartY = centerY - totalH / 2
                for (i, ln) in lossNodes.enumerated() {
                    if let idx = nodes.firstIndex(where: { $0.id == ln.id }) {
                        nodes[idx].position = CGPoint(x: lossX, y: lossStartY + CGFloat(i) * vSpacing)
                    }
                }
            }

            // Visualization nodes → right of loss nodes (or right of network if no loss)
            let vizNodes = nodes.filter { $0.type == .visualization }
            if !vizNodes.isEmpty {
                let vizAnchorX = lossNodes.isEmpty ? networkRightX : networkRightX + pipelineGap
                let vizX = vizAnchorX + pipelineGap
                let totalH = CGFloat(vizNodes.count - 1) * vSpacing
                let vizStartY = centerY - totalH / 2
                for (i, vn) in vizNodes.enumerated() {
                    if let idx = nodes.firstIndex(where: { $0.id == vn.id }) {
                        nodes[idx].position = CGPoint(x: vizX, y: vizStartY + CGFloat(i) * vSpacing)
                    }
                }
            }
        }
    }
}

enum CanvasMode: String {
    case train, inference
}

struct InferenceInputInfo: Identifiable {
    let id = UUID()
    let label: String
    let portId: UUID
    let range: ClosedRange<Double>
}

enum PlaygroundMode: String, CaseIterable {
    case dev     = "Dev"
    case inspect = "Inspect"
}

enum NodeRole: String, CaseIterable {
    case hidden = "Hidden"
    case input  = "Input"
    case output = "Output"
    case bias   = "Bias"
}

struct NodeViewModel: Identifiable {
    enum NodeType: String, CaseIterable {
        case neuron = "Neuron"
        case dataset = "Dataset"
        case loss = "Loss"
        case visualization = "Viz"
        case outputDisplay = "Result"
        case annotation = "Note"

        var icon: String {
            switch self {
            case .neuron: return "circle.grid.3x3.fill"
            case .dataset: return "tablecells.fill"
            case .loss: return "target"
            case .visualization: return "chart.line.uptrend.xyaxis"
            case .outputDisplay: return "eye.circle.fill"
            case .annotation: return "note.text"
            }
        }

    }
    let id: UUID
    var position: CGPoint
    var type: NodeType
    var activation: ActivationType = .relu
    var role: NodeRole = .hidden
    var datasetConfig: DatasetNodeConfig?
    var lossConfig: LossNodeConfig?
    var outputDisplayValue: Double?
    var annotationText: String = "Note"

    var isInput: Bool { role == .input }
    var isOutput: Bool { role == .output }
    var isBias: Bool  { role == .bias }
}

struct ConnectionViewModel: Identifiable {
    let id: UUID = UUID()
    var sourceNodeId: UUID
    var targetNodeId: UUID
    var value: Double = 0.0
    var gradient: Double = 0.0
}

