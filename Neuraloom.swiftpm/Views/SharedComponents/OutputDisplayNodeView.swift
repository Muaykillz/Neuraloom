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
                Text("Result")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(String(format: "%.4f", displayValue))
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
            viewModel.selectedNodeId = (viewModel.selectedNodeId == node.id) ? nil : node.id
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
