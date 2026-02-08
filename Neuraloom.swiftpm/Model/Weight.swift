import Foundation

class Weight: Identifiable, Hashable {
    let id: UUID
    var value: Double
    var gradient: Double
    
    weak var from: Neuron?
    weak var to: Neuron?
    
    init(from: Neuron, to: Neuron, initialValue: Double?) {
        self.id = UUID()
        self.from = from
        self.to = to
        self.gradient = 0.0
        
        if let initialValue = initialValue {
            self.value = initialValue
        } else {
            // Xavier-ish Initialization: helps small networks converge
            // For XOR, we need weights to be strong enough to activate neurons
            self.value = Double.random(in: -1.0...1.0)
        }
    }
    
    func resetGradient() {
        gradient = 0.0
    }
    
    // MARK: - Hashable Conformance
    static func == (lhs: Weight, rhs: Weight) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}