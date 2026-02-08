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
    
    var output: [Double] {
        outputNeurons.map(\.value)
    }
    
    // MARK: - Utility
    
    func resetVisitedState() {
        for neuron in neurons.values {
            neuron.visitedState = .unvisited
            neuron.inDegree = 0
        }
    }
    
    func resetValues() {
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