import Foundation

enum ActivationType {
    case linear
    case relu
    case sigmoid
    
    func forward(_ x: Double) -> Double {
        switch self {
        case .linear:
            return x
        case .relu:
            return max(0, x)
        case .sigmoid:
            return 1.0 / (1.0 + exp(-x))
        }
    }
    
    func backward(_ output: Double) -> Double {
        switch self {
        case .linear:
            return 1.0
        case .relu:
            return output > 0 ? 1.0 : 0.0
        case .sigmoid:
            return output * (1.0 - output)
        }
    }
}
