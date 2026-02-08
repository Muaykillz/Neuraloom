import Foundation

func runTrainingTests() {
    print("\n--- Running Task 5: Training Tests ---")
    
    // MARK: - Test 1: Linear Regression
    do {
        print("\n[Test 1] Linear Regression (y = 2x + 1)")
        let graph = ComputationGraph()
        let input = graph.addNeuron(activation: .linear)
        let bias = graph.addNeuron(activation: .linear)
        let output = graph.addNeuron(activation: .linear)
        
        let _ = graph.connect(from: input, to: output, initialWeightValue: 0.5)
        let _ = graph.connect(from: bias, to: output, initialWeightValue: 0.0)
        
        graph.setInputs([input, bias])
        graph.setOutputs([output])
        
        var data: [([Double], [Double])] = []
        for x in stride(from: 0.0, through: 5.0, by: 0.5) {
            data.append(([x, 1.0], [2.0 * x + 1.0]))
        }
        
        let optimizer = SGDOptimizer(learningRate: 0.05)
        let losses = try graph.train(data: data, epochs: 100, lossFunction: .mse, optimizer: optimizer, batchSize: 4, verbose: false)
        
        let finalLoss = losses.last ?? 1.0
        print("Final Loss: \(String(format: "%.6f", finalLoss))")
        
        try graph.forward(input: [3.0, 1.0])
        let prediction = graph.output[0]
        print("Pred for x=3.0: \(String(format: "%.4f", prediction)) (Expected ~7.0)")
        
        if finalLoss < 0.1 && abs(prediction - 7.0) < 0.2 {
            print("✅ Test 1 Passed")
        } else {
            print("❌ Test 1 Failed")
        }
    } catch {
        print("❌ Test 1 Error: \(error)")
    }
    
    // MARK: - Test 2: Binary Classification
    do {
        print("\n[Test 2] Binary Classification (Linearly Separable)")
        let graph = ComputationGraph()
        let x1 = graph.addNeuron(activation: .linear)
        let x2 = graph.addNeuron(activation: .linear)
        let bias = graph.addNeuron(activation: .linear)
        let output = graph.addNeuron(activation: .sigmoid)
        
        let _ = graph.connect(from: x1, to: output)
        let _ = graph.connect(from: x2, to: output)
        let _ = graph.connect(from: bias, to: output)
        
        graph.setInputs([x1, x2, bias])
        graph.setOutputs([output])
        
        let data: [([Double], [Double])] = [
            ([0.0, 0.0, 1.0], [0.0]),
            ([0.0, 1.0, 1.0], [0.0]),
            ([1.0, 0.0, 1.0], [0.0]),
            ([1.0, 1.0, 1.0], [1.0])
        ]
        
        let optimizer = SGDOptimizer(learningRate: 0.5)
        let losses = try graph.train(data: data, epochs: 200, lossFunction: .mse, optimizer: optimizer, batchSize: 1, verbose: false)
        
        let finalLoss = losses.last ?? 1.0
        print("Final Loss: \(String(format: "%.6f", finalLoss))")
        
        if finalLoss < 0.3 {
            print("✅ Test 2 Passed")
        } else {
            print("❌ Test 2 Failed")
        }
    } catch {
        print("❌ Test 2 Error: \(error)")
    }
    
    // MARK: - Test 3: XOR Problem
    do {
        print("\n[Test 3] XOR Problem (2-2-1)")
        let graph = ComputationGraph()
        let i1 = graph.addNeuron(activation: .linear)
        let i2 = graph.addNeuron(activation: .linear)
        let bias = graph.addNeuron(activation: .linear)
        
        let h1 = graph.addNeuron(activation: .relu)
        let h2 = graph.addNeuron(activation: .relu)
        let o1 = graph.addNeuron(activation: .sigmoid)
        
        // Connections
        let _ = graph.connect(from: i1, to: h1); let _ = graph.connect(from: i1, to: h2)
        let _ = graph.connect(from: i2, to: h1); let _ = graph.connect(from: i2, to: h2)
        let _ = graph.connect(from: bias, to: h1); let _ = graph.connect(from: bias, to: h2)
        let _ = graph.connect(from: h1, to: o1); let _ = graph.connect(from: h2, to: o1)
        let _ = graph.connect(from: bias, to: o1)
        
        graph.setInputs([i1, i2, bias])
        graph.setOutputs([o1])
        
        let xorData: [([Double], [Double])] = [
            ([0.0, 0.0, 1.0], [0.0]), ([0.0, 1.0, 1.0], [1.0]),
            ([1.0, 0.0, 1.0], [1.0]), ([1.0, 1.0, 1.0], [0.0])
        ]
        
        // ReLU needs slightly more careful training or more epochs
        let optimizer = SGDOptimizer(learningRate: 0.1)
        let losses = try graph.train(data: xorData, epochs: 700, lossFunction: .mse, optimizer: optimizer, batchSize: 1, verbose: false)
        
        let finalLoss = losses.last ?? 1.0
        print("Final Loss: \(String(format: "%.6f", finalLoss))")
        
        var solved = true
        for (input, target) in xorData {
            try graph.forward(input: input)
            let pred = graph.output[0]
            if target[0] == 0.0 && pred >= 0.2 { solved = false }
            if target[0] == 1.0 && pred <= 0.8 { solved = false }
            print("  [\(Int(input[0])), \(Int(input[1]))] -> \(String(format: "%.4f", pred))")
        }
        
        if solved && finalLoss < 0.1 {
            print("✅ Test 3 Passed")
        } else {
            print("❌ Test 3 Failed")
        }
    } catch {
        print("❌ Test 3 Error: \(error)")
    }
}
