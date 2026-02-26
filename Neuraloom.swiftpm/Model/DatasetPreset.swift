import Foundation

enum DatasetPreset: String, CaseIterable, Sendable {
    case xor = "XOR"
    case linear = "Linear"
    case circle = "Circle"
    case spiral = "Spiral"

    var columns: [String] {
        switch self {
        case .xor:    return ["X1", "X2", "Y"]
        case .linear: return ["X", "Y"]
        case .circle: return ["X1", "X2", "Y"]
        case .spiral: return ["X1", "X2", "Y"]
        }
    }

    var inputColumnCount: Int {
        switch self {
        case .xor, .circle, .spiral: return 2
        case .linear: return 1
        }
    }

    var rows: [[Double]] {
        switch self {
        case .xor:    return [[0,0,0], [0,1,1], [1,0,1], [1,1,0]]
        case .linear: return Self.generateLinear()
        case .circle: return Self.generateCircle()
        case .spiral: return Self.generateSpiral()
        }
    }

    var trainingData: [([Double], [Double])] {
        let ic = inputColumnCount
        return rows.map { row in
            (Array(row.prefix(ic)), Array(row.suffix(from: ic)))
        }
    }

    // MARK: - Data Generators

    private static func generateLinear() -> [[Double]] {
        (0..<20).map { i in
            let x = Double(i) / 19.0
            let y = 2.0 * x + Double.random(in: -0.1...0.1)
            return [x, y]
        }
    }

    private static func generateCircle() -> [[Double]] {
        (0..<50).map { _ in
            let x = Double.random(in: -1...1)
            let y = Double.random(in: -1...1)
            let label: Double = (x*x + y*y < 0.5) ? 1.0 : 0.0
            return [x, y, label]
        }
    }

    private static func generateSpiral() -> [[Double]] {
        var data: [[Double]] = []
        let n = 50
        for i in 0..<n {
            let t = Double(i) / Double(n) * 2.0 * .pi
            let r = Double(i) / Double(n)
            data.append([r * cos(t), r * sin(t), 0.0])
            data.append([r * cos(t + .pi), r * sin(t + .pi), 1.0])
        }
        return data
    }
}

struct DatasetNodeConfig {
    var preset: DatasetPreset = .xor
    var columnPortIds: [UUID]
    var cachedRows: [[Double]]

    init(preset: DatasetPreset = .xor) {
        self.preset = preset
        self.columnPortIds = preset.columns.map { _ in UUID() }
        self.cachedRows = preset.rows
    }

    var rows: [[Double]] { cachedRows }

    var trainingData: [([Double], [Double])] {
        let ic = preset.inputColumnCount
        return cachedRows.map { row in
            (Array(row.prefix(ic)), Array(row.suffix(from: ic)))
        }
    }

    mutating func updatePreset(_ newPreset: DatasetPreset) {
        preset = newPreset
        cachedRows = newPreset.rows
        if columnPortIds.count != newPreset.columns.count {
            columnPortIds = newPreset.columns.map { _ in UUID() }
        }
    }

    mutating func regenerate() {
        cachedRows = preset.rows
    }
}
