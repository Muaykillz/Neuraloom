import SwiftUI

struct WeightPopoverView: View {
    @ObservedObject var viewModel: CanvasViewModel
    let connection: ConnectionViewModel

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

            // Value
            HStack {
                Text("Value")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.4f", connection.value))
                    .fontDesign(.monospaced)
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
        .frame(width: 240)
    }
}
