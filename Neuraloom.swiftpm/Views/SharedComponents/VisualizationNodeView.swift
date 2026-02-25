import SwiftUI
import Charts

struct VisualizationNodeView: View {
    @ObservedObject var viewModel: CanvasViewModel
    var node: NodeViewModel

    var isSelected: Bool { viewModel.selectedNodeId == node.id }

    private var chartData: [(Int, Double)] {
        viewModel.lossHistory.enumerated().map { ($0.offset, $0.element) }
    }

    private let cardWidth: CGFloat = 210

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(.regularMaterial)
                .frame(width: cardWidth, height: 148)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isSelected ? Color.purple : Color.primary.opacity(0.12),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 5) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 10))
                        .foregroundStyle(.purple)
                    Text("Loss Curve")
                        .font(.caption2.bold())
                        .foregroundStyle(.primary)
                    Spacer()
                    if viewModel.isTraining {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 5, height: 5)
                    }
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
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 6)

                // Body
                if viewModel.lossHistory.isEmpty {
                    Text("Train to see loss")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Chart {
                        ForEach(chartData, id: \.0) { i, loss in
                            LineMark(
                                x: .value("Step", i),
                                y: .value("Loss", loss)
                            )
                            .foregroundStyle(Color.purple)
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(height: 80)
                    .padding(.horizontal, 10)

                    if let loss = viewModel.currentLoss {
                        Text(String(format: "%.4f", loss))
                            .font(.system(size: 9, design: .monospaced).bold())
                            .foregroundStyle(.purple)
                            .padding(.horizontal, 12)
                            .padding(.top, 2)
                    }
                }

                Spacer(minLength: 8)
            }
            .frame(width: cardWidth, height: 148)

            // Input port (left edge)
            Circle()
                .fill(Color.white)
                .frame(width: 18, height: 18)
                .overlay(Circle().stroke(Color.purple, lineWidth: 2.5))
                .offset(x: -(cardWidth / 2 + 4))
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
    }
}
