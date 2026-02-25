import SwiftUI

enum DatasetNodeLayout {
    static let width: CGFloat = 200
    static let portRadius: CGFloat = 9
    static let rowHeight: CGFloat = 22
    static let maxVisibleRows: Int = 6
    static let portSpacing: CGFloat = 26

    static func height(for config: DatasetNodeConfig) -> CGFloat {
        let headerAndCols: CGFloat = 52 // header + column headers
        let visibleRows = min(config.preset.rows.count, maxVisibleRows)
        let overflow: CGFloat = config.preset.rows.count > maxVisibleRows ? 16 : 0
        return headerAndCols + CGFloat(visibleRows) * rowHeight + overflow + 8
    }

    static func portPosition(nodePosition: CGPoint, columnIndex: Int, totalColumns: Int, nodeHeight: CGFloat) -> CGPoint {
        let totalH = CGFloat(totalColumns - 1) * portSpacing
        let startY = nodePosition.y - totalH / 2
        return CGPoint(
            x: nodePosition.x + width / 2 + portRadius + 2,
            y: startY + CGFloat(columnIndex) * portSpacing
        )
    }
}

struct DatasetNodeView: View {
    @ObservedObject var viewModel: CanvasViewModel
    var node: NodeViewModel

    var isSelected: Bool { viewModel.selectedNodeId == node.id }

    private var config: DatasetNodeConfig {
        node.datasetConfig ?? DatasetNodeConfig()
    }

    private var preset: DatasetPreset { config.preset }
    private var nodeHeight: CGFloat { DatasetNodeLayout.height(for: config) }

    var body: some View {
        ZStack {
            // Main card
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider().padding(.horizontal, 8)
                columnHeaders
                dataRows
                overflowLabel
                Spacer(minLength: 4)
            }
            .frame(width: DatasetNodeLayout.width, height: nodeHeight)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? Color.blue : Color.primary.opacity(0.12),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
            )

            // Port column — overlay on right edge
            portColumn
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

    // MARK: - Subviews

    private var header: some View {
        HStack(spacing: 4) {
            Image(systemName: "tablecells.fill")
                .font(.system(size: 10))
                .foregroundStyle(.blue)

            Menu {
                ForEach(DatasetPreset.allCases, id: \.self) { p in
                    Button(p.rawValue) {
                        viewModel.updateDatasetPreset(nodeId: node.id, preset: p)
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Text(preset.rawValue)
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

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
        .padding(.vertical, 8)
    }

    private var columnHeaders: some View {
        HStack(spacing: 0) {
            ForEach(preset.columns.indices, id: \.self) { ci in
                Text(preset.columns[ci])
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    private var dataRows: some View {
        let visibleRows = Array(preset.rows.prefix(DatasetNodeLayout.maxVisibleRows))
        return ForEach(visibleRows.indices, id: \.self) { ri in
            dataRow(values: visibleRows[ri], rowIndex: ri)
        }
    }

    private func dataRow(values: [Double], rowIndex: Int) -> some View {
        let isActive = viewModel.activeSampleIndex == rowIndex
        return HStack(spacing: 0) {
            ForEach(values.indices, id: \.self) { ci in
                Text(formatValue(values[ci]))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.65))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: DatasetNodeLayout.rowHeight)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isActive ? Color.blue.opacity(0.15) : Color.clear)
        )
        .animation(.easeInOut(duration: 0.15), value: viewModel.activeSampleIndex)
    }

    @ViewBuilder
    private var overflowLabel: some View {
        if preset.rows.count > DatasetNodeLayout.maxVisibleRows {
            Text("+\(preset.rows.count - DatasetNodeLayout.maxVisibleRows) more")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 10)
                .padding(.top, 2)
        }
    }

    @ViewBuilder
    private var portColumn: some View {
        let cols = preset.columns
        let totalH = CGFloat(cols.count - 1) * DatasetNodeLayout.portSpacing
        let pr = DatasetNodeLayout.portRadius
        let cardW = DatasetNodeLayout.width

        ForEach(cols.indices, id: \.self) { ci in
            let portId = config.columnPortIds[ci]
            let yOff = CGFloat(ci) * DatasetNodeLayout.portSpacing - totalH / 2

            // Port circle — flush against right edge of card
            Circle()
                .fill(Color.white)
                .frame(width: pr * 2, height: pr * 2)
                .overlay(Circle().stroke(Color.blue, lineWidth: 2.5))
                .offset(x: cardW / 2 + pr + 2, y: yOff)
                .gesture(
                    DragGesture(coordinateSpace: .named("canvas"))
                        .onChanged { value in
                            if viewModel.activeWiringSource == nil {
                                viewModel.startWiring(sourceId: portId, location: value.location)
                            } else {
                                viewModel.updateWiringTarget(location: value.location)
                            }
                        }
                        .onEnded { value in
                            viewModel.endWiring(sourceId: portId, location: value.location)
                        }
                )

            // Label outside
            Text(cols[ci])
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.blue.opacity(0.85))
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(.background.opacity(0.9), in: RoundedRectangle(cornerRadius: 3))
                .offset(x: cardW / 2 + pr * 2 + 14, y: yOff)
        }
    }

    private func formatValue(_ v: Double) -> String {
        if v == v.rounded() && abs(v) < 100 {
            return String(format: "%.0f", v)
        }
        return String(format: "%.2f", v)
    }
}
