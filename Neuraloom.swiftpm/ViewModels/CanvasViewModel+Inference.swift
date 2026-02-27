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

        let autoIds = Set(autoOutputDisplayIds)
        nodes.removeAll { autoIds.contains($0.id) }
        connections.removeAll { autoIds.contains($0.sourceNodeId) || autoIds.contains($0.targetNodeId) }

        playgroundMode = savedPlaygroundMode
        selectedNodeId = savedSelectedNodeId
        selectedConnectionId = savedSelectedConnectionId

        inferenceInputInfos = []
        inferenceInputs = [:]
        inferenceOutputNodeIds = []
        autoOutputDisplayIds = []
        compiledInferenceNetwork = nil

        withAnimation(.spring()) {
            canvasMode = .train
        }
    }

    // MARK: - Run Inference

    func runInference() {
        Task { await runAnimatedInference() }
    }

    private func runAnimatedInference() async {
        guard !isPredicting else { return }
        guard var net = compiledInferenceNetwork else { return }

        isPredicting = true
        defer {
            isPredicting = false
            withAnimation(.easeOut(duration: 0.2)) { clearGlow() }
        }

        let edgeGlowDuration: TimeInterval = 0.1
        let nodeGlowDuration: TimeInterval = 0.15

        let inputNeuronIds = nodes.filter { $0.isInput }.map(\.id)
        var inputValues: [Double] = []
        for neuronId in inputNeuronIds {
            var value = 0.0
            for conn in connections {
                if conn.targetNodeId == neuronId, let v = inferenceInputs[conn.sourceNodeId] {
                    value = v
                    break
                }
            }
            inputValues.append(value)
        }

        for (i, idx) in net.model.inputNodeIndices.enumerated() {
            if i < inputValues.count { net.model.nodeValues[idx] = inputValues[i] }
        }
        for idx in net.model.biasNodeIndices {
            net.model.nodeValues[idx] = 1.0
        }

        for (vmId, modelIdx) in net.nodeVMIdToNodeIdx {
            if net.model.inputNodeIndices.contains(modelIdx) || net.model.biasNodeIndices.contains(modelIdx) {
                await MainActor.run { nodeOutputs[vmId] = net.model.nodeValues[modelIdx] }
            }
        }

        let (layers, _) = computeNodeLayers()
        let idToModelIdx = net.nodeVMIdToNodeIdx

        // Animate from Dataset to Input Layer
        let datasetNodeIds = Set(nodes.filter { $0.type == .dataset }.map(\.id))
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

        // Animate through hidden/output layers
        for (layerIndex, currentLayer) in layers.enumerated() {
            guard !Task.isCancelled else { break }

            let sourceLayerIds = (layerIndex == 0) ? datasetNodeIds : Set(layers[layerIndex - 1])
            let currentLayerIds = Set(currentLayer)

            let incomingToCurrent = connections.filter { conn in
                let targetIsInCurrent = currentLayerIds.contains(conn.targetNodeId)
                let sourceIsInPrevious = sourceLayerIds.contains(conn.sourceNodeId)
                let sourceIsBias = nodes.first(where: { $0.id == conn.sourceNodeId })?.isBias ?? false
                let sourceIsDatasetPort = datasetNodeIds.contains(conn.sourceNodeId)
                    || (nodes.first(where: { $0.type == .dataset })?.datasetConfig?.columnPortIds.contains(conn.sourceNodeId) ?? false)
                return targetIsInCurrent && (sourceIsInPrevious || sourceIsBias || (layerIndex == 0 && sourceIsDatasetPort))
            }

            let allSourceNodeIds = Set(incomingToCurrent.map { $0.sourceNodeId })
                .union(nodes.filter({ $0.isBias && !connections.filter({ incomingToCurrent.map({ $0.id }).contains($0.id) }).map({ $0.sourceNodeId }).contains($0.id) }).map({ $0.id }))

            withAnimation(.easeIn(duration: edgeGlowDuration)) {
                glowingNodeIds = allSourceNodeIds
                glowingConnectionIds = Set(incomingToCurrent.map { $0.id })
            }
            try? await Task.sleep(for: .seconds(edgeGlowDuration))

            withAnimation(.easeIn(duration: nodeGlowDuration)) {
                glowingNodeIds.formUnion(currentLayerIds)
            }

            for nodeId in currentLayer {
                guard let modelIdx = idToModelIdx[nodeId], !net.model.inputNodeIndices.contains(modelIdx) else { continue }

                var sum: Double = 0.0
                for wIdx in net.model.nodeIncomingEdgeIndices[modelIdx] {
                    let sourceNodeIdx = net.model.edgeSourceNodeIndices[wIdx]
                    sum += net.model.nodeValues[sourceNodeIdx] * net.model.weightValues[wIdx]
                }
                net.model.nodeValues[modelIdx] = net.model.nodeActivations[modelIdx].forward(sum)

                await MainActor.run {
                    nodeOutputs[nodeId] = net.model.nodeValues[modelIdx]
                    for outId in autoOutputDisplayIds where connections.contains(where: { $0.sourceNodeId == nodeId && $0.targetNodeId == outId }) {
                        if let nodeIdxToUpdate = nodes.firstIndex(where: { $0.id == outId }) {
                            nodes[nodeIdxToUpdate].outputDisplayValue = net.model.nodeValues[modelIdx]
                        }
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

        compiledInferenceNetwork = net
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
                    if targetDepth == nil || targetDepth! <= sourceDepth {
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

    private var inferenceHiddenNodeTypes: Set<NodeViewModel.NodeType> {
        [.loss, .visualization]
    }

    var visibleNodes: [NodeViewModel] {
        if canvasMode == .train { return nodes }
        return nodes.filter { !inferenceHiddenNodeTypes.contains($0.type) }
    }

    var visibleConnections: [DrawableConnection] {
        if canvasMode == .train { return drawableConnections }
        let hiddenNodeIds = Set(nodes.filter { inferenceHiddenNodeTypes.contains($0.type) }.map(\.id))
        let hiddenPortIds: Set<UUID> = Set(nodes.compactMap { $0.lossConfig }.flatMap { $0.inputPortIds })
        return drawableConnections.filter { conn in
            let rawConn = connections.first(where: { $0.id == conn.id })
            guard let raw = rawConn else { return true }
            if hiddenNodeIds.contains(raw.sourceNodeId) || hiddenNodeIds.contains(raw.targetNodeId) { return false }
            if hiddenPortIds.contains(raw.sourceNodeId) || hiddenPortIds.contains(raw.targetNodeId) { return false }
            return true
        }
    }
}
