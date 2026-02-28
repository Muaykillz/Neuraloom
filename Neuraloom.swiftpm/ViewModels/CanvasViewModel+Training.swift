import SwiftUI

extension CanvasViewModel {

    // MARK: - Training Control

    func startTraining() {
        guard !isTraining else { return }

        isTraining = true
        fulfillTourCondition(.trainStarted)
        if storyLRChanged {
            fulfillTourCondition(.custom(id: "lrChanged"))
        }

        if currentEpoch == 0 && stepCount == 0 {
            lossHistory = []
            sampleLossAccumulator = []
            currentLoss = nil
        }
        activeSampleIndex = nil

        if stepGranularity == .epoch {
            startEpochTraining()
        } else {
            startSampleTraining()
        }
    }

    private func startEpochTraining() {
        let compiled: TrainingService.CompiledNetwork
        if let existing = trainingService.currentSteppingNetwork() {
            compiled = existing
        } else {
            do { compiled = try trainingService.buildNetwork(nodes: nodes, connections: connections) }
            catch { triggerToast(error.localizedDescription); isTraining = false; return }
        }

        let config = TrainingConfig(
            learningRate: learningRate,
            lossFunction: selectedLossFunction,
            totalEpochs: totalEpochs,
            batchSize: 4
        )
        trainingService.startTraining(compiled: compiled, config: config, startEpoch: currentEpoch) { [weak self] update in
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.currentEpoch = update.epoch
                self.currentLoss = update.loss
                self.lossHistory.append(update.loss)
                self.applyWeightSync(update.weightSync)
                self.applyNodeSync(update.nodeSync)
            }
        } onComplete: { [weak self] in
            await MainActor.run { self?.isTraining = false }
        }
    }

    private func startSampleTraining() {
        let target = totalEpochs
        sampleTrainingTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isTraining else {
                    self?.sampleTrainingTimer?.invalidate()
                    self?.sampleTrainingTimer = nil
                    return
                }
                if self.stepCount >= target {
                    self.sampleTrainingTimer?.invalidate()
                    self.sampleTrainingTimer = nil
                    self.isTraining = false
                    return
                }
                self.performOneStep()
            }
        }
    }

    func stopTraining() {
        trainingService.stopTraining()
        sampleTrainingTimer?.invalidate()
        sampleTrainingTimer = nil
        isTraining = false
        activeSampleIndex = nil
    }

    func stepTraining() {
        guard !isTraining else { return }
        performOneStep()
    }

    private func performOneStep() {
        let config = TrainingConfig(
            learningRate: learningRate,
            lossFunction: selectedLossFunction,
            totalEpochs: totalEpochs,
            batchSize: 4
        )
        trainingService.stepTraining(
            granularity: stepGranularity,
            nodes: nodes,
            connections: connections,
            config: config
        ) { [weak self] update in
            guard let self else { return }
            let prevEpoch = self.currentEpoch
            self.currentEpoch = update.epoch
            self.currentLoss = update.loss
            self.stepCount += 1

            if self.stepGranularity == .epoch {
                self.lossHistory.append(update.loss)
            } else {
                self.sampleLossAccumulator.append(update.loss)
                if update.epoch > prevEpoch && !self.sampleLossAccumulator.isEmpty {
                    let avg = self.sampleLossAccumulator.reduce(0, +) / Double(self.sampleLossAccumulator.count)
                    self.lossHistory.append(avg)
                    self.sampleLossAccumulator = []
                }
            }
            self.applyWeightSync(update.weightSync)
            self.applyNodeSync(update.nodeSync)
            self.stepPhase = update.phase
            self.activeSampleIndex = update.sampleIndex
            self.activeSampleTarget = update.sampleTarget
            self.fulfillTourCondition(.trainingStepRun)
            self.storyStepCounter += 1
            if self.storyStepCounter >= 2 {
                self.fulfillTourCondition(.custom(id: "stepped2Times"))
            }
            if self.storyStepCounter >= 6 {
                self.fulfillTourCondition(.custom(id: "stepped6Times"))
            }
        }
    }

    // MARK: - Reset

    func resetTraining() {
        trainingService.resetTraining()
        sampleTrainingTimer?.invalidate()
        sampleTrainingTimer = nil
        isTraining = false
        lossHistory = []
        sampleLossAccumulator = []
        currentEpoch = 0
        stepCount = 0
        currentLoss = nil
        activeSampleIndex = nil
        activeSampleTarget = nil
        nodeOutputs = [:]
        nodeGradients = [:]
        stepPhase = nil
        clearGlow()
        for i in connections.indices {
            let src = connections[i].sourceNodeId
            let isBias = nodes.first(where: { $0.id == src })?.isBias == true
            let isUtility = columnPortPosition(portId: src) != nil
                || lossPortPosition(portId: connections[i].targetNodeId) != nil
            connections[i].value = (isBias || isUtility) ? 0.0 : Double.random(in: -1.0...1.0)
            connections[i].gradient = 0.0
        }
    }

    // MARK: - Sync

    private func applyWeightSync(_ sync: [UUID: (value: Double, gradient: Double)]) {
        for (connId, vals) in sync {
            if let ci = connections.firstIndex(where: { $0.id == connId }) {
                connections[ci].value = vals.value
                connections[ci].gradient = vals.gradient
            }
        }
    }

    private func applyNodeSync(_ sync: [UUID: (value: Double, gradient: Double)]) {
        for (nodeId, vals) in sync {
            nodeOutputs[nodeId] = vals.value
            nodeGradients[nodeId] = vals.gradient
        }
    }

    // MARK: - Glow

    func toggleGlow(nodeIds: Set<UUID> = [], connectionIds: Set<UUID> = []) {
        if glowingNodeIds == nodeIds && glowingConnectionIds == connectionIds {
            clearGlow()
        } else {
            glowingNodeIds = nodeIds
            glowingConnectionIds = connectionIds
        }
    }

    func clearGlow() {
        glowingNodeIds = []
        glowingConnectionIds = []
    }
}
