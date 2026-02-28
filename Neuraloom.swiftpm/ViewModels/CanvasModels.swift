import SwiftUI

// MARK: - Canvas Enums

enum CanvasMode: String {
    case train, inference
}

enum PlaygroundMode: String, CaseIterable {
    case dev     = "Dev"
    case inspect = "Inspect"
}

enum NodeRole: String, CaseIterable {
    case hidden = "Hidden"
    case input  = "Input"
    case output = "Output"
    case bias   = "Bias"
}

// MARK: - Inference Input Source

enum InferenceInputSource: String, CaseIterable {
    case manual  = "Manual"
    case dataset = "Dataset"
}

// MARK: - Inference Input Info

struct InferenceInputInfo: Identifiable {
    let id = UUID()
    let label: String
    let portId: UUID
    let range: ClosedRange<Double>
}

// MARK: - Node View Model

struct NodeViewModel: Identifiable {
    enum NodeType: String, CaseIterable {
        case neuron = "Neuron"
        case dataset = "Dataset"
        case loss = "Loss"
        case visualization = "Viz"
        case outputDisplay = "Result"
        case number = "Number"
        case annotation = "Note"
        case scatterPlot = "Scatter"

        var icon: String {
            switch self {
            case .neuron:        return "circle.grid.3x3.fill"
            case .dataset:       return "tablecells.fill"
            case .loss:          return "target"
            case .visualization: return "chart.line.uptrend.xyaxis"
            case .outputDisplay: return "eye.circle.fill"
            case .number:        return "number"
            case .annotation:    return "note.text"
            case .scatterPlot:   return "chart.dots.scatter"
            }
        }
    }

    let id: UUID
    var position: CGPoint
    var type: NodeType
    var activation: ActivationType = .linear
    var role: NodeRole = .hidden
    var datasetConfig: DatasetNodeConfig?
    var lossConfig: LossNodeConfig?
    var scatterPlotConfig: ScatterPlotConfig?
    var scatterSeriesA: [(x: Double, y: Double)] = []
    var scatterSeriesB: [(x: Double, y: Double)] = []
    var outputDisplayValue: Double?
    var annotationText: String = "Note"
    var numberValue: Double = 0.0

    var isInput: Bool { role == .input }
    var isOutput: Bool { role == .output }
    var isBias: Bool  { role == .bias }
}

// MARK: - Connection View Model

struct ConnectionViewModel: Identifiable {
    let id: UUID = UUID()
    var sourceNodeId: UUID
    var targetNodeId: UUID
    var value: Double = 0.0
    var gradient: Double = 0.0
}

// MARK: - Drawable Connection

struct DrawableConnection: Identifiable {
    let id: UUID
    let from: CGPoint
    let to: CGPoint
    let value: Double
    let isUtilityLink: Bool
    var detourY: CGFloat?
}
