import Foundation

// MARK: - Supporting Types

struct TrainingConfig: Sendable {
    let learningRate: Double
    let lossFunction: LossFunction
    let totalEpochs: Int
    let batchSize: Int
}

struct TrainingUpdate: Sendable {
    let epoch: Int
    let loss: Double
    let weightSync: [UUID: (value: Double, gradient: Double)]
    let sampleIndex: Int?  // original row index in preset.rows (nil for epoch/async)
}

enum StepGranularity: String, CaseIterable {
    case sample = "Sample"
    case epoch  = "Epoch"
}

// MARK: - TrainingService

@MainActor
final class TrainingService {

    struct CompiledNetwork: Sendable {
        var model: ExecutionModel
        let connToWeightIdx: [UUID: Int]
        let trainingData: [([Double], [Double])]
    }

    private var trainingTask: Task<Void, Never>?
    private var steppingNetwork: CompiledNetwork?
    private var sampleQueue: [(index: Int, input: [Double], output: [Double])] = []
    private var sampleIndex: Int = 0
    private var stepEpoch: Int = 0

    // MARK: - Build

    func buildNetwork(nodes: [NodeViewModel], connections: [ConnectionViewModel]) throws -> CompiledNetwork {
        let graph = ComputationGraph()
        var neuronMap: [UUID: Neuron] = [:]

        for nodeVM in nodes where nodeVM.type == .neuron {
            let neuron = graph.addNeuron(activation: nodeVM.activation)
            neuronMap[nodeVM.id] = neuron
        }

        let inputNeurons = nodes.filter(\.isInput)
        let outputNeurons = nodes.filter(\.isOutput)
        graph.setInputs(inputNeurons.compactMap { neuronMap[$0.id] })
        graph.setOutputs(outputNeurons.compactMap { neuronMap[$0.id] })
        graph.setBiases(nodes.filter(\.isBias).compactMap { neuronMap[$0.id] })

        var connWeightId: [UUID: UUID] = [:]
        for conn in connections {
            guard let from = neuronMap[conn.sourceNodeId],
                  let to = neuronMap[conn.targetNodeId] else { continue }
            let weight = graph.connect(from: from, to: to)
            if conn.value != 0.0 { weight.value = conn.value }
            connWeightId[conn.id] = weight.id
        }

        try graph.validate()

        let model = try ExecutionEngine.compile(graph: graph)

        var connToWeightIdx: [UUID: Int] = [:]
        for (connId, weightId) in connWeightId {
            if let idx = model.weightIDMap.firstIndex(of: weightId) {
                connToWeightIdx[connId] = idx
            }
        }

        // Resolve training data from dataset node
        let trainingData = resolveTrainingData(
            nodes: nodes, connections: connections,
            inputNeuronIds: inputNeurons.map(\.id),
            outputNeuronIds: outputNeurons.map(\.id)
        )

        return CompiledNetwork(model: model, connToWeightIdx: connToWeightIdx, trainingData: trainingData)
    }

    private func resolveTrainingData(
        nodes: [NodeViewModel],
        connections: [ConnectionViewModel],
        inputNeuronIds: [UUID],
        outputNeuronIds: [UUID]
    ) -> [([Double], [Double])] {
        // 1. Find the Loss Node with its config
        guard let lossNode = nodes.first(where: { $0.type == .loss }),
              let lossConfig = lossNode.lossConfig else {
            // Fallback: No loss node or no config — use default XOR
            return [([0,0], [0]), ([0,1], [1]), ([1,0], [1]), ([1,1], [0])]
        }

        // 2. Find Dataset node
        guard let dsNode = nodes.first(where: { $0.type == .dataset }),
              let config = dsNode.datasetConfig else {
            return []
        }
        let portIds = config.columnPortIds
        let rows = config.preset.rows

        // 3. Map Input Neurons to Dataset Ports (X1, X2 -> Input Neurons)
        var inputToColumn: [UUID: Int] = [:]
        for conn in connections {
            if let ci = portIds.firstIndex(of: conn.sourceNodeId) {
                if inputNeuronIds.contains(conn.targetNodeId) {
                    inputToColumn[conn.targetNodeId] = ci
                }
            }
        }

        // 4. Map Output Neurons via Loss Ports
        // Find which neuron connects to the ŷ (prediction) port
        let neuronsConnectingToPred = connections
            .filter { $0.targetNodeId == lossConfig.predPortId }
            .map { $0.sourceNodeId }

        // Find which dataset port connects to the y (target) port
        let portsConnectingToTrue = connections
            .filter { $0.targetNodeId == lossConfig.truePortId && portIds.contains($0.sourceNodeId) }
            .map { $0.sourceNodeId }

        var outputToTargetColumn: [UUID: Int] = [:]
        for (index, neuronId) in neuronsConnectingToPred.enumerated() {
            if index < portsConnectingToTrue.count {
                if let ci = portIds.firstIndex(of: portsConnectingToTrue[index]) {
                    outputToTargetColumn[neuronId] = ci
                }
            }
        }

        // 5. Build the final training data
        return rows.map { row in
            let inputs: [Double] = inputNeuronIds.map { nid in
                if let ci = inputToColumn[nid], ci < row.count { return row[ci] }
                return 0.0
            }
            let outputs: [Double] = outputNeuronIds.map { nid in
                if let ci = outputToTargetColumn[nid], ci < row.count { return row[ci] }
                return 0.0
            }
            return (inputs, outputs)
        }
    }

