import SwiftUI

struct LossNodeView: View {
    @ObservedObject var viewModel: CanvasViewModel
    var node: NodeViewModel

    private let cardWidth: CGFloat = 120
    private let cardHeight: CGFloat = 72
    private let portRadius: CGFloat = DatasetNodeLayout.portRadius
    private let portSpacing: CGFloat = DatasetNodeLayout.portSpacing

    var isSelected: Bool { viewModel.selectedNodeId == node.id }
    var isGlowing: Bool { viewModel.glowingNodeIds.contains(node.id) }
    private var config: LossNodeConfig? { node.lossConfig }

    var body: some View {
        ZStack {
            cardBody
                .onTapGesture {
                    viewModel.selectedNodeId = (viewModel.selectedNodeId == node.id) ? nil : node.id
                }
                .popover(isPresented: Binding(
                    get: { viewModel.selectedNodeId == node.id },
                    set: { if !$0 { viewModel.selectedNodeId = nil } }
                ), arrowEdge: .top) {
                    NodePopoverView(viewModel: viewModel, node: node)
                        .onDisappear { viewModel.clearGlow() }
                }

            ForEach(LossNodeConfig.portLabels.indices, id: \.self) { pi in
                let yOff = CGFloat(pi) * portSpacing - portSpacing / 2
                Text(LossNodeConfig.portLabels[pi])
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.red.opacity(0.85))
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(.background.opacity(0.9), in: RoundedRectangle(cornerRadius: 3))
                    .offset(x: -(cardWidth / 2 + portRadius + 12), y: yOff)
                Circle()
                    .fill(Color.white)
                    .frame(width: portRadius * 2, height: portRadius * 2)
                    .overlay(Circle().stroke(Color.red, lineWidth: 2.5))
                    .offset(x: -(cardWidth / 2 + 3), y: yOff)
            }

            Circle()
                .fill(Color.white)
                .frame(width: 18, height: 18)
                .overlay(Circle().stroke(Color.red, lineWidth: 2.5))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
                .offset(x: cardWidth / 2)
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
        .gesture(
            DragGesture(coordinateSpace: .named("canvas"))
                .onChanged { value in
                    viewModel.handleNodeDrag(id: node.id, location: value.location)
                }
        )
    }

    // MARK: - Card Body

    private var cardBody: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(.regularMaterial)
                .frame(width: cardWidth, height: cardHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isSelected ? Color.red : Color.primary.opacity(0.12),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
                .shadow(color: glowShadowColor, radius: isGlowing ? 18 : 8, x: 0, y: isGlowing ? 0 : 3)
                .animation(.easeInOut(duration: 0.3), value: isGlowing)

            VStack(spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: "target")
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                    Text(viewModel.selectedLossFunction == .mse ? "MSE" : "Cross-Entropy")
                        .font(.caption2.bold())
                        .foregroundStyle(.primary)
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
                .padding(.horizontal, 10)
                .padding(.top, 8)

                Text(viewModel.currentLoss.map { String(format: "%.4f", $0) } ?? "—")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(lossColor)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
            }
            .frame(width: cardWidth, height: cardHeight)
        }
    }

    private var glowShadowColor: Color {
        isGlowing ? Color.red.opacity(0.8) : Color.black.opacity(0.08)
    }

    private var lossColor: Color {
        guard let loss = viewModel.currentLoss else { return .secondary }
        if loss < 0.05 { return .green }
        if loss < 0.15 { return .orange }
        return .red
    }
}
