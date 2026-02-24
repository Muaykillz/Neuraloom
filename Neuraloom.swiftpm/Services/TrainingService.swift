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
}

// MARK: - TrainingService

@MainActor
final class TrainingService {

    struct CompiledNetwork: Sendable {
        var model: ExecutionModel
        let connToWeightIdx: [UUID: Int]
    }

    private var trainingTask: Task<Void, Never>?
    private var steppingNetwork: CompiledNetwork?
    private var sampleQueue: [([Double], [Double])] = []
    private var sampleIndex: Int = 0
    private var stepEpoch: Int = 0

    private let xorData: [([Double], [Double])] = [
        ([0, 0], [0]), ([0, 1], [1]), ([1, 0], [1]), ([1, 1], [0])
    ]

    // MARK: - Build

    func buildNetwork(nodes: [NodeViewModel], connections: [ConnectionViewModel]) throws -> CompiledNetwork {
        let graph = ComputationGraph()
        var neuronMap: [UUID: Neuron] = [:]

        for nodeVM in nodes where nodeVM.type == .neuron {
            let neuron = graph.addNeuron(activation: nodeVM.activation)
            neuronMap[nodeVM.id] = neuron
        }

        graph.setInputs(nodes.filter(\.isInput).compactMap { neuronMap[$0.id] })
        graph.setOutputs(nodes.filter(\.isOutput).compactMap { neuronMap[$0.id] })

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

        return CompiledNetwork(model: model, connToWeightIdx: connToWeightIdx)
    }

    // MARK: - Async Training

    func startTraining(
        compiled: CompiledNetwork,
        config: TrainingConfig,
        onUpdate: @escaping @Sendable (TrainingUpdate) async -> Void,
        onComplete: @escaping @Sendable () async -> Void
    ) {
        let epochs = config.totalEpochs
        let lr = config.learningRate
        let lf = config.lossFunction
        let batchSize = config.batchSize
        let data = xorData
        let connToWeightIdx = compiled.connToWeightIdx

        trainingTask = Task.detached(priority: .userInitiated) {
            var m = compiled.model
            let updateInterval = max(1, epochs / 100)

            for epoch in 1...epochs {
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
                    await onUpdate(TrainingUpdate(epoch: epoch, loss: loss, weightSync: sync))
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
            model: &net.model, data: xorData,
            learningRate: config.learningRate,
            lossFunction: config.lossFunction,
            batchSize: config.batchSize
        )
        steppingNetwork = net
        stepEpoch += 1
        onUpdate(TrainingUpdate(epoch: stepEpoch, loss: loss, weightSync: syncWeightsDict(from: net)))
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
            sampleQueue = xorData.shuffled()
            sampleIndex = 0
        }
        guard var net = steppingNetwork else { return }

        if sampleIndex >= sampleQueue.count {
            sampleQueue = xorData.shuffled()
            sampleIndex = 0
            stepEpoch += 1
        }
        let sample = [sampleQueue[sampleIndex]]
        sampleIndex += 1

        let loss = ExecutionEngine.trainOneEpoch(
            model: &net.model, data: sample,
            learningRate: config.learningRate,
            lossFunction: config.lossFunction,
            batchSize: 1
        )
        steppingNetwork = net
        onUpdate(TrainingUpdate(epoch: stepEpoch, loss: loss, weightSync: syncWeightsDict(from: net)))
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