    // MARK: - Async Training

    func startTraining(
        compiled: CompiledNetwork,
        config: TrainingConfig,
        startEpoch: Int = 0,
        onUpdate: @escaping @Sendable (TrainingUpdate) async -> Void,
        onComplete: @escaping @Sendable () async -> Void
    ) {
        let epochs = config.totalEpochs
        let lr = config.learningRate
        let lf = config.lossFunction
        let batchSize = config.batchSize
        let data = compiled.trainingData
        let connToWeightIdx = compiled.connToWeightIdx

        trainingTask = Task.detached(priority: .userInitiated) {
            var m = compiled.model
            let updateInterval = max(1, epochs / 100)

            if startEpoch >= epochs {
                await onComplete()
                return
            }

            for epoch in (startEpoch + 1)...epochs {
                if Task.isCancelled { break }
                let loss = ExecutionEngine.trainOneEpoch(
                    model: &m, data: data, learningRate: lr,
                    lossFunction: lf, batchSize: batchSize
                )
                if epoch % updateInterval == 0 || epoch == epochs {
                    var sync: [UUID: (value: Double, gradient: Double)] = [:]
                    for (connId, idx) in connToWeightIdx {
                        sync[connId] = (m.weightValues[idx], m.weightGradients[idx])
                    }
                    await onUpdate(TrainingUpdate(epoch: epoch, loss: loss, weightSync: sync, sampleIndex: nil))
                }
            }

            await onComplete()
        }
    }

    func stopTraining() {
        trainingTask?.cancel()
        trainingTask = nil
    }

    // MARK: - Step Training

    func stepTraining(
        granularity: StepGranularity,
        nodes: [NodeViewModel],
        connections: [ConnectionViewModel],
        config: TrainingConfig,
        onUpdate: (TrainingUpdate) -> Void
    ) {
        switch granularity {
        case .epoch:  stepOneEpoch(nodes: nodes, connections: connections, config: config, onUpdate: onUpdate)
        case .sample: stepOneSample(nodes: nodes, connections: connections, config: config, onUpdate: onUpdate)
        }
    }

    private func stepOneEpoch(
        nodes: [NodeViewModel],
        connections: [ConnectionViewModel],
        config: TrainingConfig,
        onUpdate: (TrainingUpdate) -> Void
    ) {
        if steppingNetwork == nil {
            guard let compiled = try? buildNetwork(nodes: nodes, connections: connections) else { return }
            steppingNetwork = compiled
        }
        guard var net = steppingNetwork else { return }

        let loss = ExecutionEngine.trainOneEpoch(
            model: &net.model, data: net.trainingData,
            learningRate: config.learningRate,
            lossFunction: config.lossFunction,
            batchSize: config.batchSize
        )
        steppingNetwork = net
        stepEpoch += 1
        onUpdate(TrainingUpdate(epoch: stepEpoch, loss: loss, weightSync: syncWeightsDict(from: net), sampleIndex: nil))
    }

    private func stepOneSample(
        nodes: [NodeViewModel],
        connections: [ConnectionViewModel],
        config: TrainingConfig,
        onUpdate: (TrainingUpdate) -> Void
    ) {
        if steppingNetwork == nil {
            guard let compiled = try? buildNetwork(nodes: nodes, connections: connections) else { return }
            steppingNetwork = compiled
            sampleQueue = compiled.trainingData.enumerated().map { (i, pair) in
                (index: i, input: pair.0, output: pair.1)
            }
            sampleIndex = 0
        }
        guard var net = steppingNetwork else { return }

        if sampleIndex >= sampleQueue.count {
            sampleQueue = net.trainingData.enumerated().map { (i, pair) in
                (index: i, input: pair.0, output: pair.1)
            }
            sampleIndex = 0
            stepEpoch += 1
        }
        let sample = sampleQueue[sampleIndex]
        let trainData = [(sample.input, sample.output)]
        sampleIndex += 1

        let loss = ExecutionEngine.trainOneEpoch(
            model: &net.model, data: trainData,
            learningRate: config.learningRate,
            lossFunction: config.lossFunction,
            batchSize: 1
        )
        steppingNetwork = net
        onUpdate(TrainingUpdate(epoch: stepEpoch, loss: loss, weightSync: syncWeightsDict(from: net), sampleIndex: sample.index))
    }

    // MARK: - Reset & Invalidate

    func resetTraining() {
        trainingTask?.cancel()
        trainingTask = nil
        steppingNetwork = nil
        sampleQueue = []
        sampleIndex = 0
        stepEpoch = 0
    }

    func invalidateStepping() {
        steppingNetwork = nil
    }

    // MARK: - Private Helpers

    private func syncWeightsDict(from net: CompiledNetwork) -> [UUID: (value: Double, gradient: Double)] {
        var dict: [UUID: (value: Double, gradient: Double)] = [:]
        for (connId, idx) in net.connToWeightIdx {
            dict[connId] = (net.model.weightValues[idx], net.model.weightGradients[idx])
        }
        return dict
    }
}
