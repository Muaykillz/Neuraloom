import SwiftUI

struct TrainingPanelView: View {
    @ObservedObject var viewModel: CanvasViewModel
    @State private var isExpanded = false
    @State private var epochsText = "500"
    @State private var lrText = "0.1"
    @State private var autoStepTimer: Timer?
    @State private var pressStart: Date?

    var body: some View {
        VStack(spacing: 0) {
            if isExpanded {
                HStack(spacing: 16) {

                    // Mode switcher
                    Picker("Mode", selection: $viewModel.playgroundMode) {
                        Text("Dev").tag(PlaygroundMode.dev)
                        Text("Inspect").tag(PlaygroundMode.inspect)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 130)

                    Divider().frame(height: 20)

                    // Learning Rate
                    HStack(spacing: 4) {
                        Text("LR").font(.caption2).foregroundStyle(.secondary)
                        TextField("0.1", text: $lrText)
                            .keyboardType(.decimalPad)
                            .font(.caption.monospaced())
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 52)
                            .disabled(viewModel.isTraining)
                            .onChange(of: lrText) { _, v in
                                if let d = Double(v) { viewModel.learningRate = d }
                            }
                    }

                    // Epochs / Steps picker + input
                    HStack(spacing: 4) {
                        Menu {
                            Button("Epochs")  { viewModel.stepGranularity = .epoch  }
                            Button("Steps") { viewModel.stepGranularity = .sample }
                        } label: {
                            HStack(spacing: 3) {
                                Text(viewModel.stepGranularity == .epoch ? "Epochs" : "Steps")
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .foregroundColor(Color(UIColor.secondaryLabel))
                                    .frame(minWidth: 38, alignment: .leading)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 7))
                                    .foregroundColor(Color(UIColor.secondaryLabel))
                            }
                        }
                        .disabled(viewModel.isTraining)
                        TextField("500", text: $epochsText)
                            .keyboardType(.numberPad)
                            .font(.caption.monospaced())
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                            .disabled(viewModel.isTraining)
                            .onChange(of: epochsText) { _, v in
                                if let n = Int(v), n > 0 { viewModel.totalEpochs = n }
                            }
                    }

                    Divider().frame(height: 20)

                    // Train label + phase indicator
                    HStack(spacing: 3) {
                        Text("Train")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let phase = viewModel.stepPhase {
                            Text(phase == .forward ? "(Forward)" : "(Backward)")
                                .font(.system(size: 9))
                                .foregroundStyle(phase == .forward ? Color.blue : Color.orange)
                        }
                    }
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                    // Step — always one sample; hold ≥1.5s to auto-repeat
                    Image(systemName: "forward.frame.fill")
                        .font(.title3)
                        .foregroundStyle(viewModel.isTraining ? Color.primary.opacity(0.2) : .orange)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: .infinity, pressing: { isPressing in
                            if isPressing && !viewModel.isTraining {
                                pressStart = .now
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    guard pressStart != nil else { return }
                                    startAutoStep()
                                }
                            } else {
                                let wasAutoStepping = autoStepTimer != nil
                                stopAutoStep()
                                if !wasAutoStepping && pressStart != nil && !viewModel.isTraining {
                                    viewModel.stepTraining()
                                }
                                pressStart = nil
                            }
                        }, perform: {})

                    // Run all / Stop
                    Button {
                        if viewModel.isTraining { viewModel.stopTraining() }
                        else { viewModel.startTraining() }
                    } label: {
                        Image(systemName: viewModel.isTraining ? "stop.fill" : "forward.fill")
                            .font(.title3)
                            .foregroundStyle(viewModel.isTraining ? .red : .orange)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // Reset
                    Button { viewModel.resetTraining() } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isTraining)

                    // Status
                    if viewModel.isTraining || viewModel.currentLoss != nil {
                        Divider().frame(height: 20)
                        Text(viewModel.currentLoss.map { clippedFmt($0) } ?? "—")
                            .font(.caption.monospaced().bold())
                            .foregroundStyle(lossColor)
                        Text(viewModel.stepGranularity == .epoch
                             ? "\(viewModel.currentEpoch)/\(viewModel.totalEpochs)"
                             : "\(viewModel.stepCount)/\(viewModel.totalEpochs)")
                            .font(.caption2).foregroundStyle(.secondary)
                    }

                    // Collapse (rightmost)
                    Button {
                        isExpanded = false
                    } label: {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .glassEffect(in: .rect(cornerRadius: 14))
                .transition(.move(edge: .bottom).combined(with: .opacity))

            } else {
                // Collapsed pill
                Button { isExpanded = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.inspectMode ? "magnifyingglass" : "slider.horizontal.3")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(viewModel.isTraining ? .orange : .secondary)
                        if viewModel.isTraining {
                            Circle().fill(Color.orange).frame(width: 6, height: 6)
                        }
                        Text(viewModel.inspectMode ? "Inspect Mode" : "Training Controls")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .glassEffect(in: .capsule)
                }
                .buttonStyle(.plain)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isExpanded)
        .onAppear {
            epochsText = "\(viewModel.totalEpochs)"
            lrText = String(viewModel.learningRate)
            if viewModel.storyExpandTrainingPanel {
                isExpanded = true
                viewModel.storyExpandTrainingPanel = false
            }
        }
        .onChange(of: viewModel.storyExpandTrainingPanel) { _, expand in
            if expand {
                isExpanded = true
                viewModel.storyExpandTrainingPanel = false
            }
        }
    }

    private func startAutoStep() {
        stopAutoStep()
        autoStepTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                self.viewModel.stepTraining()
            }
        }
    }

    private func stopAutoStep() {
        autoStepTimer?.invalidate()
        autoStepTimer = nil
    }

    private var lossColor: Color {
        guard let loss = viewModel.currentLoss else { return .primary }
        if loss < 0.05 { return .green }
        if loss < 0.15 { return .orange }
        return .primary
    }
}
