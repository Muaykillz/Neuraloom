import SwiftUI

extension CanvasViewModel {

    // MARK: - Enter / Exit Inference

    func enterInferenceMode() {
        guard canvasMode == .train else { return }
        stopTraining()

        do {
            compiledInferenceNetwork = try trainingService.buildNetwork(nodes: nodes, connections: connections)
        } catch {
            triggerToast("Cannot enter inference: \(error.localizedDescription)")
            return
        }

        savedPlaygroundMode = playgroundMode
        savedSelectedNodeId = selectedNodeId
        savedSelectedConnectionId = selectedConnectionId

        inferenceInputInfos = []
        inferenceInputs = [:]
        if let dsNode = nodes.first(where: { $0.type == .dataset }),
           let config = dsNode.datasetConfig {
            let preset = config.preset
            let ranges = preset.inputRanges
            let inputCols = preset.inputColumns
            for i in 0..<inputCols.count {
                let portId = config.columnPortIds[i]
                let range = i < ranges.count ? ranges[i] : (min: 0.0, max: 1.0)
                let mid = (range.min + range.max) / 2.0
                inferenceInputInfos.append(InferenceInputInfo(
                    label: inputCols[i],
                    portId: portId,
                    range: range.min...range.max
                ))
                inferenceInputs[portId] = mid
            }
        }

        inferenceOutputNodeIds = nodes.filter { $0.type == .neuron && $0.isOutput }.map(\.id)

        autoOutputDisplayIds = []
        for outId in inferenceOutputNodeIds {
            if let outNode = nodes.first(where: { $0.id == outId }) {
                let displayId = UUID()
                var displayNode = NodeViewModel(
                    id: displayId,
                    position: CGPoint(x: outNode.position.x + 150, y: outNode.position.y),
                    type: .outputDisplay
                )
                displayNode.outputDisplayValue = nodeOutputs[outId]
                nodes.append(displayNode)
                connections.append(ConnectionViewModel(sourceNodeId: outId, targetNodeId: displayId))
                autoOutputDisplayIds.append(displayId)
            }
        }

        for i in nodes.indices where nodes[i].type == .scatterPlot {
            nodes[i].scatterSeriesA.removeAll()
            nodes[i].scatterSeriesB.removeAll()
        }

        inferenceInputSource = .manual
        inferenceDatasetRowIndex = 0

        playgroundMode = .inspect
        selectedNodeId = nil
        selectedConnectionId = nil
        connectionTapGlobalLocation = nil

        withAnimation(.spring()) {
            canvasMode = .inference
        }
    }

    func exitInferenceMode() {
        guard canvasMode == .inference else { return }

        let autoIds = Set(autoOutputDisplayIds).union(inferenceTemporaryNodeIds)
        nodes.removeAll { autoIds.contains($0.id) }
        connections.removeAll {
            autoIds.contains($0.sourceNodeId) || autoIds.contains($0.targetNodeId)
            || inferenceTemporaryConnectionIds.contains($0.id)
        }
        inferenceTemporaryNodeIds.removeAll()
        inferenceTemporaryConnectionIds.removeAll()

        playgroundMode = savedPlaygroundMode
        selectedNodeId = savedSelectedNodeId
        selectedConnectionId = savedSelectedConnectionId

        inferenceInputInfos = []
        inferenceInputs = [:]
        inferenceOutputNodeIds = []
        autoOutputDisplayIds = []
        autoPredict = false
        compiledInferenceNetwork = nil
        activeSampleIndex = nil

        withAnimation(.spring()) {
            canvasMode = .train
        }
    }

    // MARK: - Run Inference

    func runInference() {
        switch inferenceInputSource {
        case .manual:
            Task { await runAnimatedInference() }
        case .dataset:
            Task { await runDatasetRowInference() }
        }
    }

