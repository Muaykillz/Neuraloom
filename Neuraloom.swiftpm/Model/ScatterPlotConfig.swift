import Foundation

struct ScatterPlotConfig {
    let x1PortId: UUID
    let y1PortId: UUID
    let x2PortId: UUID
    let y2PortId: UUID

    /// Fixed axis range. nil = auto-scale from data.
    var xAxisRange: ClosedRange<Double>?
    var yAxisRange: ClosedRange<Double>?

    var inputPortIds: [UUID] { [x1PortId, y1PortId, x2PortId, y2PortId] }
    static let portLabels = ["x\u{2081}", "y\u{2081}", "x\u{2082}", "y\u{2082}"]

    init() {
        self.x1PortId = UUID()
        self.y1PortId = UUID()
        self.x2PortId = UUID()
        self.y2PortId = UUID()
    }
}
