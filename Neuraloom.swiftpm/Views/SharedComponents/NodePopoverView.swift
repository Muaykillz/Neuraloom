import SwiftUI

struct NodePopoverView: View {
    @ObservedObject var viewModel: CanvasViewModel
    let node: NodeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Header
            HStack {
                Text(node.type.rawValue)
                    .font(.headline)
                Spacer()
                Button(role: .destructive) {
                    viewModel.selectedNodeId = nil
                    viewModel.deleteNode(id: node.id)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Activation (neuron only)
            if node.type == .neuron {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Activation")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Picker("Activation", selection: Binding(
                        get: { node.activation },
                        set: { viewModel.updateActivation(id: node.id, activation: $0) }
                    )) {
                        Text("ReLU").tag(ActivationType.relu)
                        Text("Sigmoid").tag(ActivationType.sigmoid)
                        Text("Linear").tag(ActivationType.linear)
                    }
                    .pickerStyle(.segmented)
                }

                Divider()

                // I/O Markers
                VStack(alignment: .leading, spacing: 8) {
                    Text("Role")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Toggle(isOn: Binding(
                            get: { node.isInput },
                            set: { _ in viewModel.toggleInput(id: node.id) }
                        )) {
                            Label("Input", systemImage: "arrow.right.circle")
                        }
                        .toggleStyle(.button)

                        Toggle(isOn: Binding(
                            get: { node.isOutput },
                            set: { _ in viewModel.toggleOutput(id: node.id) }
                        )) {
                            Label("Output", systemImage: "arrow.left.circle")
                        }
                        .toggleStyle(.button)
                    }
                }
            }
        }
        .padding()
        .frame(width: 280)
    }
}
