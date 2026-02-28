import SwiftUI

struct OutputDisplayNodeView: View {
    @ObservedObject var viewModel: CanvasViewModel
    var node: NodeViewModel

    private var isSelected: Bool { viewModel.selectedNodeId == node.id }
    private var isGlowing: Bool { viewModel.glowingNodeIds.contains(node.id) }
    private var displayValue: Double { node.outputDisplayValue ?? 0.0 }

    var body: some View {
        ZStack {
            VStack(spacing: 8) {
                HStack {
                    Spacer()
                    Text("Result")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        viewModel.deleteNode(id: node.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.tertiary)
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Text(clippedFmt(displayValue))
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(width: 140)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? Color.green : Color.primary.opacity(0.12),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                    .shadow(
                        color: isGlowing ? Color.green.opacity(0.8) : Color.black.opacity(0.08),
                        radius: isGlowing ? 18 : 8,
                        x: 0, y: isGlowing ? 0 : 3
                    )
                    .animation(.easeInOut(duration: 0.3), value: isGlowing)
            )

            Circle()
                .fill(Color.white)
                .frame(width: 18, height: 18)
                .overlay(Circle().stroke(Color.green, lineWidth: 2.5))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
                .offset(x: -70)
        }
        .position(node.position)
        .onTapGesture {
            if let incomingConn = viewModel.connections.first(where: { $0.targetNodeId == node.id }) {
                let sourceNodeId = incomingConn.sourceNodeId
                
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    // If the source node is already selected, tapping again should deselect and clear glow.
                    if viewModel.selectedNodeId == sourceNodeId {
                        viewModel.selectedNodeId = nil
                        viewModel.clearGlow()
                    } else {
                        // Otherwise, glow the connection/source node and select it to show the popover.
                        viewModel.toggleGlow(nodeIds: [sourceNodeId], connectionIds: [incomingConn.id])
                        viewModel.selectedNodeId = sourceNodeId
                    }
                }
            }
        }
        .gesture(
            DragGesture(coordinateSpace: .named("canvas"))
                .onChanged { value in
                    viewModel.handleNodeDrag(id: node.id, location: value.location)
                }
        )
        .animation(.easeInOut(duration: 0.3), value: displayValue)
    }
}
