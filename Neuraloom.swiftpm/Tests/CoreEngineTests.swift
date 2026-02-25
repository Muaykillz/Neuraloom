import Foundation

func runAllCoreEngineTests() {
    print("\n--- Running All Core Engine Tests ---")
    var passed = 0
    var failed = 0

    func pass(_ name: String) { print("✅ \(name)"); passed += 1 }
    func fail(_ name: String, _ reason: String) { print("❌ \(name): \(reason)"); failed += 1 }

    // MARK: - Test 1: Simple Pass-Through (2 neurons)
    do {
        let graph = ComputationGraph()
        let n1 = graph.addNeuron(activation: .linear)
        let n2 = graph.addNeuron(activation: .linear)
        let _ = graph.connect(from: n1, to: n2, initialWeightValue: 2.0)
        graph.setInputs([n1]); graph.setOutputs([n2])
        try graph.validate()

        var model = try ExecutionEngine.compile(graph: graph)
        ExecutionEngine.predict(model: &model, input: [3.0])
        let output = model.nodeValues[model.outputNodeIndices[0]]

        if abs(output - 6.0) < 0.0001 {
            pass("T1: Simple pass-through")
        } else {
            fail("T1: Simple pass-through", "Expected 6.0, got \(output)")
        }
    } catch {
        fail("T1: Simple pass-through", error.localizedDescription)
    }

    // MARK: - Test 2: ReLU Activation
    do {
        let graph = ComputationGraph()
        let n1 = graph.addNeuron(activation: .linear)
        let n2 = graph.addNeuron(activation: .relu)
        let _ = graph.connect(from: n1, to: n2, initialWeightValue: 1.0)
        graph.setInputs([n1]); graph.setOutputs([n2])
        try graph.validate()

        var model = try ExecutionEngine.compile(graph: graph)

        ExecutionEngine.predict(model: &model, input: [5.0])
        var output = model.nodeValues[model.outputNodeIndices[0]]
        guard abs(output - 5.0) < 0.0001 else {
            fail("T2: ReLU activation", "positive: Expected 5.0, got \(output)")
            return
        }

        ExecutionEngine.predict(model: &model, input: [-3.0])
        output = model.nodeValues[model.outputNodeIndices[0]]
        if abs(output - 0.0) < 0.0001 {
            pass("T2: ReLU activation")
        } else {
            fail("T2: ReLU activation", "negative: Expected 0.0, got \(output)")
        }
    } catch {
        fail("T2: ReLU activation", error.localizedDescription)
    }

    // MARK: - Test 3: Two Inputs → One Output (Simple Sum)
    do {
        let graph = ComputationGraph()
        let n1 = graph.addNeuron(activation: .linear)
        let n2 = graph.addNeuron(activation: .linear)
        let n3 = graph.addNeuron(activation: .linear)
        let _ = graph.connect(from: n1, to: n3, initialWeightValue: 2.0)
        let _ = graph.connect(from: n2, to: n3, initialWeightValue: 3.0)
        graph.setInputs([n1, n2]); graph.setOutputs([n3])
        try graph.validate()

        var model = try ExecutionEngine.compile(graph: graph)
        ExecutionEngine.predict(model: &model, input: [1.0, 2.0])
        let output = model.nodeValues[model.outputNodeIndices[0]]

        if abs(output - 8.0) < 0.0001 {
            pass("T3: Multiple inputs (1*2 + 2*3 = 8)")
        } else {
            fail("T3: Multiple inputs", "Expected 8.0, got \(output)")
        }
    } catch {
        fail("T3: Multiple inputs", error.localizedDescription)
    }

    // MARK: - Test 4: Cycle Detection
    do {
        let cycleGraph = ComputationGraph()
        let c1 = cycleGraph.addNeuron(activation: .linear)
        let c2 = cycleGraph.addNeuron(activation: .linear)
        let _ = cycleGraph.connect(from: c1, to: c2)
        let _ = cycleGraph.connect(from: c2, to: c1)
        cycleGraph.setInputs([c1]); cycleGraph.setOutputs([c2])

        var caughtCycle = false
        do {
            try cycleGraph.validate()
        } catch GraphError.cycleDetected {
            caughtCycle = true
        }
        guard caughtCycle else {
            fail("T4: Cycle detection", "Cycle was not detected")
            return
        }

        let dagGraph = ComputationGraph()
        let d1 = dagGraph.addNeuron(activation: .linear)
        let d2 = dagGraph.addNeuron(activation: .linear)
        let d3 = dagGraph.addNeuron(activation: .linear)
        let _ = dagGraph.connect(from: d1, to: d2)
        let _ = dagGraph.connect(from: d1, to: d3)
        let _ = dagGraph.connect(from: d2, to: d3)
        dagGraph.setInputs([d1]); dagGraph.setOutputs([d3])
        try dagGraph.validate()

        pass("T4: Cycle detection (both Cycle and DAG cases)")
    } catch {
        fail("T4: Cycle detection", "unexpected error: \(error.localizedDescription)")
    }

    // MARK: - Test 5: Topological Order
    do {
        let graph = ComputationGraph()
        let n1 = graph.addNeuron(activation: .linear); let n2 = graph.addNeuron(activation: .linear)
        let n3 = graph.addNeuron(activation: .linear); let n4 = graph.addNeuron(activation: .linear)
        let _ = graph.connect(from: n1, to: n3); let _ = graph.connect(from: n2, to: n3)
        let _ = graph.connect(from: n3, to: n4)
        graph.setInputs([n1, n2]); graph.setOutputs([n4])

        let order = try graph.topologicalOrder()
        let indices = order.map { $0.id }
        let n1Index = indices.firstIndex(of: n1.id)!; let n2Index = indices.firstIndex(of: n2.id)!
        let n3Index = indices.firstIndex(of: n3.id)!; let n4Index = indices.firstIndex(of: n4.id)!

        if n1Index < n3Index && n2Index < n3Index && n3Index < n4Index {
            pass("T5: Topological order")
        } else {
            fail("T5: Topological order", "order violated")
        }
    } catch {
        fail("T5: Topological order", error.localizedDescription)
    }

    // MARK: - Final Integration Test: XOR-like structure
    do {
        let graph = ComputationGraph()
        let i1 = graph.addNeuron(activation: .linear); let i2 = graph.addNeuron(activation: .linear)
        let h1 = graph.addNeuron(activation: .relu); let h2 = graph.addNeuron(activation: .relu)
        let o1 = graph.addNeuron(activation: .sigmoid)
        let _ = graph.connect(from: i1, to: h1); let _ = graph.connect(from: i1, to: h2)
        let _ = graph.connect(from: i2, to: h1); let _ = graph.connect(from: i2, to: h2)
        let _ = graph.connect(from: h1, to: o1); let _ = graph.connect(from: h2, to: o1)
        graph.setInputs([i1, i2]); graph.setOutputs([o1])
        try graph.validate()

        var model = try ExecutionEngine.compile(graph: graph)

        ExecutionEngine.predict(model: &model, input: [1.0, 0.0])
        let o10 = model.nodeValues[model.outputNodeIndices[0]]
        ExecutionEngine.predict(model: &model, input: [0.0, 1.0])
        let o01 = model.nodeValues[model.outputNodeIndices[0]]
        ExecutionEngine.predict(model: &model, input: [1.0, 1.0])
        let o11 = model.nodeValues[model.outputNodeIndices[0]]
        ExecutionEngine.predict(model: &model, input: [0.0, 0.0])
        let o00 = model.nodeValues[model.outputNodeIndices[0]]

        pass("T6: XOR architecture valid — outputs: [1,0]=\(String(format:"%.3f",o10)) [0,1]=\(String(format:"%.3f",o01)) [1,1]=\(String(format:"%.3f",o11)) [0,0]=\(String(format:"%.3f",o00))")
    } catch {
        fail("T6: XOR architecture", error.localizedDescription)
    }

    print("\n--- Core Engine Tests: \(passed) passed, \(failed) failed ---")
}
