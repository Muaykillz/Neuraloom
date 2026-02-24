import SwiftUI

struct WeightPopoverView: View {
    @ObservedObject var viewModel: CanvasViewModel
    let connection: ConnectionViewModel
    @State private var editingValue: String = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Header
            HStack {
                Text("Weight")
                    .font(.headline)
                Spacer()
                Button(role: .destructive) {
                    viewModel.selectedConnectionId = nil
                    viewModel.deleteConnection(id: connection.id)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.selectedConnectionId = nil
                    viewModel.connectionTapGlobalLocation = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Value (editable)
            HStack {
                Text("Value")
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("0.0", text: $editingValue)
                    .keyboardType(.decimalPad)
                    .font(.caption.monospaced())
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                    .focused($fieldFocused)
                    .onChange(of: editingValue) { _, v in
                        if let d = Double(v) {
                            viewModel.updateConnectionValue(id: connection.id, value: d)
                        }
                    }
                    .onChange(of: connection.value) { _, newVal in
                        if !fieldFocused {
                            editingValue = String(format: "%.4f", newVal)
                        }
                    }
                    .onAppear {
                        editingValue = String(format: "%.4f", connection.value)
                    }
            }

            // Gradient
            HStack {
                Text("Gradient")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.4f", connection.gradient))
                    .fontDesign(.monospaced)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(width: 260)
    }

}