    func runPredictAll() {
        guard inferenceInputSource == .dataset,
              let dsNode = nodes.first(where: { $0.type == .dataset }),
              let config = dsNode.datasetConfig else { return }
        let total = config.cachedRows.count
        guard total > 0, !isPredicting else { return }

        clearScatterData()

        Task {
            for i in 0..<(total - 1) {
                guard !Task.isCancelled else { break }
                selectDatasetRow(i)
                await runSilentInference(row: config.cachedRows[i], inputCount: config.preset.inputColumnCount)
                try? await Task.sleep(for: .milliseconds(60))
            }
            selectDatasetRow(total - 1)
            await runDatasetRowInference()
            fulfillTourCondition(.custom(id: "predictedAll"))
        }
    }

    func selectDatasetRow(_ index: Int) {
        inferenceDatasetRowIndex = index
        activeSampleIndex = index
    }

    private func runDatasetRowInference() async {
        guard let dsNode = nodes.first(where: { $0.type == .dataset }),
              let config = dsNode.datasetConfig else { return }
        let rows = config.cachedRows
        guard inferenceDatasetRowIndex < rows.count else { return }

        let row = rows[inferenceDatasetRowIndex]
        let inputCount = config.preset.inputColumnCount
        let inputValues = Array(row.prefix(inputCount))

        activeSampleIndex = inferenceDatasetRowIndex
        await runAnimatedInference(inputOverride: inputValues)
    }

    private func runSilentInference(row: [Double], inputCount: Int) async {
        guard var net = compiledInferenceNetwork else { return }

        let inputValues = Array(row.prefix(inputCount))
        seedNetworkInputs(inputValues, into: &net)

        let (layers, _) = computeNodeLayers()
        let idToModelIdx = net.nodeVMIdToNodeIdx

        for layer in layers {
            computeLayerValues(layer: layer, idToModelIdx: idToModelIdx, net: &net)
        }

        updateAllOutputDisplays(net: net)
        updateDatasetPortDisplays(row: row)

        computeInferenceLoss(net: net)
        updateScatterPlotNodes()
        compiledInferenceNetwork = net
    }

