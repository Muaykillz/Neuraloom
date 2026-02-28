import SwiftUI
import Charts

struct ScatterPlotNodeView: View {
    @ObservedObject var viewModel: CanvasViewModel
    var node: NodeViewModel

    private let cardWidth: CGFloat = 240
    private let cardHeight: CGFloat = 200
    private let portRadius: CGFloat = DatasetNodeLayout.portRadius
    private let portSpacing: CGFloat = DatasetNodeLayout.portSpacing

    var isSelected: Bool { viewModel.selectedNodeId == node.id }
    var isGlowing: Bool { viewModel.glowingNodeIds.contains(node.id) }

    var body: some View {
        ZStack {
            cardBody
                .onTapGesture {
                    viewModel.selectedNodeId = (viewModel.selectedNodeId == node.id) ? nil : node.id
                }

            if let config = node.scatterPlotConfig {
                let totalH = CGFloat(config.inputPortIds.count - 1) * portSpacing
                ForEach(ScatterPlotConfig.portLabels.indices, id: \.self) { pi in
                    let yOff = CGFloat(pi) * portSpacing - totalH / 2
                    Text(ScatterPlotConfig.portLabels[pi])
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.teal.opacity(0.85))
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(.background.opacity(0.9), in: RoundedRectangle(cornerRadius: 3))
                        .offset(x: -(cardWidth / 2 + portRadius + 12), y: yOff)
                    Circle()
                        .fill(Color.white)
                        .frame(width: portRadius * 2, height: portRadius * 2)
                        .overlay(Circle().stroke(Color.teal, lineWidth: 2.5))
                        .offset(x: -(cardWidth / 2 + 3), y: yOff)
                }
            }
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
                            isSelected ? Color.teal : Color.primary.opacity(0.12),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
                .shadow(color: isGlowing ? Color.teal.opacity(0.8) : Color.black.opacity(0.08),
                        radius: isGlowing ? 18 : 8, x: 0, y: isGlowing ? 0 : 3)
                .animation(.easeInOut(duration: 0.3), value: isGlowing)

            VStack(spacing: 0) {
                headerRow
                    .padding(.horizontal, 10)
                    .padding(.top, 8)

                chartContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
            }
            .frame(width: cardWidth, height: cardHeight)
        }
    }

    private var headerRow: some View {
        HStack(spacing: 5) {
            Image(systemName: "chart.dots.scatter")
                .font(.system(size: 10))
                .foregroundStyle(.teal)
            Text("Scatter 2D")
                .font(.caption2.bold())
                .foregroundStyle(.primary)
            Spacer()
            if !node.scatterSeriesA.isEmpty || !node.scatterSeriesB.isEmpty {
                Button {
                    if let idx = viewModel.nodes.firstIndex(where: { $0.id == node.id }) {
                        viewModel.nodes[idx].scatterSeriesA.removeAll()
                        viewModel.nodes[idx].scatterSeriesB.removeAll()
                    }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.teal)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
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
    }

    // MARK: - Chart

    private var chartContent: some View {
        let seriesA = node.scatterSeriesA
        let seriesB = node.scatterSeriesB
        return Chart {
            ForEach(seriesA.indices, id: \.self) { (i: Int) in
                PointMark(
                    x: .value("x", seriesA[i].x),
                    y: .value("y", seriesA[i].y)
                )
                .foregroundStyle(.blue)
                .symbolSize(30)
            }
            ForEach(seriesB.indices, id: \.self) { (i: Int) in
                PointMark(
                    x: .value("x", seriesB[i].x),
                    y: .value("y", seriesB[i].y)
                )
                .foregroundStyle(.orange)
                .symbolSize(30)
            }
        }
        .chartXScale(domain: chartXDomain)
        .chartYScale(domain: chartYDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }

    private var chartXDomain: ClosedRange<Double> {
        if let locked = node.scatterPlotConfig?.xAxisRange { return locked }
        let allX = node.scatterSeriesA.map { $0.x } + node.scatterSeriesB.map { $0.x }
        guard let lo = allX.min(), let hi = allX.max(), lo < hi else { return 0...1 }
        return lo...hi
    }

    private var chartYDomain: ClosedRange<Double> {
        if let locked = node.scatterPlotConfig?.yAxisRange { return locked }
        let allY = node.scatterSeriesA.map { $0.y } + node.scatterSeriesB.map { $0.y }
        guard let lo = allY.min(), let hi = allY.max(), lo < hi else { return 0...1 }
        return lo...hi
    }
}
