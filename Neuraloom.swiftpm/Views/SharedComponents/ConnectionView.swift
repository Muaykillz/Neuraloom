import SwiftUI

struct ConnectionView: Shape {
    var from: CGPoint
    var to: CGPoint

    var animatableData: AnimatablePair<CGPoint.AnimatableData, CGPoint.AnimatableData> {
        get { AnimatablePair(from.animatableData, to.animatableData) }
        set { from.animatableData = newValue.first; to.animatableData = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: from)
        let controlWidth = abs(to.x - from.x) * 0.5
        let control1 = CGPoint(x: from.x + controlWidth, y: from.y)
        let control2 = CGPoint(x: to.x - controlWidth, y: to.y)
        path.addCurve(to: to, control1: control1, control2: control2)
        return path
    }
}

// Uses strokedPath as fill so hit testing works on thin/vertical lines
struct ConnectionHitArea: Shape {
    var from: CGPoint
    var to: CGPoint

    func path(in rect: CGRect) -> Path {
        var base = Path()
        base.move(to: from)
        let controlWidth = abs(to.x - from.x) * 0.5
        let control1 = CGPoint(x: from.x + controlWidth, y: from.y)
        let control2 = CGPoint(x: to.x - controlWidth, y: to.y)
        base.addCurve(to: to, control1: control1, control2: control2)
        return base.strokedPath(StrokeStyle(lineWidth: 20, lineCap: .round))
    }
}
