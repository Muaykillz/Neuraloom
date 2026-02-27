import SwiftUI

struct InferencePanelView: View {
    @ObservedObject var viewModel: CanvasViewModel

    var body: some View {
        HStack(spacing: 16) {
            Button {
                viewModel.runInference()
            } label: {
                HStack(spacing: 6) {
                    if viewModel.isPredicting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.caption)
                        Text("Predict")
                            .font(.subheadline.bold())
                    }
                }
                .foregroundStyle(.white)
                .frame(width: 80, height: 20)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.green.opacity(viewModel.isPredicting ? 0.7 : 1.0), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isPredicting)

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
    }
}