    private func runAnimatedInference(inputOverride: [Double]? = nil) async {
        guard !isPredicting else { return }
        guard var net = compiledInferenceNetwork else { return }

        isPredicting = true
        defer {
            isPredicting = false
            withAnimation(.easeOut(duration: 0.2)) { clearGlow() }
            fulfillTourCondition(.custom(id: "predicted"))
        }

        let scale = inferenceAnimationScale
        let edgeGlowDuration: TimeInterval = 0.1 * scale
        let nodeGlowDuration: TimeInterval = 0.15 * scale

        let inputNeuronIds = nodes.filter { $0.isInput }.map(\.id)
        var inputValues: [Double]
        if let override = inputOverride {
            inputValues = override
        } else {
            inputValues = []
            for neuronId in inputNeuronIds {
                var value = 0.0
                for conn in connections {
                    guard conn.targetNodeId == neuronId else { continue }
                    if let v = inferenceInputs[conn.sourceNodeId] {
                        value = v
                        break
                    }
                    if let srcNode = nodes.first(where: { $0.id == conn.sourceNodeId && $0.type == .number }) {
                        value = srcNode.numberValue
                        break
                    }
                }
                inputValues.append(value)
            }
        }

        seedNetworkInputs(inputValues, into: &net)

        for (vmId, modelIdx) in net.nodeVMIdToNodeIdx {
            if net.model.inputNodeIndices.contains(modelIdx) || net.model.biasNodeIndices.contains(modelIdx) {
                nodeOutputs[vmId] = net.model.nodeValues[modelIdx]
            }
        }

        let (layers, _) = computeNodeLayers()
        let idToModelIdx = net.nodeVMIdToNodeIdx

        // Update Result nodes connected directly to dataset ports
        if inferenceInputSource == .dataset,
           let dsConfig = nodes.first(where: { $0.type == .dataset })?.datasetConfig {
            updateDatasetPortDisplays(row: dsConfig.cachedRows[inferenceDatasetRowIndex])
        }

        // Animate from Dataset to Input Layer (only when a dataset node exists)
        let datasetNodeIds = Set(nodes.filter { $0.type == .dataset }.map(\.id))
        let hasDataset = !datasetNodeIds.isEmpty

        if hasDataset {
            let inputLayerIds = Set(layers.first ?? [])
            let datasetConnections = connections.filter { c in
                let isTargetInput = inputLayerIds.contains(c.targetNodeId)
                let portIds = nodes.first(where: { $0.type == .dataset })?.datasetConfig?.columnPortIds ?? []
                return isTargetInput && portIds.contains(c.sourceNodeId)
            }

            withAnimation(.easeIn(duration: edgeGlowDuration)) {
                glowingNodeIds = datasetNodeIds
                glowingConnectionIds = Set(datasetConnections.map { $0.id })
            }
            try? await Task.sleep(for: .seconds(edgeGlowDuration))

            withAnimation(.easeIn(duration: nodeGlowDuration)) {
                glowingNodeIds.formUnion(inputLayerIds)
            }
            try? await Task.sleep(for: .seconds(nodeGlowDuration))
        }

        // When no dataset, glow input + bias together first, then animate from layer 1 onward
        let biasIds = Set(nodes.filter { $0.isBias }.map(\.id))
        let startLayerIndex: Int

        if !hasDataset {
            let inputLayerIds = Set(layers.first ?? [])
            withAnimation(.easeIn(duration: nodeGlowDuration)) {
                glowingNodeIds = inputLayerIds.union(biasIds)
            }
            // Compute input layer values (no-op for input neurons but keeps consistency)
            if let firstLayer = layers.first {
                computeLayerValues(layer: firstLayer, idToModelIdx: idToModelIdx, net: &net)
            }
            try? await Task.sleep(for: .seconds(nodeGlowDuration))
            startLayerIndex = 1
        } else {
            startLayerIndex = 0
        }

        // Animate through layers
        for layerIndex in startLayerIndex..<layers.count {
            guard !Task.isCancelled else { break }
            let currentLayer = layers[layerIndex]
            let currentLayerIds = Set(currentLayer)

            let sourceLayerIds: Set<UUID>
            if layerIndex == 0 && hasDataset {
                sourceLayerIds = datasetNodeIds
            } else if layerIndex > 0 {
                sourceLayerIds = Set(layers[layerIndex - 1]).union(biasIds)
            } else {
                sourceLayerIds = Set<UUID>()
            }

            let incomingToCurrent = connections.filter { conn in
                let targetIsInCurrent = currentLayerIds.contains(conn.targetNodeId)
                let sourceIsInPrevious = sourceLayerIds.contains(conn.sourceNodeId)
                let sourceIsBias = nodes.first(where: { $0.id == conn.sourceNodeId })?.isBias ?? false
                let sourceIsDatasetPort = hasDataset && (datasetNodeIds.contains(conn.sourceNodeId)
                    || (nodes.first(where: { $0.type == .dataset })?.datasetConfig?.columnPortIds.contains(conn.sourceNodeId) ?? false))
                return targetIsInCurrent && (sourceIsInPrevious || sourceIsBias || (layerIndex == 0 && sourceIsDatasetPort))
            }

            let incomingSourceIds = Set(incomingToCurrent.map(\.sourceNodeId))

            withAnimation(.easeIn(duration: edgeGlowDuration)) {
                glowingNodeIds = incomingSourceIds
                glowingConnectionIds = Set(incomingToCurrent.map { $0.id })
            }
            try? await Task.sleep(for: .seconds(edgeGlowDuration))

            withAnimation(.easeIn(duration: nodeGlowDuration)) {
                glowingNodeIds.formUnion(currentLayerIds)
            }

            computeLayerValues(layer: currentLayer, idToModelIdx: idToModelIdx, net: &net)

            for nodeId in currentLayer {
                guard let modelIdx = idToModelIdx[nodeId] else { continue }
                nodeOutputs[nodeId] = net.model.nodeValues[modelIdx]
                for outId in autoOutputDisplayIds where connections.contains(where: { $0.sourceNodeId == nodeId && $0.targetNodeId == outId }) {
                    if let nodeIdxToUpdate = nodes.firstIndex(where: { $0.id == outId }) {
                        nodes[nodeIdxToUpdate].outputDisplayValue = net.model.nodeValues[modelIdx]
                    }
                }
            }

            try? await Task.sleep(for: .seconds(nodeGlowDuration))
        }

        // Animate to final result nodes
        let outputNeuronIds = Set(nodes.filter { $0.isOutput }.map { $0.id })
        let resultConnections = connections.filter { conn in
            outputNeuronIds.contains(conn.sourceNodeId) &&
            autoOutputDisplayIds.contains(conn.targetNodeId)
        }
        let resultNodeIds = Set(autoOutputDisplayIds)

        if !resultConnections.isEmpty {
            withAnimation(.easeIn(duration: edgeGlowDuration)) {
                glowingNodeIds = outputNeuronIds
                glowingConnectionIds = Set(resultConnections.map { $0.id })
            }
            try? await Task.sleep(for: .seconds(edgeGlowDuration))

            withAnimation(.easeIn(duration: nodeGlowDuration)) {
                glowingNodeIds.formUnion(resultNodeIds)
            }
            try? await Task.sleep(for: .seconds(nodeGlowDuration))
        }

        computeInferenceLoss(net: net)
        updateScatterPlotNodes()
        compiledInferenceNetwork = net
    }

