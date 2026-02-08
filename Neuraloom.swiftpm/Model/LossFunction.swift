import Foundation
import Accelerate

enum LossFunction {
    case mse
    case crossEntropy
    
    // Compute the loss value
    func compute(predicted: [Double], target: [Double]) -> Double {
        guard predicted.count == target.count else { return 0.0 }
        let n = vDSP_Length(predicted.count)
        
        switch self {
        case .mse:
            var diff = [Double](repeating: 0.0, count: Int(n))
            vDSP_vsubD(target, 1, predicted, 1, &diff, 1, n)
            var squaredDiff = [Double](repeating: 0.0, count: Int(n))
            vDSP_vsqD(diff, 1, &squaredDiff, 1, n)
            var sum: Double = 0.0
            vDSP_sveD(squaredDiff, 1, &sum, n)
            return sum / Double(n)
            
        case .crossEntropy:
            var totalLoss: Double = 0.0
            for i in 0..<Int(n) {
                let p = max(1e-7, min(1.0 - 1e-7, predicted[i]))
                let t = target[i]
                let term = t * log(p) + (1.0 - t) * log(1.0 - p)
                totalLoss -= term
            }
            return totalLoss / Double(n)
        }
    }
    
    // Compute the gradient of the loss function w.r.t predicted output (dL/dy)
    func gradient(predicted: [Double], target: [Double]) -> [Double] {
        guard predicted.count == target.count else { return [] }
        let n = vDSP_Length(predicted.count)
        var gradients = [Double](repeating: 0.0, count: Int(n))
        
        switch self {
        case .mse:
            // Gradient of MSE: (2/n) * (predicted - target)
            vDSP_vsubD(target, 1, predicted, 1, &gradients, 1, n)
            var factor = 2.0 / Double(n)
            vDSP_vsmulD(gradients, 1, &factor, &gradients, 1, n)
            
        case .crossEntropy:
            // Gradient of BCE: (p - t) / (p * (1 - p))
            for i in 0..<Int(n) {
                let p = max(1e-7, min(1.0 - 1e-7, predicted[i]))
                let t = target[i]
                gradients[i] = (p - t) / (p * (1.0 - p))
            }
        }
        
        return gradients
    }
}
