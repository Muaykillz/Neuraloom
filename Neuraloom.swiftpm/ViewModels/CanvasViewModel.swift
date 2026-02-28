import SwiftUI

@MainActor
class CanvasViewModel: ObservableObject {
    @Published var nodes: [NodeViewModel] = []
    @Published var connections: [ConnectionViewModel] = []

    @Published var scale: CGFloat = 1.0
    @Published var offset: CGSize = .zero
    var viewportSize: CGSize = .zero
    var viewportInsets: EdgeInsets = EdgeInsets()

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
    @Published var activeSampleTarget: [Double]? = nil
    @Published var stepCount = 0
    @Published var playgroundMode: PlaygroundMode = .dev {
        didSet {
            clearGlow()
            if playgroundMode == .inspect {
                fulfillTourCondition(.inspectModeOpened)
            }
        }
    }

    // MARK: - Tour Condition Tracking

    @Published var fulfilledTourConditions: Set<String> = []
    @Published var storyHideExitInference = false
    @Published var storyHideInferencePanel = false
    @Published var storyStepCounter: Int = 0
    @Published var storyLRChanged: Bool = false
    @Published var storyExpandTrainingPanel: Bool = false
    @Published var storySidebarOpen: Bool = false

    func fulfillTourCondition(_ condition: TourCompletionCondition) {
        fulfilledTourConditions.insert(condition.key)
    }

