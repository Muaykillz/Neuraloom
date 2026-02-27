import SwiftUI

struct NumberNodeView: View {
    @ObservedObject var viewModel: CanvasViewModel
    var node: NodeViewModel

    @State private var isShowingPopover = false
    @State private var editText = ""

    private var isSelected: Bool { viewModel.selectedNodeId == node.id }
    private var isGlowing: Bool { viewModel.glowingNodeIds.contains(node.id) }

    var body: some View {
        ZStack {
            VStack(spacing: 6) {
                HStack {
                    Spacer()
                    Text("Number")
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

                Text(compactFmt(node.numberValue))
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(.teal)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(width: 100)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? Color.teal : Color.primary.opacity(0.12),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                    .shadow(
                        color: isGlowing ? Color.teal.opacity(0.8) : Color.black.opacity(0.08),
                        radius: isGlowing ? 18 : 8,
                        x: 0, y: isGlowing ? 0 : 3
                    )
                    .animation(.easeInOut(duration: 0.3), value: isGlowing)
            )
            .gesture(
                DragGesture(coordinateSpace: .named("canvas"))
                    .onChanged { value in
                        viewModel.handleNodeDrag(id: node.id, location: value.location)
                    }
            )
            .onTapGesture {
                editText = String(format: "%.4f", node.numberValue)
                isShowingPopover.toggle()
            }
            .popover(isPresented: $isShowingPopover, arrowEdge: .top) {
                VStack(spacing: 12) {
                    Text("Value")
                        .font(.headline)
                    TextField("0.0", text: $editText)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 140)
                        .onSubmit { applyEdit() }
                    Button("Apply") { applyEdit() }
                        .buttonStyle(.borderedProminent)
                        .tint(.teal)
                }
                .padding()
                .frame(width: 180)
            }

            // Output port (right side)
            Circle()
                .fill(Color.white)
                .frame(width: 18, height: 18)
                .overlay(Circle().stroke(Color.teal, lineWidth: 2.5))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
                .offset(x: 50)
                .gesture(
                    DragGesture(coordinateSpace: .named("canvas"))
                        .onChanged { value in
                            if viewModel.activeWiringSource == nil {
                                viewModel.startWiring(sourceId: node.id, location: value.location)
                            }
                            viewModel.updateWiringTarget(location: value.location)
                        }
                        .onEnded { value in
                            viewModel.endWiring(sourceId: node.id, location: value.location)
                        }
                )
        }
        .position(node.position)
    }

    private func applyEdit() {
        if let val = Double(editText),
           let idx = viewModel.nodes.firstIndex(where: { $0.id == node.id }) {
            viewModel.nodes[idx].numberValue = val
        }
        isShowingPopover = false
    }
}
