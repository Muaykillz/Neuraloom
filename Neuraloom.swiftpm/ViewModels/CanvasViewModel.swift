import SwiftUI

@MainActor
class CanvasViewModel: ObservableObject {
    @Published var nodes: [NodeViewModel] = []
    @Published var connections: [ConnectionViewModel] = []

    @Published var scale: CGFloat = 1.0
    @Published var offset: CGSize = .zero

    @Published var activeWiringSource: UUID? = nil
    @Published var wiringTargetPosition: CGPoint? = nil
    @Published var hoveredNodeId: UUID? = nil

    @Published var selectedNodeId: UUID? = nil
    @Published var selectedConnectionId: UUID? = nil
    @Published var connectionTapGlobalLocation: CGPoint? = nil

    @Published var toastMessage: String? = nil

    // MARK: - Training State

    @Published var isTraining = false
    @Published var currentEpoch = 0
    @Published var totalEpochs = 500
    @Published var learningRate: Double = 0.1
    @Published var selectedLossFunction: LossFunction = .mse
    @Published var currentLoss: Double? = nil
    @Published var lossHistory: [Double] = []
    @Published var stepGranularity: StepGranularity = .epoch
    @Published var activeSampleIndex: Int? = nil
    @Published var stepCount = 0
    @Published var playgroundMode: PlaygroundMode = .dev {
        didSet { clearGlow() }
    }
    var inspectMode: Bool { playgroundMode == .inspect }
    @Published var nodeOutputs: [UUID: Double] = [:]
    @Published var nodeGradients: [UUID: Double] = [:]
    @Published var stepPhase: StepPhase? = nil
    @Published var glowingNodeIds: Set<UUID> = []
    @Published var glowingConnectionIds: Set<UUID> = []
    var sampleLossAccumulator: [Double] = []

    // MARK: - Inference Mode State

    @Published var canvasMode: CanvasMode = .train
    @Published var inferenceInputs: [UUID: Double] = [:]
    @Published var inferenceInputInfos: [InferenceInputInfo] = []
    @Published var inferenceOutputNodeIds: [UUID] = []
    @Published var autoOutputDisplayIds: [UUID] = []
    var inferenceTemporaryNodeIds: Set<UUID> = []
    var inferenceTemporaryConnectionIds: Set<UUID> = []
    @Published var isPredicting = false
    @Published var canvasOpacity: Double = 1.0
    @Published var inferenceInputSource: InferenceInputSource = .manual
    @Published var inferenceDatasetRowIndex: Int = 0
    var savedPlaygroundMode: PlaygroundMode = .dev
    var savedSelectedNodeId: UUID?
    var savedSelectedConnectionId: UUID?
    var compiledInferenceNetwork: TrainingService.CompiledNetwork?

    let trainingService = TrainingService()

    // MARK: - Gesture State

    var lastMagnification: CGFloat = 1.0
    var previousTranslation: CGSize = .zero
    var sampleTrainingTimer: Timer?

    init() {
        setupMVPScenario()
    }

    // MARK: - MVP Setup

    func setupMVPScenario() {
        let i1Id = UUID(); let i2Id = UUID(); let h1Id = UUID(); let h2Id = UUID(); let o1Id = UUID()
        let dsId = UUID(); let lossId = UUID(); let vizId = UUID()
        let dsConfig = DatasetNodeConfig(preset: .xor)
        let lossConfig = LossNodeConfig()

        nodes = [
            NodeViewModel(id: i1Id, position: CGPoint(x: 100, y: 200), type: .neuron, activation: .linear, role: .input),
            NodeViewModel(id: i2Id, position: CGPoint(x: 100, y: 400), type: .neuron, activation: .linear, role: .input),
            NodeViewModel(id: h1Id, position: CGPoint(x: 300, y: 200), type: .neuron, activation: .relu),
            NodeViewModel(id: h2Id, position: CGPoint(x: 300, y: 400), type: .neuron, activation: .relu),
            NodeViewModel(id: o1Id, position: CGPoint(x: 500, y: 300), type: .neuron, activation: .sigmoid, role: .output),
            {
                var n = NodeViewModel(id: dsId, position: CGPoint(x: -150, y: 300), type: .dataset)
                n.datasetConfig = dsConfig
                return n
            }(),
            {
                var n = NodeViewModel(id: lossId, position: CGPoint(x: 700, y: 300), type: .loss)
                n.lossConfig = lossConfig
                return n
            }(),
            NodeViewModel(id: vizId, position: CGPoint(x: 950, y: 300), type: .visualization)
        ]

        addConnection(from: i1Id, to: h1Id); addConnection(from: i1Id, to: h2Id)
        addConnection(from: i2Id, to: h1Id); addConnection(from: i2Id, to: h2Id)
        addConnection(from: h1Id, to: o1Id); addConnection(from: h2Id, to: o1Id)

        addConnection(from: dsConfig.columnPortIds[0], to: i1Id)
        addConnection(from: dsConfig.columnPortIds[1], to: i2Id)

        addConnection(from: o1Id, to: lossConfig.predPortId)
        addConnection(from: dsConfig.columnPortIds[2], to: lossConfig.truePortId)

        addConnection(from: lossId, to: vizId)
    }
}
