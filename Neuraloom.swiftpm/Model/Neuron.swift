import Foundation

class Neuron: Identifiable, Hashable {
    let id: UUID
    var value: Double // Activation output
    var gradient: Double // dL/dvalue for backprop
    let activation: ActivationType
    
    var incomingWeights: [Weight] = []
    var outgoingWeights: [Weight] = []
    
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
}