    /// Computes loss for any temporary loss node added during inference.
    /// Resolves predicted and true values from connected ports; sets `currentLoss` to nil if unresolvable.
    private func computeInferenceLoss(net: TrainingService.CompiledNetwork) {
        guard let lossNode = nodes.first(where: { $0.type == .loss && inferenceTemporaryNodeIds.contains($0.id) }),
              let config = lossNode.lossConfig else {
            if canvasMode == .inference { currentLoss = nil }
            return
        }

        let predValue = resolvePortValue(portId: config.predPortId)
        let trueValue = resolvePortValue(portId: config.truePortId)

        if let pred = predValue, let truth = trueValue {
            currentLoss = selectedLossFunction.compute(predicted: [pred], target: [truth])
        } else {
            currentLoss = nil
        }
    }

    /// Traces a loss-port connection back to its source and returns the resolved value.
    private func resolvePortValue(portId: UUID) -> Double? {
        guard let conn = connections.first(where: { $0.targetNodeId == portId }) else { return nil }
        let sourceId = conn.sourceNodeId

        if let val = nodeOutputs[sourceId] { return val }

        if let dsNode = nodes.first(where: { $0.type == .dataset }),
           let dsConfig = dsNode.datasetConfig,
           let colIdx = dsConfig.columnPortIds.firstIndex(of: sourceId) {
            if inferenceInputSource == .dataset {
                let rows = dsConfig.cachedRows
                if inferenceDatasetRowIndex < rows.count, colIdx < rows[inferenceDatasetRowIndex].count {
                    return rows[inferenceDatasetRowIndex][colIdx]
                }
            } else if let manualVal = inferenceInputs[sourceId] {
                return manualVal
            }
        }

        if let numNode = nodes.first(where: { $0.id == sourceId && $0.type == .number }) {
            return numNode.numberValue
        }

        return nil
    }

    // MARK: - Auto Predict

    /// Runs a silent (non-animated) forward pass when autoPredict is enabled.
    func runAutoPredict() {
        guard autoPredict, canvasMode == .inference, !isPredicting else { return }
        switch inferenceInputSource {
        case .manual:
            Task { await runSilentManualInference() }
        case .dataset:
            guard let dsNode = nodes.first(where: { $0.type == .dataset }),
                  let config = dsNode.datasetConfig else { return }
            let rows = config.cachedRows
            guard !rows.isEmpty else { return }
            clearScatterData()
            let inputCount = config.preset.inputColumnCount
            let savedRow = inferenceDatasetRowIndex
            Task {
                for (i, row) in rows.enumerated() {
                    selectDatasetRow(i)
                    await runSilentInference(row: row, inputCount: inputCount)
                }
                selectDatasetRow(savedRow)
            }
        }
    }

