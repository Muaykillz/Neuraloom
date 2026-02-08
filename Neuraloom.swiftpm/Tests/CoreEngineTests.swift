import Foundation

func runAllCoreEngineTests() {
    print("\\n--- Running All Core Engine Tests ---")

    // MARK: - Test 1: Simple Pass-Through (2 neurons)
    do {
        let graph = ComputationGraph()

        let n1 = graph.addNeuron(activation: .linear)
        let n2 = graph.addNeuron(activation: .linear)

        let _ = graph.connect(from: n1, to: n2, initialWeightValue: 2.0)

        graph.setInputs([n1])
        graph.setOutputs([n2])

        try graph.validate()
        try graph.forward(input: [3.0])

        assert(abs(n2.value - 6.0) < 0.0001, "Test 1 Failed: Simple pass-through - Expected 6.0, got \(n2.value)")
        print("✅ Test 1 passed: Simple pass-through")
    } catch {
        print("❌ Test 1 Failed: Simple pass-through - \\(error.localizedDescription)")
    }

    // MARK: - Test 2: ReLU Activation
    do {
        let graph = ComputationGraph()

        let n1 = graph.addNeuron(activation: .linear)
        let n2 = graph.addNeuron(activation: .relu)

        let _ = graph.connect(from: n1, to: n2, initialWeightValue: 1.0)

        graph.setInputs([n1])
        graph.setOutputs([n2])

        try graph.validate()

        // Test positive
        try graph.forward(input: [5.0])
        assert(abs(n2.value - 5.0) < 0.0001, "Test 2 Failed: ReLU positive - Expected 5.0, got \(n2.value)")

        // Test negative (should clamp to 0)
        try graph.forward(input: [-3.0])
        assert(abs(n2.value - 0.0) < 0.0001, "Test 2 Failed: ReLU negative - Expected 0.0, got \(n2.value)")

        print("✅ Test 2 passed: ReLU activation")
    } catch {
        print("❌ Test 2 Failed: ReLU activation - \\(error.localizedDescription)")
    }

    // MARK: - Test 3: Two Inputs → One Output (Simple Sum)
    do {
        let graph = ComputationGraph()

        let n1 = graph.addNeuron(activation: .linear)
        let n2 = graph.addNeuron(activation: .linear)
        let n3 = graph.addNeuron(activation: .linear)

        let _ = graph.connect(from: n1, to: n3, initialWeightValue: 2.0)
        let _ = graph.connect(from: n2, to: n3, initialWeightValue: 3.0)

        graph.setInputs([n1, n2])
        graph.setOutputs([n3])

        try graph.validate()
        try graph.forward(input: [1.0, 2.0])
        // Expected: (1.0 × 2.0) + (2.0 × 3.0) = 8.0
        assert(abs(n3.value - 8.0) < 0.0001, "Test 3 Failed: Multiple inputs - Expected 8.0, got \(n3.value)")

        print("✅ Test 3 passed: Multiple inputs")
    } catch {
        print("❌ Test 3 Failed: Multiple inputs - \\(error.localizedDescription)")
    }

    // MARK: - Test 4: Cycle Detection
    do {
        // 1. Test Cycle Case (Should throw error)
        let cycleGraph = ComputationGraph()
        let c1 = cycleGraph.addNeuron(activation: .linear)
        let c2 = cycleGraph.addNeuron(activation: .linear)
        let _ = cycleGraph.connect(from: c1, to: c2)
        let _ = cycleGraph.connect(from: c2, to: c1) // Cycle!
        cycleGraph.setInputs([c1])
        cycleGraph.setOutputs([c2])

        var caughtCycle = false
        do {
            try cycleGraph.validate()
        } catch GraphError.cycleDetected {
            caughtCycle = true
        }
        assert(caughtCycle, "Test 4 Failed: Cycle was not detected")

        // 2. Test DAG Case (Should pass)
        let dagGraph = ComputationGraph()
        let d1 = dagGraph.addNeuron(activation: .linear)
        let d2 = dagGraph.addNeuron(activation: .linear)
        let d3 = dagGraph.addNeuron(activation: .linear)
        let _ = dagGraph.connect(from: d1, to: d2)
        let _ = dagGraph.connect(from: d1, to: d3)
        let _ = dagGraph.connect(from: d2, to: d3) // Valid DAG
        dagGraph.setInputs([d1])
        dagGraph.setOutputs([d3])

        try dagGraph.validate()
        
        print("✅ Test 4 passed: Cycle detection (both Cycle and DAG cases)")
    } catch {
        print("❌ Test 4 Failed: unexpected error - \\(error.localizedDescription)")
    }

    // MARK: - Test 5: Topological Order
    do {
        let graph = ComputationGraph()

        let n1 = graph.addNeuron(activation: .linear)
        let n2 = graph.addNeuron(activation: .linear)
        let n3 = graph.addNeuron(activation: .linear)
        let n4 = graph.addNeuron(activation: .linear)

        // n1 → n3, n2 → n3, n3 → n4
        let _ = graph.connect(from: n1, to: n3)
        let _ = graph.connect(from: n2, to: n3)
        let _ = graph.connect(from: n3, to: n4)

        graph.setInputs([n1, n2])
        graph.setOutputs([n4])

        let order = try graph.topologicalOrder
        let indices = order.map { $0.id }

        let n1Index = indices.firstIndex(of: n1.id)!
        let n2Index = indices.firstIndex(of: n2.id)!
        let n3Index = indices.firstIndex(of: n3.id)!
        let n4Index = indices.firstIndex(of: n4.id)!

        assert(n1Index < n3Index, "Test 5 Failed: Topological order - n1 not before n3")
        assert(n2Index < n3Index, "Test 5 Failed: Topological order - n2 not before n3")
        assert(n3Index < n4Index, "Test 5 Failed: Topological order - n3 not before n4")

        print("✅ Test 5 passed: Topological order")
    } catch {
        print("❌ Test 5 Failed: Topological order - \\(error.localizedDescription)")
    }

    // MARK: - Final Integration Test: XOR-like structure
    do {
        let graph = ComputationGraph()

        // 2 inputs
        let i1 = graph.addNeuron(activation: .linear)
        let i2 = graph.addNeuron(activation: .linear)

        // 2 hidden
        let h1 = graph.addNeuron(activation: .relu)
        let h2 = graph.addNeuron(activation: .relu)

        // 1 output
        let o1 = graph.addNeuron(activation: .sigmoid)

        // Connect: fully-connected 2-2-1
        let _ = graph.connect(from: i1, to: h1)
        let _ = graph.connect(from: i1, to: h2)
        let _ = graph.connect(from: i2, to: h1)
        let _ = graph.connect(from: i2, to: h2)
        let _ = graph.connect(from: h1, to: o1)
        let _ = graph.connect(from: h2, to: o1)

        graph.setInputs([i1, i2])
        graph.setOutputs([o1])

        // Validate
        try graph.validate()
        print("✅ XOR architecture is valid")

        // Forward pass (random weights, won't solve XOR yet)
        try graph.forward(input: [1.0, 0.0])
        print("Output for [1.0, 0.0]: \(o1.value)") // Some number between 0-1

        try graph.forward(input: [0.0, 1.0])
        print("Output for [0.0, 1.0]: \(o1.value)")

        try graph.forward(input: [1.0, 1.0])
        print("Output for [1.0, 1.0]: \(o1.value)")
        
        try graph.forward(input: [0.0, 0.0])
        print("Output for [0.0, 0.0]: \(o1.value)")

        print("✅ Day 1 Complete! All core engine functionalities appear to be in place.")
    } catch {
        print("❌ Final Integration Test Failed: \\(error.localizedDescription)")
    }

    print("--- All Core Engine Tests Finished ---")
}
