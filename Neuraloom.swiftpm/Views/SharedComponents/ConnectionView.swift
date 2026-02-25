import SwiftUI

struct ConnectionView: Shape {
    var from: CGPoint
    var to: CGPoint
    /// When set, both control points are pushed down to this Y, creating a smooth
    /// arc that detours below the neural network instead of cutting through it.
    var detourY: CGFloat?

    var animatableData: AnimatablePair<CGPoint.AnimatableData, CGPoint.AnimatableData> {
        get { AnimatablePair(from.animatableData, to.animatableData) }
        set { from.animatableData = newValue.first; to.animatableData = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: from)
        if let dy = detourY {
            // Smooth arc: both control points sit at detourY
            path.addCurve(
                to: to,
                control1: CGPoint(x: from.x, y: dy),
                control2: CGPoint(x: to.x, y: dy)
            )
        } else {
            let cw = abs(to.x - from.x) * 0.5
            path.addCurve(
                to: to,
                control1: CGPoint(x: from.x + cw, y: from.y),
                control2: CGPoint(x: to.x - cw, y: to.y)
            )
        }
        return path
    }
}

// Uses strokedPath as fill so hit testing works on thin/vertical lines
struct ConnectionHitArea: Shape {
    var from: CGPoint
    var to: CGPoint
    var detourY: CGFloat?

    func path(in rect: CGRect) -> Path {
        let base = ConnectionView(from: from, to: to, detourY: detourY).path(in: rect)
        return base.strokedPath(StrokeStyle(lineWidth: 20, lineCap: .round))
    }
}
