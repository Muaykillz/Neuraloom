import Foundation
import Accelerate

// MARK: - Execution Data Structure (SoA)
struct ExecutionModel {
    var nodeValues: [Double]
    var nodeGradients: [Double]
    let nodeActivations: [ActivationType]
    
    var weightValues: [Double]
    var weightGradients: [Double]
    
    let nodeIncomingEdgeIndices: [[Int]]
    let nodeOutgoingEdgeIndices: [[Int]]
    
    let edgeSourceNodeIndices: [Int]
    
    let weightIDMap: [UUID]
    let nodeIDMap: [UUID]
    
    let inputNodeIndices: [Int]
    let outputNodeIndices: [Int]
    let topologicalNodeIndices: [Int]
}

// MARK: - The Engine
class ExecutionEngine {
    
    // MARK: - Compilation
    static func compile(graph: ComputationGraph) throws -> ExecutionModel {
        let nodes = Array(graph.neurons.values)
        var nodeIndexMap: [UUID: Int] = [:]
        for (i, node) in nodes.enumerated() { nodeIndexMap[node.id] = i }
        
        let weights = Array(graph.weights.values)
        
        var nodeIncoming = [[Int]](repeating: [], count: nodes.count)
        var nodeOutgoing = [[Int]](repeating: [], count: nodes.count)
        var edgeSource = [Int](repeating: 0, count: weights.count)
        
        for (wIdx, weight) in weights.enumerated() {
            guard let from = weight.from, let to = weight.to,
                  let fromIdx = nodeIndexMap[from.id],
                  let toIdx = nodeIndexMap[to.id] else { continue }
            
            edgeSource[wIdx] = fromIdx
            nodeIncoming[toIdx].append(wIdx)
            nodeOutgoing[fromIdx].append(wIdx)
        }
        
        return ExecutionModel(
            nodeValues: nodes.map { $0.value },
            nodeGradients: [Double](repeating: 0.0, count: nodes.count),
            nodeActivations: nodes.map { $0.activation },
            weightValues: weights.map { $0.value },
            weightGradients: [Double](repeating: 0.0, count: weights.count),
            nodeIncomingEdgeIndices: nodeIncoming,
            nodeOutgoingEdgeIndices: nodeOutgoing,
            edgeSourceNodeIndices: edgeSource,
            weightIDMap: weights.map { $0.id },
            nodeIDMap: nodes.map { $0.id },
            inputNodeIndices: graph.inputNeurons.compactMap { nodeIndexMap[$0.id] },
            outputNodeIndices: graph.outputNeurons.compactMap { nodeIndexMap[$0.id] },
            topologicalNodeIndices: try graph.topologicalOrder().compactMap { nodeIndexMap[$0.id] }
        )
    }
    
    // MARK: - Training
    @discardableResult
    static func train(
        model: inout ExecutionModel,
        data: [([Double], [Double])],
        epochs: Int,
        learningRate: Double,
        lossFunction: LossFunction,
        verbose: Bool = true
    ) -> [Double] {
        var lossHistory: [Double] = []
        
        for epoch in 1...epochs {
            var totalLoss: Double = 0.0
            
            for (input, target) in data {
                predict(model: &model, input: input)
                
                let outputValues = model.outputNodeIndices.map { model.nodeValues[$0] }
                totalLoss += lossFunction.compute(predicted: outputValues, target: target)
                
                let outputGradients = lossFunction.gradient(predicted: outputValues, target: target)
                computeBackward(model: &model, targetGradients: outputGradients)
                
                var step = -learningRate
                let weightCount = vDSP_Length(model.weightValues.count)
                if weightCount > 0 {
                    vDSP_vsmaD(model.weightGradients, 1, &step, model.weightValues, 1, &model.weightValues, 1, weightCount)
                    vDSP_vclrD(&model.weightGradients, 1, weightCount)
                    vDSP_vclrD(&model.nodeGradients, 1, vDSP_Length(model.nodeValues.count))
                }
            }
            
            let avgLoss = totalLoss / Double(data.count)
            lossHistory.append(avgLoss)
            if verbose && (epoch % 100 == 0 || epoch == 1) {
                print("Epoch \(epoch): Loss \(String(format: "%.6f", avgLoss))")
            }
        }
        return lossHistory
    }
    
    // MARK: - Inference
    static func predict(model: inout ExecutionModel, input: [Double]) {
        for (i, idx) in model.inputNodeIndices.enumerated() {
            if i < input.count { model.nodeValues[idx] = input[i] }
        }
        
        for nodeIdx in model.topologicalNodeIndices {
            let incomingEdges = model.nodeIncomingEdgeIndices[nodeIdx]
            if incomingEdges.isEmpty { continue }

            var sum: Double = 0.0
            for wIdx in incomingEdges {
                let sourceNodeIdx = model.edgeSourceNodeIndices[wIdx]
                sum += model.nodeValues[sourceNodeIdx] * model.weightValues[wIdx]
            }
            
            model.nodeValues[nodeIdx] = model.nodeActivations[nodeIdx].forward(sum)
        }
    }
    
    // MARK: - Core Math (Private)
    private static func computeBackward(model: inout ExecutionModel, targetGradients: [Double]) {
        for (i, nodeIdx) in model.outputNodeIndices.enumerated() {
            if i < targetGradients.count { model.nodeGradients[nodeIdx] = targetGradients[i] }
        }
        
        for nodeIdx in model.topologicalNodeIndices.reversed() {
            let localGrad = model.nodeActivations[nodeIdx].backward(model.nodeValues[nodeIdx]) * model.nodeGradients[nodeIdx]
            
            let incomingEdges = model.nodeIncomingEdgeIndices[nodeIdx]
            for wIdx in incomingEdges {
                let sourceNodeIdx = model.edgeSourceNodeIndices[wIdx]
                model.weightGradients[wIdx] += localGrad * model.nodeValues[sourceNodeIdx]
                model.nodeGradients[sourceNodeIdx] += localGrad * model.weightValues[wIdx]
            }
        }
    }
    
    static func syncBack(from model: ExecutionModel, to graph: ComputationGraph) {
        for (i, wID) in model.weightIDMap.enumerated() {
            graph.weights[wID]?.value = model.weightValues[i]
        }
        for (i, nID) in model.nodeIDMap.enumerated() {
            graph.neurons[nID]?.value = model.nodeValues[i]
        }
    }
}