    private func runSilentManualInference() async {
        guard var net = compiledInferenceNetwork else { return }

        let inputNeuronIds = nodes.filter { $0.isInput }.map(\.id)
        var inputValues: [Double] = []
        for neuronId in inputNeuronIds {
            var value = 0.0
            for conn in connections {
                guard conn.targetNodeId == neuronId else { continue }
                if let v = inferenceInputs[conn.sourceNodeId] {
                    value = v
                    break
                }
                if let srcNode = nodes.first(where: { $0.id == conn.sourceNodeId && $0.type == .number }) {
                    value = srcNode.numberValue
                    break
                }
            }
            inputValues.append(value)
        }

        seedNetworkInputs(inputValues, into: &net)

        let (layers, _) = computeNodeLayers()
        let idToModelIdx = net.nodeVMIdToNodeIdx

        for layer in layers {
            computeLayerValues(layer: layer, idToModelIdx: idToModelIdx, net: &net)
        }

        updateAllOutputDisplays(net: net)
        computeInferenceLoss(net: net)
        updateScatterPlotNodes()
        compiledInferenceNetwork = net
    }

    // MARK: - Scatter Plot Updates

    private func clearScatterData() {
        for i in nodes.indices where nodes[i].type == .scatterPlot {
            nodes[i].scatterSeriesA.removeAll()
            nodes[i].scatterSeriesB.removeAll()
        }
    }

    private func updateScatterPlotNodes() {
        for i in nodes.indices where nodes[i].type == .scatterPlot {
            guard let config = nodes[i].scatterPlotConfig else { continue }
            let x1 = resolvePortValue(portId: config.x1PortId)
            let y1 = resolvePortValue(portId: config.y1PortId)
            let x2 = resolvePortValue(portId: config.x2PortId)
            let y2 = resolvePortValue(portId: config.y2PortId)
            if let x = x1, let y = y1 {
                nodes[i].scatterSeriesA.append((x: x, y: y))
            }
            if let x = x2, let y = y2 {
                nodes[i].scatterSeriesB.append((x: x, y: y))
            }
        }
    }

    // MARK: - Live Weight Sync

    /// Updates the compiled inference network's weight in-place so the next Predict uses the new value.
    func syncWeightToInferenceNetwork(connectionId: UUID, newValue: Double) {
        guard canvasMode == .inference,
              var net = compiledInferenceNetwork,
              let wIdx = net.connToWeightIdx[connectionId] else { return }
        net.model.weightValues[wIdx] = newValue
        compiledInferenceNetwork = net
    }

    // MARK: - Inference Helpers

    private func seedNetworkInputs(_ inputValues: [Double], into net: inout TrainingService.CompiledNetwork) {
        for (i, idx) in net.model.inputNodeIndices.enumerated() {
            if i < inputValues.count { net.model.nodeValues[idx] = inputValues[i] }
        }
        for idx in net.model.biasNodeIndices {
            net.model.nodeValues[idx] = 1.0
        }
    }

    private func computeLayerValues(layer: [UUID], idToModelIdx: [UUID: Int], net: inout TrainingService.CompiledNetwork) {
        for nodeId in layer {
            guard let modelIdx = idToModelIdx[nodeId],
                  !net.model.inputNodeIndices.contains(modelIdx) else { continue }
            var sum = 0.0
            for wIdx in net.model.nodeIncomingEdgeIndices[modelIdx] {
                let src = net.model.edgeSourceNodeIndices[wIdx]
                sum += net.model.nodeValues[src] * net.model.weightValues[wIdx]
            }
            net.model.nodeValues[modelIdx] = net.model.nodeActivations[modelIdx].forward(sum)
        }
    }

