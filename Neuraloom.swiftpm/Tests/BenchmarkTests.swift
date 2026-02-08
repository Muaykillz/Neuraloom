import Foundation
import Accelerate

func runBenchmarkTests() {
    print("\n--- Running Task 5: FULL TRAINING CYCLE Benchmark (Ultimate Proof) ---")
    
    let layers = 10
    let neuronsPerLayer = 100
    let totalNodes = layers * neuronsPerLayer
    let bulkIterations = 50 
    let learningRate = 0.01
    
    print("[Test 4] Full Training (Forward + Backward + Update)")
    print("  Layers: \(layers), Nodes/Layer: \(neuronsPerLayer), Total Weights: \( (layers - 1) * neuronsPerLayer * neuronsPerLayer )")
    
    // --- Setup ExecutionModel ---
    let nodeValues = [Double](repeating: 0.0, count: totalNodes)
    let nodeActivations: [ActivationType] = (0..<totalNodes).map { _ in .relu }
    var weightValues: [Double] = []
    var nodeIncoming = [[Int]](repeating: [], count: totalNodes)
    var edgeSource = [Int]()
    
    var weightIdx = 0
    for l in 0..<(layers - 1) {
        let startSrc = l * neuronsPerLayer
        let startDst = (l + 1) * neuronsPerLayer
        for dst in startDst..<(startDst + neuronsPerLayer) {
            for src in startSrc..<(startSrc + neuronsPerLayer) {
                weightValues.append(0.01)
                edgeSource.append(src)
                nodeIncoming[dst].append(weightIdx)
                weightIdx += 1
            }
        }
    }
    
    let inputIndices = Array(0..<neuronsPerLayer)
    let outputIndices = Array((totalNodes - neuronsPerLayer)..<totalNodes)
    let topoIndices = Array(0..<totalNodes)
    
    var model = ExecutionModel(
        nodeValues: nodeValues,
        nodeGradients: [Double](repeating: 0.0, count: totalNodes),
        nodeActivations: nodeActivations,
        weightValues: weightValues,
        weightGradients: [Double](repeating: 0.0, count: weightValues.count),
        nodeIncomingEdgeIndices: nodeIncoming,
        nodeOutgoingEdgeIndices: [[Int]](repeating: [], count: totalNodes),
        edgeSourceNodeIndices: edgeSource,
        weightIDMap: [],
        nodeIDMap: (0..<totalNodes).map { _ in UUID() },
        inputNodeIndices: inputIndices,
        outputNodeIndices: outputIndices,
        topologicalNodeIndices: topoIndices
    )
    
    let data = [([Double](repeating: 1.0, count: neuronsPerLayer), [Double](repeating: 1.0, count: neuronsPerLayer))]
    
    // --- Scenario A: Object Graph FULL Training ---
    class MockNode {
        var value: Double = 0.0; var grad: Double = 0.0
        var incoming: [MockWeight] = []
        var activation: ActivationType = .relu
    }
    class MockWeight { 
        var value: Double = 0.01; var grad: Double = 0.0
        unowned var from: MockNode; unowned var to: MockNode
        init(from: MockNode, to: MockNode) { self.from = from; self.to = to }
    }
    
    let mockNodes: [MockNode] = (0..<totalNodes).map { _ in MockNode() }
    var tempWeights: [MockWeight] = []
    for l in 0..<(layers - 1) {
        let startSrc = l * neuronsPerLayer
        let startDst = (l + 1) * neuronsPerLayer
        for dst in startDst..<(startDst + neuronsPerLayer) {
            for src in startSrc..<(startSrc + neuronsPerLayer) {
                let w = MockWeight(from: mockNodes[src], to: mockNodes[dst])
                tempWeights.append(w)
                mockNodes[dst].incoming.append(w)
            }
        }
    }
    let mockWeights = tempWeights
    
    let startA = CFAbsoluteTimeGetCurrent()
    for _ in 0..<bulkIterations {
        for (input, target) in data {
            // 1. Forward
            for i in 0..<totalNodes {
                let n = mockNodes[i]
                if n.incoming.isEmpty { 
                    if i < input.count { n.value = input[i] }
                    continue 
                }
                var sum = 0.0
                for w in n.incoming { sum += w.from.value * w.value }
                n.value = n.activation.forward(sum)
            }
            
            // 2. Backward
            for (i, idx) in outputIndices.enumerated() {
                mockNodes[idx].grad = mockNodes[idx].value - target[i] 
            }
            for i in (0..<totalNodes).reversed() {
                let n = mockNodes[i]
                let localGrad = n.activation.backward(n.value) * n.grad
                for w in n.incoming {
                    w.grad += localGrad * w.from.value
                    w.from.grad += localGrad * w.value
                }
            }
            
            // 3. Update
            for w in mockWeights {
                w.value -= learningRate * w.grad
                w.grad = 0
            }
            for n in mockNodes { n.grad = 0 }
        }
    }
    let timeA = CFAbsoluteTimeGetCurrent() - startA
    print("\nScenario A (Object FULL Training): \(String(format: "%.4f", timeA))s")
    
    // --- Scenario B: ExecutionEngine FULL Training ---
    let startB = CFAbsoluteTimeGetCurrent()
    ExecutionEngine.train(model: &model, data: data, epochs: bulkIterations, learningRate: learningRate, lossFunction: .mse, verbose: false)
    let timeB = CFAbsoluteTimeGetCurrent() - startB
    print("Scenario B (Engine FULL Training): \(String(format: "%.4f", timeB))s")
    
    print("\nSpeedup for Full Training: \(String(format: "%.2fx", timeA / timeB))")
    
    if timeA / timeB > 1.0 {
        print("✅ Success: ExecutionEngine is faster for real-world training workloads!")
    } else {
        print("⚠️ Warning: ExecutionEngine is not faster than Object-based in this scenario.")
    }
}
