import Foundation

// MARK: - Canvas Integration Tests
// Tests CanvasViewModel.buildNetwork() compilation, ID mapping,
// validation errors, training flow, and weight sync-back.

@MainActor
func runCanvasIntegrationTests() async {
    print("\n--- Canvas Integration Tests ---")
    var passed = 0
    var failed = 0

    func pass(_ name: String) { print("✅ \(name)"); passed += 1 }
    func fail(_ name: String, _ reason: String) { print("❌ \(name): \(reason)"); failed += 1 }

    func waitForTraining(_ vm: CanvasViewModel, timeout: Int = 50) async {
        var ticks = 0
        while vm.isTraining && ticks < timeout {
            try? await Task.sleep(nanoseconds: 100_000_000)
            ticks += 1
        }
    }

    let svc = TrainingService()

    // MARK: - Compilation Tests

    // T1: MVP scenario compiles with correct node and weight counts
    do {
        let vm = CanvasViewModel()
        do {
            let compiled = try svc.buildNetwork(nodes: vm.nodes, connections: vm.connections)
            let n = compiled.model.nodeIDMap.count
            let w = compiled.model.weightIDMap.count
            if n == 5 && w == 6 {
                pass("T1: MVP compiles — 5 nodes, 6 weights")
            } else {
                fail("T1: MVP compiles", "expected 5 nodes/6 weights, got \(n)/\(w)")
            }
        } catch {
            fail("T1: MVP compiles", error.localizedDescription)
        }
    }

    // T2: Non-neuron nodes (dataset, viz) are excluded from the graph
    do {
        let inId = UUID(); let outId = UUID()
        let nodes: [NodeViewModel] = [
            NodeViewModel(id: inId,  position: .zero, type: .neuron,        activation: .linear,  role: .input),
            NodeViewModel(id: UUID(), position: .zero, type: .dataset),
            NodeViewModel(id: UUID(), position: .zero, type: .visualization),
            NodeViewModel(id: UUID(), position: .zero, type: .annotation),
            NodeViewModel(id: outId, position: .zero, type: .neuron,        activation: .sigmoid, role: .output),
        ]
        let conns = [ConnectionViewModel(sourceNodeId: inId, targetNodeId: outId)]
        do {
            let compiled = try svc.buildNetwork(nodes: nodes, connections: conns)
            let n = compiled.model.nodeIDMap.count
            if n == 2 {
                pass("T2: Non-neuron nodes excluded — only 2 neuron nodes compiled")
            } else {
                fail("T2: Non-neuron nodes excluded", "expected 2, got \(n)")
            }
        } catch {
            fail("T2: Non-neuron nodes excluded", error.localizedDescription)
        }
    }

    // T3: Every ConnectionViewModel maps to exactly one weight index
    do {
        let vm = CanvasViewModel()
        do {
            let compiled = try svc.buildNetwork(nodes: vm.nodes, connections: vm.connections)
            let mapped = vm.connections.filter { compiled.connToWeightIdx[$0.id] != nil }.count
            let total  = vm.connections.count
            if mapped == total {
                pass("T3: All \(total) connections have a weight index mapping")
            } else {
                fail("T3: Weight index mapping", "\(total - mapped) connections unmapped")
            }
        } catch {
            fail("T3: Weight index mapping", error.localizedDescription)
        }
    }

    // T4: All weight indices are in-bounds for the model weight arrays
    do {
        let vm = CanvasViewModel()
        do {
            let compiled = try svc.buildNetwork(nodes: vm.nodes, connections: vm.connections)
            let weightCount = compiled.model.weightValues.count
            let allInBounds = compiled.connToWeightIdx.values.allSatisfy { $0 >= 0 && $0 < weightCount }
            if allInBounds {
                pass("T4: All weight indices in-bounds (weightCount=\(weightCount))")
            } else {
                fail("T4: Weight indices in-bounds", "at least one index is out of range")
            }
        } catch {
            fail("T4: Weight indices in-bounds", error.localizedDescription)
        }
    }

    // MARK: - Validation Error Tests

    // T5: No input nodes → inputOutputNotSet
    do {
        let vm = CanvasViewModel()
        let nodes = vm.nodes.map { n in NodeViewModel(id: n.id, position: n.position, type: n.type, activation: n.activation, role: n.role == .input ? .hidden : n.role) }
        do {
            _ = try svc.buildNetwork(nodes: nodes, connections: vm.connections)
            fail("T5: Missing inputs → error", "expected throw, got success")
        } catch GraphError.inputOutputNotSet {
            pass("T5: Missing inputs throws inputOutputNotSet")
        } catch {
            fail("T5: Missing inputs → error", "wrong error: \(error)")
        }
    }

    // T6: No output nodes → inputOutputNotSet
    do {
        let vm = CanvasViewModel()
        let nodes = vm.nodes.map { n in NodeViewModel(id: n.id, position: n.position, type: n.type, activation: n.activation, role: n.role == .output ? .hidden : n.role) }
        do {
            _ = try svc.buildNetwork(nodes: nodes, connections: vm.connections)
            fail("T6: Missing outputs → error", "expected throw, got success")
        } catch GraphError.inputOutputNotSet {
            pass("T6: Missing outputs throws inputOutputNotSet")
        } catch {
            fail("T6: Missing outputs → error", "wrong error: \(error)")
        }
    }

    // T7: Floating (disconnected) neuron → disconnectedGraph
    do {
        let vm = CanvasViewModel()
        let nodes = vm.nodes + [NodeViewModel(id: UUID(), position: .zero, type: .neuron, activation: .relu)]
        do {
            _ = try svc.buildNetwork(nodes: nodes, connections: vm.connections)
            fail("T7: Disconnected node → error", "expected throw, got success")
        } catch GraphError.disconnectedGraph {
            pass("T7: Disconnected node throws disconnectedGraph")
        } catch {
            fail("T7: Disconnected node → error", "wrong error: \(error)")
        }
    }

    // T8: Empty canvas → inputOutputNotSet (no neurons = no inputs/outputs)
    do {
        do {
            _ = try svc.buildNetwork(nodes: [], connections: [])
            fail("T8: Empty canvas → error", "expected throw, got success")
        } catch {
            pass("T8: Empty canvas throws \(type(of: error))")
        }
    }

    // MARK: - Training State Tests

    // T9: Calling startTraining() while already training is a no-op
    do {
        let vm = CanvasViewModel()
        vm.startTraining()
        guard vm.isTraining else { fail("T9: Double-start guard", "first call did not set isTraining"); vm.stopTraining(); return }
        vm.startTraining()  // should be ignored
        let stillTraining = vm.isTraining
        vm.stopTraining()
        if stillTraining {
            pass("T9: Double-start is no-op (isTraining stays true)")
        } else {
            fail("T9: Double-start guard", "second call somehow cleared isTraining")
        }
    }

    // T10: stopTraining() sets isTraining = false immediately
    do {
        let vm = CanvasViewModel()
        vm.startTraining()
        vm.stopTraining()
        if !vm.isTraining {
            pass("T10: stopTraining() clears isTraining immediately")
        } else {
            fail("T10: stopTraining clears isTraining", "isTraining still true")
        }
    }

    // T11: isTraining becomes false after training completes normally
    do {
        let vm = CanvasViewModel()
        vm.totalEpochs = 50
        vm.startTraining()
        await waitForTraining(vm)
        if !vm.isTraining {
            pass("T11: isTraining = false after training completes")
        } else {
            fail("T11: isTraining clears after training", "still training after timeout")
        }
    }

    // T12: lossHistory count matches totalEpochs
    do {
        let vm = CanvasViewModel()
        vm.totalEpochs = 100
        vm.startTraining()
        await waitForTraining(vm)
        if vm.lossHistory.count == 100 {
            pass("T12: lossHistory has exactly 100 entries")
        } else {
            fail("T12: lossHistory count", "expected 100, got \(vm.lossHistory.count)")
        }
    }

    // T13: currentEpoch reaches totalEpochs
    do {
        let vm = CanvasViewModel()
        vm.totalEpochs = 80
        vm.startTraining()
        await waitForTraining(vm)
        if vm.currentEpoch == 80 {
            pass("T13: currentEpoch reaches totalEpochs (80)")
        } else {
            fail("T13: currentEpoch", "expected 80, got \(vm.currentEpoch)")
        }
    }

    // T14: Loss decreases over training
    do {
        let vm = CanvasViewModel()
        vm.totalEpochs = 200
        vm.learningRate = 0.1
        vm.startTraining()
        await waitForTraining(vm)
        guard let first = vm.lossHistory.first, let last = vm.lossHistory.last else {
            fail("T14: Loss decreases", "no loss history recorded")
            return
        }
        if last < first {
            pass("T14: Loss decreases (\(String(format: "%.4f", first)) → \(String(format: "%.4f", last)))")
        } else {
            fail("T14: Loss decreases", "\(first) → \(last) (did not decrease)")
        }
    }

    // T15: Weight values sync back to ConnectionViewModels after training
    do {
        let vm = CanvasViewModel()
        vm.totalEpochs = 100
        let initialValues = vm.connections.map(\.value)
        vm.startTraining()
        await waitForTraining(vm)
        let updatedValues = vm.connections.map(\.value)
        let anyChanged = zip(initialValues, updatedValues).contains { $0 != $1 }
        if anyChanged {
            pass("T15: Weight values synced back to ConnectionViewModels")
        } else {
            fail("T15: Weight sync-back", "all values still 0.0 — sync did not happen")
        }
    }

    // T16: XOR converges to loss < 0.05 within 1000 epochs
    do {
        let vm = CanvasViewModel()
        vm.totalEpochs = 1000
        vm.learningRate = 0.1
        vm.startTraining()
        await waitForTraining(vm, timeout: 100)
        let finalLoss = vm.lossHistory.last ?? 1.0
        if finalLoss < 0.05 {
            pass("T16: XOR converges — final loss \(String(format: "%.5f", finalLoss))")
        } else {
            fail("T16: XOR converges", "final loss \(String(format: "%.5f", finalLoss)) >= 0.05")
        }
    }

    print("\n--- Canvas Integration Tests: \(passed) passed, \(failed) failed ---\n")
}
