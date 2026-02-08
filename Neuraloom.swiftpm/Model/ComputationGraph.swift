import Foundation

class ComputationGraph {
    private(set) var neurons: [UUID: Neuron]
    private(set) var weights: [UUID: Weight]
    
    private(set) var inputNeurons: [Neuron]
    private(set) var outputNeurons: [Neuron]
    
    init() {
        self.neurons = [:]
        self.weights = [:]
        self.inputNeurons = []
        self.outputNeurons = []
    }
    
    // MARK: - Building
    
    func addNeuron(activation: ActivationType) -> Neuron {
        let neuron = Neuron(activation: activation)
        neurons[neuron.id] = neuron
        return neuron
    }
    
    func connect(from: Neuron, to: Neuron, initialWeightValue: Double? = nil) -> Weight {
        let weight = Weight(from: from, to: to, initialValue: initialWeightValue)
        from.outgoingWeights.append(weight)
        to.incomingWeights.append(weight)
        weights[weight.id] = weight
        return weight
    }
    
    func setInputs(_ neurons: [Neuron]) {
        self.inputNeurons = neurons
    }
    
    func setOutputs(_ neurons: [Neuron]) {
        self.outputNeurons = neurons
    }
    
    // MARK: - Validation
    
    func validate() throws {
        guard !inputNeurons.isEmpty && !outputNeurons.isEmpty else {
            throw GraphError.inputOutputNotSet
        }
        
        resetVisitedState()
        
        try checkCycles()
        try checkConnectivity()
    }
    
    private func resetVisitedState() {
        for neuron in neurons.values {
            neuron.visitedState = .unvisited
            neuron.inDegree = 0
        }
    }
    
    private func checkCycles() throws {
        for neuron in neurons.values {
            if neuron.visitedState == .unvisited {
                try dfsForCycle(neuron)
            }
        }
    }
    
    private func dfsForCycle(_ neuron: Neuron) throws {
        neuron.visitedState = .visiting
        
        for weight in neuron.outgoingWeights {
            guard let neighbor = weight.to else { continue }
            
            if neighbor.visitedState == .visiting {
                throw GraphError.cycleDetected
            }
            if neighbor.visitedState == .unvisited {
                try dfsForCycle(neighbor)
            }
        }
        
        neuron.visitedState = .visited
    }
    
    private func checkConnectivity() throws {
        guard !inputNeurons.isEmpty else {
            throw GraphError.inputOutputNotSet
        }
        
        var queue = inputNeurons
        var visited = Set(inputNeurons.map(\.id))
        
        while !queue.isEmpty {
            let current = queue.removeFirst()
            
            for weight in current.outgoingWeights {
                guard let neighbor = weight.to else { continue }
                if !visited.contains(neighbor.id) {
                    visited.insert(neighbor.id)
                    queue.append(neighbor)
                }
            }
        }
        
        for neuron in neurons.values {
            if !visited.contains(neuron.id) {
                throw GraphError.disconnectedGraph
            }
        }
        
        for outputNeuron in outputNeurons {
            if !visited.contains(outputNeuron.id) {
                throw GraphError.disconnectedGraph
            }
        }
    }
    
    // MARK: - Execution
    
    var topologicalOrder: [Neuron] {
        get throws {
            for neuron in neurons.values {
                neuron.inDegree = neuron.incomingWeights.count
            }
            
            var order: [Neuron] = []
            var queue: [Neuron] = []
            
            for neuron in neurons.values where neuron.inDegree == 0 {
                queue.append(neuron)
            }
            
            while !queue.isEmpty {
                let current = queue.removeFirst()
                order.append(current)
                
                for weight in current.outgoingWeights {
                    guard let neighbor = weight.to else { continue }
                    neighbor.inDegree -= 1
                    if neighbor.inDegree == 0 {
                        queue.append(neighbor)
                    }
                }
            }
            
            if order.count != neurons.count {
                throw GraphError.cycleDetected
            }
            
            return order
        }
    }
    
    func forward(input: [Double]) throws {
        guard input.count == inputNeurons.count else {
            throw GraphError.dimensionMismatch
        }
        
        // Note: Gradients are NOT reset here to allow accumulation.
        // Values are overwritten by topological computation.
        
        for (index, value) in input.enumerated() {
            inputNeurons[index].value = value
        }
        
        let order = try topologicalOrder
        for neuron in order {
            if !neuron.isInput {
                neuron.computeOutput()
            }
        }
    }
    
    func backward(target: [Double], lossFunction: LossFunction) throws {
        guard target.count == outputNeurons.count else {
            throw GraphError.dimensionMismatch
        }
        
        let predicted = self.output
        let outputGradients = lossFunction.gradient(predicted: predicted, target: target)
        
        for (index, neuron) in outputNeurons.enumerated() {
            neuron.gradient = outputGradients[index]
        }
        
        let order = try topologicalOrder
        for neuron in order.reversed() {
            neuron.backpropagate()
        }
    }
    
    func train(
        data: [([Double], [Double])],
        epochs: Int,
        lossFunction: LossFunction,
        optimizer: SGDOptimizer,
        batchSize: Int = 1,
        verbose: Bool = true
    ) throws -> [Double] {
        var lossHistory: [Double] = []
        
        for epoch in 1...epochs {
            var totalLoss: Double = 0.0
            let shuffledData = data.shuffled()
            let batches = shuffledData.chunked(into: batchSize)
            
            for batch in batches {
                resetGradients()
                
                for (input, target) in batch {
                    try forward(input: input)
                    
                    let loss = lossFunction.compute(predicted: self.output, target: target)
                    totalLoss += loss
                    
                    try backward(target: target, lossFunction: lossFunction)
                }
                
                // Update weights with gradient averaging
                optimizer.step(weights: Array(weights.values), batchSize: batch.count)
            }
            
            let avgLoss = totalLoss / Double(data.count)
            lossHistory.append(avgLoss)
            
            if verbose && (epoch % 10 == 0 || epoch == 1) {
                print("Epoch \(epoch)/\(epochs): Loss = \(String(format: "%.6f", avgLoss))")
            }
        }
        
        return lossHistory
    }
    
    var output: [Double] {
        outputNeurons.map(\.value)
    }
    
    // MARK: - Utility
    
    func resetGradients() {
        for neuron in neurons.values {
            neuron.gradient = 0.0
        }
        for weight in weights.values {
            weight.resetGradient()
        }
    }
    
    func resetGradientsAndValues() {
        resetGradients()
        for neuron in neurons.values {
            if !neuron.isInput {
                neuron.value = 0.0
            }
            neuron.visitedState = .unvisited
        }
    }
}

enum GraphError: Error, CustomStringConvertible {
    case cycleDetected
    case disconnectedGraph
    case inputOutputNotSet
    case dimensionMismatch
    
    var description: String {
        switch self {
        case .cycleDetected: return "Cycle detected in the computation graph. Feedforward networks cannot have cycles."
        case .disconnectedGraph: return "Disconnected graph: Not all neurons are reachable from input neurons, or output neurons are not reachable."
        case .inputOutputNotSet: return "Input or output neurons are not set for the graph."
        case .dimensionMismatch: return "Input dimension mismatch. The number of provided inputs does not match the number of input neurons."
        }
    }
}