    func clearTourCondition(_ condition: TourCompletionCondition) {
        fulfilledTourConditions.remove(condition.key)
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
    @Published var predictAllMode: Bool = true
    @Published var autoPredict: Bool = false
    var inferenceAnimationScale: Double = 1.0
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

    init() {}

    // MARK: - Reset

    func resetCanvas() {
        nodes = []
        connections = []
        scale = 1.0
        offset = .zero
        activeWiringSource = nil
        wiringTargetPosition = nil
        hoveredNodeId = nil
        selectedNodeId = nil
        selectedConnectionId = nil
        connectionTapGlobalLocation = nil
        toastMessage = nil
        isTraining = false
        currentEpoch = 0
        currentLoss = nil
        lossHistory = []
        stepCount = 0
        activeSampleIndex = nil
        activeSampleTarget = nil
        stepPhase = nil
        glowingNodeIds = []
        glowingConnectionIds = []
        sampleLossAccumulator = []
        nodeOutputs = [:]
        nodeGradients = [:]
        fulfilledTourConditions = []
        storyHideExitInference = false
        storyHideInferencePanel = false
        storyStepCounter = 0
        storyLRChanged = false
        storyExpandTrainingPanel = false
        canvasMode = .train
        inferenceInputs = [:]
        inferenceInputInfos = []
        inferenceOutputNodeIds = []
        autoOutputDisplayIds = []
        inferenceTemporaryNodeIds = []
        inferenceTemporaryConnectionIds = []
        isPredicting = false
        canvasOpacity = 1.0
        inferenceInputSource = .manual
        inferenceDatasetRowIndex = 0
        autoPredict = false
        inferenceAnimationScale = 1.0
        compiledInferenceNetwork = nil
        playgroundMode = .dev
        lastMagnification = 1.0
        previousTranslation = .zero
        sampleTrainingTimer?.invalidate()
        sampleTrainingTimer = nil
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

    // MARK: - Chapter 1: Hello, Neuron

    func setupChapter1Scenario() {
        let ids = Chapter1IDs.self

        var numberNode = NodeViewModel(id: ids.numberIn, position: CGPoint(x: -100, y: 300), type: .number)
        numberNode.numberValue = 3.0

        nodes = [
            numberNode,
            NodeViewModel(id: ids.inputX1, position: CGPoint(x: 100, y: 300), type: .neuron, activation: .linear, role: .input),
            NodeViewModel(id: ids.bias1, position: CGPoint(x: 100, y: 450), type: .neuron, activation: .linear, role: .bias),
            NodeViewModel(id: ids.neuronOut, position: CGPoint(x: 400, y: 350), type: .neuron, activation: .linear, role: .output),
        ]

        addConnection(from: ids.numberIn, to: ids.inputX1)
        addConnection(id: ids.weightW, from: ids.inputX1, to: ids.neuronOut, value: 0.5)
        addConnection(id: ids.weightB, from: ids.bias1, to: ids.neuronOut, value: 0.0)

        // Enter inference mode so the Result node is auto-created
        enterInferenceMode()
    }

    // MARK: - Chapter 2: The Art of Learning

    func setupChapter2Scenario() {
        let ids = Chapter2IDs.self

        var dsConfig = DatasetNodeConfig(preset: .linear)
        dsConfig.columnPortIds = [ids.dsPortX, ids.dsPortY]

        let lossConfig = LossNodeConfig(predPortId: ids.lossPred, truePortId: ids.lossTrue)

        nodes = [
            {
                var n = NodeViewModel(id: ids.dataset, position: CGPoint(x: -150, y: 300), type: .dataset)
                n.datasetConfig = dsConfig
                return n
            }(),
            NodeViewModel(id: ids.inputX1, position: CGPoint(x: 100, y: 300), type: .neuron, activation: .linear, role: .input),
            NodeViewModel(id: ids.bias1, position: CGPoint(x: 100, y: 450), type: .neuron, activation: .linear, role: .bias),
            NodeViewModel(id: ids.neuronOut, position: CGPoint(x: 400, y: 350), type: .neuron, activation: .linear, role: .output),
            {
                var n = NodeViewModel(id: ids.loss1, position: CGPoint(x: 600, y: 350), type: .loss)
                n.lossConfig = lossConfig
                return n
            }(),
            NodeViewModel(id: ids.viz1, position: CGPoint(x: 850, y: 350), type: .visualization)
        ]

        // Dataset[X] → Input
        addConnection(from: ids.dsPortX, to: ids.inputX1)
        // Input → Output (weight W)
        addConnection(id: ids.weightW, from: ids.inputX1, to: ids.neuronOut, value: 0.5)
        // Bias → Output (weight B)
        addConnection(id: ids.weightB, from: ids.bias1, to: ids.neuronOut, value: 0.0)
        // Output → Loss[ŷ]
        addConnection(from: ids.neuronOut, to: ids.lossPred)
        // Dataset[Y] → Loss[y]
        addConnection(from: ids.dsPortY, to: ids.lossTrue)
        // Loss → Viz
        addConnection(from: ids.loss1, to: ids.viz1)

        // Inspect mode: teaching concepts, not building
        playgroundMode = .inspect
        totalEpochs = 20
        storyStepCounter = 0
        storyLRChanged = false
    }

    // MARK: - Chapter 3: Build-Your-Own

    func setupChapter3Scenario() {
        let ids = Chapter3IDs.self

        var dsConfig = DatasetNodeConfig(preset: .linear)
        dsConfig.columnPortIds = [ids.dsPortX, ids.dsPortY]

        nodes = [
            {
                var n = NodeViewModel(id: ids.dataset, position: CGPoint(x: -150, y: 350), type: .dataset)
                n.datasetConfig = dsConfig
                return n
            }()
        ]

        connections = []
        playgroundMode = .dev
        totalEpochs = 20
        storyStepCounter = 0
        storyLRChanged = false
    }

    // MARK: - Linear Regression Demo

    func setupLinearRegressionDemo() {
        let inId = UUID(); let outId = UUID()
        let dsId = UUID(); let lossId = UUID(); let vizId = UUID()
        let biasId = UUID()
        let dsConfig = DatasetNodeConfig(preset: .linear)
        let lossConfig = LossNodeConfig()

        nodes = [
            NodeViewModel(id: inId, position: CGPoint(x: 100, y: 300), type: .neuron, activation: .linear, role: .input),
            NodeViewModel(id: outId, position: CGPoint(x: 400, y: 300), type: .neuron, activation: .linear, role: .output),
            NodeViewModel(id: biasId, position: CGPoint(x: 100, y: 450), type: .neuron, activation: .linear, role: .bias),
            {
                var n = NodeViewModel(id: dsId, position: CGPoint(x: -150, y: 300), type: .dataset)
                n.datasetConfig = dsConfig
                return n
            }(),
            {
                var n = NodeViewModel(id: lossId, position: CGPoint(x: 600, y: 300), type: .loss)
                n.lossConfig = lossConfig
                return n
            }(),
            NodeViewModel(id: vizId, position: CGPoint(x: 850, y: 300), type: .visualization)
        ]

        addConnection(from: inId, to: outId)
        addConnection(from: biasId, to: outId)

        addConnection(from: dsConfig.columnPortIds[0], to: inId)

        addConnection(from: outId, to: lossConfig.predPortId)
        addConnection(from: dsConfig.columnPortIds[1], to: lossConfig.truePortId)

        addConnection(from: lossId, to: vizId)
    }
}
