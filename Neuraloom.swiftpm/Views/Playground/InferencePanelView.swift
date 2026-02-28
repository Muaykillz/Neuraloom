import SwiftUI

struct InferencePanelView: View {
    @ObservedObject var viewModel: CanvasViewModel
    @State private var showModeMenu = false

    private var isDatasetMode: Bool {
        viewModel.inferenceInputSource == .dataset
    }

    private var buttonLabel: String {
        isDatasetMode && viewModel.predictAllMode ? "Predict All" : "Predict"
    }

    private var buttonIcon: String {
        isDatasetMode && viewModel.predictAllMode ? "forward.fill" : "play.fill"
    }

    private var buttonColor: Color {
        isDatasetMode && viewModel.predictAllMode ? .teal : .green
    }

    var body: some View {
        HStack(spacing: 16) {
            // Split button: [action | chevron]
            HStack(spacing: 0) {
                Button {
                    if isDatasetMode && viewModel.predictAllMode {
                        viewModel.runPredictAll()
                    } else {
                        viewModel.runInference()
                    }
                } label: {
                    HStack(spacing: 6) {
                        if viewModel.isPredicting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: buttonIcon)
                                .font(.caption)
                            Text(buttonLabel)
                                .font(.subheadline.bold())
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(height: 20)
                    .padding(.leading, 20)
                    .padding(.trailing, isDatasetMode ? 12 : 20)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isPredicting)

                if isDatasetMode {
                    Divider()
                        .frame(height: 16)
                        .overlay(Color.white.opacity(0.3))

                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            showModeMenu.toggle()
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 20)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isPredicting)
                    .popover(isPresented: $showModeMenu, arrowEdge: .bottom) {
                        VStack(spacing: 0) {
                            modeMenuItem(
                                label: "Predict All",
                                icon: "forward.fill",
                                selected: viewModel.predictAllMode
                            ) {
                                viewModel.predictAllMode = true
                            }

                            Divider()

                            modeMenuItem(
                                label: "Predict",
                                icon: "play.fill",
                                selected: !viewModel.predictAllMode
                            ) {
                                viewModel.predictAllMode = false
                            }
                        }
                        .frame(width: 170)
                        .presentationCompactAdaptation(.popover)
                    }
                }
            }
            .background(buttonColor.opacity(viewModel.isPredicting ? 0.7 : 1.0), in: Capsule())

            if !viewModel.inferenceOutputNodeIds.isEmpty {
                Divider().frame(height: 20)

                ForEach(viewModel.inferenceOutputNodeIds, id: \.self) { nodeId in
                    let value = viewModel.nodeOutputs[nodeId] ?? 0
                    VStack(spacing: 2) {
                        Text("Result")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.4f", value))
                            .font(.caption.monospaced().bold())
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .glassEffect(in: .rect(cornerRadius: 14))
        .onChange(of: viewModel.inferenceInputSource) {
            showModeMenu = false
        }
    }

    private func modeMenuItem(label: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            showModeMenu = false
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption)
                    .frame(width: 16)
                Text(label)
                    .font(.subheadline)
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .font(.caption2.bold())
                        .foregroundStyle(.teal)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
