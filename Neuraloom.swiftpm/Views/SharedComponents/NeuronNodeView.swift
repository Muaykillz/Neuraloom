import SwiftUI

struct NeuronNodeView: View {
    @ObservedObject var viewModel: CanvasViewModel
    var node: NodeViewModel
    
    var isHovered: Bool { viewModel.hoveredNodeId == node.id }

    var isSelected: Bool { viewModel.selectedNodeId == node.id }

    private var roleLabel: String {
        switch node.role {
        case .input:  return "I"
        case .output: return "O"
        case .bias:   return "1"
        case .hidden: return "N"
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.orange)
                .frame(width: 50, height: 50)
                .overlay(
                    Text(roleLabel)
                        .font(.system(.callout, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: isSelected ? 3 : 0)
                        .frame(width: 50, height: 50)
                )
                .shadow(
                    color: Color.orange.opacity(isHovered ? 0.4 : 0.25),
                    radius: isHovered ? 12 : 6,
                    x: 0,
                    y: isHovered ? 6 : 3
                )
                .scaleEffect(isHovered ? 1.15 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
                .gesture(
                    DragGesture(coordinateSpace: .named("canvas"))
                        .onChanged { value in
                            viewModel.handleNodeDrag(id: node.id, location: value.location)
                        }
                )
                .onTapGesture {
                    viewModel.selectedNodeId = (viewModel.selectedNodeId == node.id) ? nil : node.id
                }
                .popover(isPresented: Binding(
                    get: { viewModel.selectedNodeId == node.id },
                    set: { if !$0 { viewModel.selectedNodeId = nil } }
                )) {
                    NodePopoverView(viewModel: viewModel, node: node)
                }

            // Connection Handle with better visibility
            Circle()
                .fill(Color.white)
                .frame(width: 18, height: 18)
                .overlay(
                    Circle()
                        .stroke(Color.orange, lineWidth: 2.5)
                )
                .offset(x: 24)
                .gesture(
                    DragGesture(coordinateSpace: .named("canvas"))
                        .onChanged { value in
                            if viewModel.activeWiringSource == nil {
                                viewModel.startWiring(sourceId: node.id, location: value.location)
                            } else {
                                viewModel.updateWiringTarget(location: value.location)
                            }
                        }
                        .onEnded { value in
                            viewModel.endWiring(sourceId: node.id, location: value.location)
                        }
                )
        }
        .position(node.position)
    }
}

struct NeuronNodeView_Previews: PreviewProvider {
    static var previews: some View {
        let vm = CanvasViewModel()
        vm.nodes = [NodeViewModel(id: UUID(), position: CGPoint(x: 100, y: 100), type: .neuron)]
        return NeuronNodeView(viewModel: vm, node: vm.nodes[0]).previewLayout(.sizeThatFits)
    }
}

