import SwiftUI

struct AnnotationNodeView: View {
    @ObservedObject var viewModel: CanvasViewModel
    var node: NodeViewModel

    @State private var isEditing = false
    @FocusState private var isFocused: Bool

    private var isSelected: Bool { viewModel.selectedNodeId == node.id }
    private var nodeIndex: Int? { viewModel.nodes.firstIndex(where: { $0.id == node.id }) }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if isEditing, let idx = nodeIndex {
                    TextField("Note", text: $viewModel.nodes[idx].annotationText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .fixedSize()
                        .focused($isFocused)
                        .onSubmit { isEditing = false }
                        .onChange(of: isFocused) { _, focused in
                            if !focused { isEditing = false }
                        }
                } else {
                    Text(node.annotationText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(isSelected ? 0.2 : 0.06), lineWidth: 1)
            )

            if isSelected {
                Button {
                    viewModel.deleteNode(id: node.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white, .red)
                }
                .buttonStyle(.plain)
                .offset(x: 8, y: -8)
            }
        }
        .position(node.position)
        .onTapGesture(count: 2) {
            isEditing = true
            isFocused = true
        }
        .onTapGesture {
            viewModel.selectedNodeId = isSelected ? nil : node.id
        }
        .gesture(
            DragGesture(coordinateSpace: .named("canvas"))
                .onChanged { value in
                    viewModel.handleNodeDrag(id: node.id, location: value.location)
                }
        )
    }
}
