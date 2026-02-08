import Foundation

class Neuron: Identifiable, Hashable {
    let id: UUID
    var value: Double // Activation output
    var gradient: Double // dL/dvalue for backprop
    let activation: ActivationType
    
    var incomingWeights: [Weight] = []
    var outgoingWeights: [Weight] = []
    
    // For topological sort and cycle detection
    var visitedState: VisitedState = .unvisited
    var inDegree: Int = 0
    
    init(activation: ActivationType, id: UUID = UUID()) {
        self.id = id
        self.value = 0.0
        self.gradient = 0.0
        self.activation = activation
    }
    
    // MARK: - Hashable Conformance
    static func == (lhs: Neuron, rhs: Neuron) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: - Core Logic
    func computeOutput() {
        guard !isInput else { return } // Input neurons' values are set externally
        
        var sum: Double = 0.0
        for weight in incomingWeights {
            guard let fromNeuron = weight.from else {
                // This should not happen if graph integrity is maintained
                print("Warning: Incoming weight \(weight.id) has no 'from' neuron.")
                continue
            }
            sum += fromNeuron.value * weight.value
        }
        
        self.value = activation.forward(sum)
    }
    
    func backpropagate() {
        // Only non-input neurons compute activation derivative based on their output
        // Input neurons don't have an activation function to differentiate
        guard !isInput else { return }
        
        let activationGrad = activation.backward(value) // Derivative w.r.t. activated output
        let neuronGradient = self.gradient * activationGrad // dL/d(sum_input) = dL/d(output) * d(output)/d(sum_input)
        
        for weight in incomingWeights {
            guard let fromNeuron = weight.from else {
                print("Warning: Incoming weight \(weight.id) has no 'from' neuron.")
                continue
            }
            
            // dL/dw = dL/d(sum_input) * d(sum_input)/dw = neuronGradient * fromNeuron.value
            weight.gradient += neuronGradient * fromNeuron.value
            
            // dL/d(from_neuron_output) = dL/d(sum_input) * d(sum_input)/d(from_neuron_output) = neuronGradient * weight.value
            fromNeuron.gradient += neuronGradient * weight.value
        }
    }
    
    func resetGradient() {
        gradient = 0.0
    }
    
    var isInput: Bool { incomingWeights.isEmpty }
    var isOutput: Bool { outgoingWeights.isEmpty }
}

enum VisitedState: Int {
    case unvisited
    case visiting // In current DFS path (gray)
    case visited // Finished DFS path (black)
}
