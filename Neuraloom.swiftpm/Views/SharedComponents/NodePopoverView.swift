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

            // Neuron-only controls
            if node.type == .neuron {
                // Activation (hidden for bias — always outputs 1)
                if node.role != .bias {
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
                }

                // Role
                VStack(alignment: .leading, spacing: 8) {
                    Text("Role")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Toggle(isOn: Binding(
                            get: { node.role == .input },
                            set: { _ in viewModel.setRole(.input, for: node.id) }
                        )) {
                            Label("In", systemImage: "arrow.right.circle")
                        }
                        .toggleStyle(.button)

                        Toggle(isOn: Binding(
                            get: { node.role == .output },
                            set: { _ in viewModel.setRole(.output, for: node.id) }
                        )) {
                            Label("Out", systemImage: "arrow.left.circle")
                        }
                        .toggleStyle(.button)

                        Toggle(isOn: Binding(
                            get: { node.role == .bias },
                            set: { _ in viewModel.setRole(.bias, for: node.id) }
                        )) {
                            Label("Bias", systemImage: "plusminus.circle")
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
