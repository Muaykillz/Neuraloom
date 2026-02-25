import Foundation

struct LossNodeConfig {
    let predPortId: UUID   // ŷ input
    let truePortId: UUID   // y input

    var inputPortIds: [UUID] { [predPortId, truePortId] }
    static let portLabels = ["ŷ", "y"]

    init() {
        self.predPortId = UUID()
        self.truePortId = UUID()
    }

    init(predPortId: UUID, truePortId: UUID) {
        self.predPortId = predPortId
        self.truePortId = truePortId
    }
}
