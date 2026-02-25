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

    // T3: Every neuron-to-neuron ConnectionViewModel maps to exactly one weight index
    do {
        let vm = CanvasViewModel()
        do {
            let compiled = try svc.buildNetwork(nodes: vm.nodes, connections: vm.connections)
            // Only neuron-to-neuron connections should have weight mappings
            // Exclude connections where source or target is a synthetic port (dataset/loss)
            let neuronIds = Set(vm.nodes.filter { $0.type == .neuron }.map(\.id))
            let neuronConns = vm.connections.filter { conn in
                neuronIds.contains(conn.sourceNodeId) && neuronIds.contains(conn.targetNodeId)
            }
            let mapped = neuronConns.filter { compiled.connToWeightIdx[$0.id] != nil }.count
            let total  = neuronConns.count
            if mapped == total {
                pass("T3: All \(total) neuron connections have a weight index mapping")
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

    // T16: XOR converges to loss < 0.05 within 2000 epochs
    do {
        let vm = CanvasViewModel()
        vm.totalEpochs = 2000
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

    // MARK: - Dataset Node Tests

    // T17: MVP scenario includes dataset node with 3 column port connections
    do {
        let vm = CanvasViewModel()
        let datasetNodes = vm.nodes.filter { $0.type == .dataset }
        let dsPortIds = datasetNodes.compactMap(\.datasetConfig).flatMap(\.columnPortIds)
        let dsConns = vm.connections.filter { conn in dsPortIds.contains(conn.sourceNodeId) }
        if datasetNodes.count == 1 && dsConns.count == 3 {
            pass("T17: MVP has 1 dataset node with 3 port connections")
        } else {
            fail("T17: MVP dataset setup", "datasets=\(datasetNodes.count), dsConns=\(dsConns.count)")
        }
    }

    // T18: buildNetwork resolves XOR training data from dataset node
    do {
        let vm = CanvasViewModel()
        do {
            let compiled = try svc.buildNetwork(nodes: vm.nodes, connections: vm.connections)
            let data = compiled.trainingData
            if data.count == 4 {
                // Verify XOR pattern: check that (0,0)→0, (0,1)→1, (1,0)→1, (1,1)→0
                let sorted = data.sorted { $0.0[0] * 10 + $0.0[1] < $1.0[0] * 10 + $1.0[1] }
                let expectedOutputs = [0.0, 1.0, 1.0, 0.0]
                let match = zip(sorted, expectedOutputs).allSatisfy { $0.0.1[0] == $0.1 }
                if match {
                    pass("T18: Training data matches XOR pattern from dataset node")
                } else {
                    fail("T18: XOR data pattern", "outputs don't match expected XOR")
                }
            } else {
                fail("T18: XOR training data", "expected 4 samples, got \(data.count)")
            }
        } catch {
            fail("T18: XOR training data", error.localizedDescription)
        }
    }

    // T19: Dataset connections are excluded from weight index mapping
    do {
        let vm = CanvasViewModel()
        do {
            let compiled = try svc.buildNetwork(nodes: vm.nodes, connections: vm.connections)
            let dsPortIds = vm.nodes.compactMap(\.datasetConfig).flatMap(\.columnPortIds)
            let dsConns = vm.connections.filter { dsPortIds.contains($0.sourceNodeId) }
            let anyMapped = dsConns.contains { compiled.connToWeightIdx[$0.id] != nil }
            if !anyMapped && !dsConns.isEmpty {
                pass("T19: Dataset connections have no weight mapping (\(dsConns.count) conns)")
            } else {
                fail("T19: Dataset weight exclusion", "dataset conns mapped=\(anyMapped), count=\(dsConns.count)")
            }
        } catch {
            fail("T19: Dataset weight exclusion", error.localizedDescription)
        }
    }

    // T20: Deleting dataset node removes its port connections
    do {
        let vm = CanvasViewModel()
        let dsNode = vm.nodes.first(where: { $0.type == .dataset })!
        let portIds = Set(dsNode.datasetConfig!.columnPortIds)
        let beforeCount = vm.connections.filter { portIds.contains($0.sourceNodeId) }.count
        vm.deleteNode(id: dsNode.id)
        let afterCount = vm.connections.filter { portIds.contains($0.sourceNodeId) }.count
        if beforeCount == 3 && afterCount == 0 {
            pass("T20: Deleting dataset node removes all 3 port connections")
        } else {
            fail("T20: Delete dataset cleanup", "before=\(beforeCount), after=\(afterCount)")
        }
    }

    // T21: updateDatasetPreset changes preset and preserves ports when column count matches
    do {
        let vm = CanvasViewModel()
        guard let dsIdx = vm.nodes.firstIndex(where: { $0.type == .dataset }) else {
            fail("T21: Preset update", "no dataset node found"); return
        }
        let oldPorts = vm.nodes[dsIdx].datasetConfig!.columnPortIds
        vm.updateDatasetPreset(nodeId: vm.nodes[dsIdx].id, preset: .circle) // 3 cols → 3 cols
        let newPorts = vm.nodes[dsIdx].datasetConfig!.columnPortIds
        let sameCount = oldPorts.count == newPorts.count
        let presetChanged = vm.nodes[dsIdx].datasetConfig!.preset == .circle
        if sameCount && presetChanged {
            pass("T21: Preset changed to Circle, ports preserved (same col count)")
        } else {
            fail("T21: Preset update", "sameCount=\(sameCount), preset=\(vm.nodes[dsIdx].datasetConfig!.preset)")
        }
    }

    // T22: updateDatasetPreset regenerates ports when column count changes
    do {
        let vm = CanvasViewModel()
        guard let dsIdx = vm.nodes.firstIndex(where: { $0.type == .dataset }) else {
            fail("T22: Port regen", "no dataset node found"); return
        }
        let oldPorts = vm.nodes[dsIdx].datasetConfig!.columnPortIds  // XOR: 3 cols
        vm.updateDatasetPreset(nodeId: vm.nodes[dsIdx].id, preset: .linear)  // 2 cols
        let newPorts = vm.nodes[dsIdx].datasetConfig!.columnPortIds
        if newPorts.count == 2 && oldPorts.count == 3 {
            pass("T22: Ports regenerated (3 → 2) when switching to Linear")
        } else {
            fail("T22: Port regen", "old=\(oldPorts.count), new=\(newPorts.count)")
        }
    }

    // T23: Switching preset removes orphaned port connections
    do {
        let vm = CanvasViewModel()
        guard let dsNode = vm.nodes.first(where: { $0.type == .dataset }) else {
            fail("T23: Orphan cleanup", "no dataset node found"); return
        }
        let portIds = Set(dsNode.datasetConfig!.columnPortIds)
        let before = vm.connections.filter { portIds.contains($0.sourceNodeId) }.count
        vm.updateDatasetPreset(nodeId: dsNode.id, preset: .linear) // 3→2 cols, old ports gone
        let orphanConns = vm.connections.filter { portIds.contains($0.sourceNodeId) }.count
        if before == 3 && orphanConns == 0 {
            pass("T23: Switching XOR→Linear removes 3 orphaned port connections")
        } else {
            fail("T23: Orphan cleanup", "before=\(before), orphans=\(orphanConns)")
        }
    }

    // T24: Training with dataset node produces same results as hardcoded XOR
    do {
        let vm = CanvasViewModel()
        vm.totalEpochs = 1000
        vm.learningRate = 0.1
        vm.startTraining()
        await waitForTraining(vm, timeout: 100)
        guard let last = vm.lossHistory.last else {
            fail("T24: Dataset training", "no loss history"); return
        }
        if last < 0.1 {
            pass("T24: Training with dataset XOR converges (loss=\(String(format: "%.5f", last)))")
        } else {
            fail("T24: Dataset training", "loss=\(String(format: "%.5f", last)) >= 0.1")
        }
    }

    // T25: columnPortPosition resolves correctly for dataset ports
    do {
        let vm = CanvasViewModel()
        guard let dsNode = vm.nodes.first(where: { $0.type == .dataset }),
              let config = dsNode.datasetConfig else {
            fail("T25: Port position", "no dataset node"); return
        }
        let pos = vm.columnPortPosition(portId: config.columnPortIds[0])
        if pos != nil {
            pass("T25: columnPortPosition resolves for first port")
        } else {
            fail("T25: Port position", "returned nil")
        }
    }

    // T26: drawableConnections includes utility links (dataset, loss ports, etc.)
    do {
        let vm = CanvasViewModel()
        let utilLinks = vm.drawableConnections.filter(\.isUtilityLink)
        let neuronLinks = vm.drawableConnections.filter { !$0.isUtilityLink }
        // Utility: dsPort[0]→i1, dsPort[1]→i2, dsPort[2]→truePort, o1→predPort, loss→viz = 5
        // Neuron: i1→h1, i1→h2, i2→h1, i2→h2, h1→o1, h2→o1 = 6
        if utilLinks.count == 5 && neuronLinks.count == 6 {
            pass("T26: drawableConnections: 5 utility + 6 neuron links")
        } else {
            fail("T26: drawableConnections", "utility=\(utilLinks.count), neuron=\(neuronLinks.count)")
        }
    }

    // T27: No dataset node → fallback XOR training data
    do {
        let i1 = UUID(); let o1 = UUID()
        let nodes: [NodeViewModel] = [
            NodeViewModel(id: i1, position: .zero, type: .neuron, activation: .linear, role: .input),
            NodeViewModel(id: o1, position: .zero, type: .neuron, activation: .sigmoid, role: .output),
        ]
        let conns = [ConnectionViewModel(sourceNodeId: i1, targetNodeId: o1)]
        do {
            let compiled = try svc.buildNetwork(nodes: nodes, connections: conns)
            if compiled.trainingData.count == 4 {
                pass("T27: No dataset node → fallback XOR (4 samples)")
            } else {
                fail("T27: Fallback data", "expected 4, got \(compiled.trainingData.count)")
            }
        } catch {
            fail("T27: Fallback data", error.localizedDescription)
        }
    }

    // MARK: - Step(Sample) Highlight Tests

    // T28: stepOneSample returns sequential sampleIndex 0, 1, 2, 3
    do {
        let vm = CanvasViewModel()
        vm.stepGranularity = .sample
        var indices: [Int?] = []
        for _ in 0..<4 {
            vm.stepTraining()
            indices.append(vm.activeSampleIndex)
        }
        if indices == [0, 1, 2, 3] {
            pass("T28: Step(Sample) highlights rows sequentially: \(indices)")
        } else {
            fail("T28: Step(Sample) sequential", "expected [0,1,2,3], got \(indices)")
        }
    }

    // T29: After exhausting all rows, sampleIndex wraps back to 0
    do {
        let vm = CanvasViewModel()
        vm.stepGranularity = .sample
        // XOR has 4 rows → step 4 times to exhaust, then 5th should wrap to 0
        for _ in 0..<4 { vm.stepTraining() }
        vm.stepTraining() // 5th step
        if vm.activeSampleIndex == 0 {
            pass("T29: sampleIndex wraps to 0 after exhausting all rows")
        } else {
            fail("T29: Wrap-around", "expected 0, got \(String(describing: vm.activeSampleIndex))")
        }
    }

    // T30: stepOneEpoch sets activeSampleIndex = nil
    do {
        let vm = CanvasViewModel()
        vm.stepGranularity = .sample
        vm.stepTraining() // set activeSampleIndex to 0
        vm.stepGranularity = .epoch
        vm.stepTraining() // epoch step should clear it
        if vm.activeSampleIndex == nil {
            pass("T30: Step(Epoch) sets activeSampleIndex = nil")
        } else {
            fail("T30: Epoch clears index", "got \(String(describing: vm.activeSampleIndex))")
        }
    }

    // T31: resetTraining clears activeSampleIndex
    do {
        let vm = CanvasViewModel()
        vm.stepGranularity = .sample
        vm.stepTraining()
        vm.resetTraining()
        if vm.activeSampleIndex == nil {
            pass("T31: resetTraining clears activeSampleIndex")
        } else {
            fail("T31: Reset clears index", "got \(String(describing: vm.activeSampleIndex))")
        }
    }

    // T32: startTraining (continuous) clears activeSampleIndex
    do {
        let vm = CanvasViewModel()
        vm.stepGranularity = .sample
        vm.stepTraining()
        guard vm.activeSampleIndex != nil else {
            fail("T32: startTraining clears index", "activeSampleIndex was already nil"); return
        }
        vm.totalEpochs = 10
        vm.startTraining()
        if vm.activeSampleIndex == nil {
            pass("T32: startTraining clears activeSampleIndex")
        } else {
            fail("T32: startTraining clears index", "got \(String(describing: vm.activeSampleIndex))")
        }
        vm.stopTraining()
    }

    print("\n--- Canvas Integration Tests: \(passed) passed, \(failed) failed ---\n")
}