    private func updateDatasetPortDisplays(row: [Double]) {
        guard let dsConfig = nodes.first(where: { $0.type == .dataset })?.datasetConfig else { return }
        for conn in connections {
            if let ci = dsConfig.columnPortIds.firstIndex(of: conn.sourceNodeId),
               let displayIdx = nodes.firstIndex(where: { $0.id == conn.targetNodeId && $0.type == .outputDisplay }) {
                nodes[displayIdx].outputDisplayValue = ci < row.count ? row[ci] : 0.0
            }
        }
    }

    private func updateAllOutputDisplays(net: TrainingService.CompiledNetwork) {
        for (vmId, modelIdx) in net.nodeVMIdToNodeIdx {
            nodeOutputs[vmId] = net.model.nodeValues[modelIdx]
        }
        for outId in autoOutputDisplayIds {
            if let conn = connections.first(where: { $0.targetNodeId == outId }),
               let val = nodeOutputs[conn.sourceNodeId],
               let idx = nodes.firstIndex(where: { $0.id == outId }) {
                nodes[idx].outputDisplayValue = val
            }
        }
    }

    // MARK: - Node Layers

    func computeNodeLayers() -> (layers: [[UUID]], maxDepth: Int) {
        let regularNeurons = nodes.filter { $0.type == .neuron && !$0.isBias }
        let regularNeuronIds = Set(regularNeurons.map { $0.id })
        let neuronConns = connections.filter { regularNeuronIds.contains($0.sourceNodeId) && regularNeuronIds.contains($0.targetNodeId) }

        var nodeDepths: [UUID: Int] = [:]
        let inputs = regularNeurons.filter { n in n.isInput || !neuronConns.contains(where: { $0.targetNodeId == n.id }) }
        for input in inputs { nodeDepths[input.id] = 0 }

        var changed = true
        while changed {
            changed = false
            for conn in neuronConns {
                if let sourceDepth = nodeDepths[conn.sourceNodeId] {
                    let targetDepth = nodeDepths[conn.targetNodeId]
                    if targetDepth.map({ $0 <= sourceDepth }) ?? true {
                        nodeDepths[conn.targetNodeId] = sourceDepth + 1
                        changed = true
                    }
                }
            }
        }

        let maxDepth = nodeDepths.values.max() ?? 0
        var layers: [[UUID]] = Array(repeating: [], count: maxDepth + 1)
        for node in regularNeurons {
            if let depth = nodeDepths[node.id], depth <= maxDepth {
                layers[depth].append(node.id)
            }
        }
        return (layers, maxDepth)
    }

    // MARK: - Visible Nodes/Connections (filtered by mode)

    /// Node IDs hidden in inference: visualization nodes + train-mode (non-temporary) loss nodes.
    private var inferenceHiddenNodeIds: Set<UUID> {
        var ids = Set(nodes.filter { $0.type == .visualization }.map(\.id))
        // Hide train-mode loss nodes but keep temporary ones added during inference
        for node in nodes where node.type == .loss && !inferenceTemporaryNodeIds.contains(node.id) {
            ids.insert(node.id)
        }
        return ids
    }

    var visibleNodes: [NodeViewModel] {
        if canvasMode == .train { return nodes }
        let hidden = inferenceHiddenNodeIds
        return nodes.filter { !hidden.contains($0.id) }
    }

    var visibleConnections: [DrawableConnection] {
        if canvasMode == .train { return drawableConnections }
        let hiddenNodeIds = inferenceHiddenNodeIds
        let hiddenPortIds: Set<UUID> = Set(
            nodes.filter { $0.type == .loss && !inferenceTemporaryNodeIds.contains($0.id) }
                .compactMap { $0.lossConfig }
                .flatMap { $0.inputPortIds }
        )
        return drawableConnections.filter { conn in
            let rawConn = connections.first(where: { $0.id == conn.id })
            guard let raw = rawConn else { return true }
            if hiddenNodeIds.contains(raw.sourceNodeId) || hiddenNodeIds.contains(raw.targetNodeId) { return false }
            if hiddenPortIds.contains(raw.sourceNodeId) || hiddenPortIds.contains(raw.targetNodeId) { return false }
            return true
        }
    }
}
