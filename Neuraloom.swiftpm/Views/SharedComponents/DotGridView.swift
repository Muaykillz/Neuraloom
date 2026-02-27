import SwiftUI

struct DotGridView: View {
    var scale: CGFloat = 1.0 // Zoom scale
    var offset: CGSize = .zero // Pan offset
    var dotSpacing: CGFloat = 20 // Spacing between dots

    var body: some View {
        GeometryReader { geometry in
            let visibleContentMinX = -offset.width / scale
            let visibleContentMaxX = visibleContentMinX + geometry.size.width / scale
            let visibleContentMinY = -offset.height / scale
            let visibleContentMaxY = visibleContentMinY + geometry.size.height / scale

            let startGridX = Int((visibleContentMinX / dotSpacing).rounded(.down)) - 1
            let endGridX = Int((visibleContentMaxX / dotSpacing).rounded(.up)) + 1

            let startGridY = Int((visibleContentMinY / dotSpacing).rounded(.down)) - 1
            let endGridY = Int((visibleContentMaxY / dotSpacing).rounded(.up)) + 1
            
            Path { path in
                for gridX in startGridX...endGridX {
                    let x = CGFloat(gridX) * dotSpacing
                    for gridY in startGridY...endGridY {
                        let y = CGFloat(gridY) * dotSpacing
                        
                        let dotX = x * scale + offset.width
                        let dotY = y * scale + offset.height
                        path.addEllipse(in: CGRect(x: dotX - 1, y: dotY - 1, width: 2, height: 2))
                    }
                }
            }
            .fill(Color.primary.opacity(0.12))
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
    }
}

struct DotGridView_Previews: PreviewProvider {
    static var previews: some View {
        DotGridView()
            .preferredColorScheme(.light)
            .previewDisplayName("Light Mode")
        
        DotGridView()
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
    }
}
