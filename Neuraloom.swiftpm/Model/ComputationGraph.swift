import Foundation

class ComputationGraph {
    private(set) var neurons: [UUID: Neuron]
    private(set) var weights: [UUID: Weight]
    
    private(set) var inputNeurons: [Neuron]
    private(set) var outputNeurons: [Neuron]
    private(set) var biasNeurons: [Neuron]

    init() {
        self.neurons = [:]
        self.weights = [:]
        self.inputNeurons = []
        self.outputNeurons = []
        self.biasNeurons = []
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

    func setBiases(_ neurons: [Neuron]) {
        self.biasNeurons = neurons
    }
    
    // MARK: - Validation
    
    func validate() throws {
        guard !inputNeurons.isEmpty && !outputNeurons.isEmpty else {
            throw GraphError.inputOutputNotSet
        }
        
        // Use topologicalOrder to validate cycles and connectivity
        let _ = try topologicalOrder()
        
        // checkConnectivity only needs to verify all nodes are reachable from inputs (BFS)
        // No need to check output neurons redundantly if all nodes are visited.
        try checkConnectivity()
    }
    
    // MARK: - Topological Sort & Cycle Detection (Kahn's Algorithm)
    func topologicalOrder() throws -> [Neuron] {
        var localInDegree: [UUID: Int] = [:]
        for neuron in neurons.values {
            localInDegree[neuron.id] = neuron.incomingWeights.count
        }
        
        var order: [Neuron] = []
        var queue: [Neuron] = []
        
        for neuron in neurons.values where localInDegree[neuron.id] == 0 {
            queue.append(neuron)
        }
        
        while !queue.isEmpty {
            let current = queue.removeFirst()
            order.append(current)
            
            for weight in current.outgoingWeights {
                guard let neighbor = weight.to else { continue }
                localInDegree[neighbor.id]? -= 1
                if localInDegree[neighbor.id] == 0 {
                    queue.append(neighbor)
                }
            }
        }
        
        if order.count != neurons.count {
            throw GraphError.cycleDetected // Cycle detected (or disconnected components)
        }
        
        return order
    }
    
    // MARK: - Connectivity Check (BFS)
    private func checkConnectivity() throws {
        guard !inputNeurons.isEmpty else { return }

        let sources = inputNeurons + biasNeurons
        var queue = sources
        var visited = Set(sources.map(\.id))
        
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
                // If topologicalOrder succeeded, this implies no disconnected components.
                // If topologicalOrder detected a cycle, it already threw.
                // This check is mainly for unreachable nodes from input (which topologicalOrder might miss if there are cycles and other parts are reachable).
                // Or if some output neurons are not reachable from input.
                // However, since topologicalOrder() already ensures all nodes are part of the main graph or throws a cycle, 
                // this check needs to ensure all non-input neurons are reached.
                // For a proper DAG after topologicalOrder passes, all neurons are "reachable" from some source.
                // Revisit: If topologicalOrder passes, all nodes are reachable from SOME source. But not necessarily from *inputNeurons*.
                // The issue 2 was checking outputNeurons redundantly.
                // Let's refine this to check if ALL neurons (that are part of the graph) are reachable from specified inputNeurons.
                // If topologicalOrder() completed all neurons and no cycles, all must be reachable from *some* source.
                // This BFS must ensure reachability from *our input* to *all neurons in the graph*.
                // If a neuron is not visited after BFS from inputs, and it's not an input neuron, it's disconnected.
                if !inputNeurons.contains(where: { $0.id == neuron.id }) { // Exclude input neurons as they start the BFS
                    throw GraphError.disconnectedGraph // This BFS is needed for explicit "from inputs" reachability
                }
            }
        }
    }
    
    var output: [Double] {
        outputNeurons.map(\.value)
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
