import Foundation
import Accelerate

class SGDOptimizer {
    let learningRate: Double
    let maxGradientNorm: Double
    
    init(learningRate: Double, maxGradientNorm: Double = .infinity) {
        self.learningRate = learningRate
        self.maxGradientNorm = maxGradientNorm
    }
    
    func step(weights: [Weight], batchSize: Int) {
        guard !weights.isEmpty else { return }
        
        let n = vDSP_Length(weights.count)
        var weightValues = weights.map { $0.value }
        var gradients = weights.map { $0.gradient }
        
        // Clipping only if finite
        if maxGradientNorm.isFinite {
            var minLimit = -maxGradientNorm
            var maxLimit = maxGradientNorm
            vDSP_vclipD(gradients, 1, &minLimit, &maxLimit, &gradients, 1, n)
        }
        
        // Update
        var updateVector = [Double](repeating: 0.0, count: Int(n))
        var stepSize = -learningRate / Double(batchSize)
        
        vDSP_vsmulD(gradients, 1, &stepSize, &updateVector, 1, n)
        vDSP_vaddD(weightValues, 1, updateVector, 1, &weightValues, 1, n)
        
        for (index, weight) in weights.enumerated() {
            weight.value = weightValues[index]
        }
    }
}
