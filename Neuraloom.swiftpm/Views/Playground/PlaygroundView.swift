import SwiftUI

struct PlaygroundView: View {
    @EnvironmentObject var canvasViewModel: CanvasViewModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar
            List {
                Section("Components") {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 16)], spacing: 12) {
                        ForEach(NodeViewModel.NodeType.allCases, id: \.self) { type in
                            ComponentItemView(type: type)
                                .onTapGesture {
                                    canvasViewModel.addNode(type: type, at: CGPoint(x: 400, y: 300))
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .padding(12)
                .listRowInsets(EdgeInsets())
            }
        } detail: {
            GeometryReader { geometry in
                // Main Canvas Area
                ZStack {
                    DotGridView(
                        scale: canvasViewModel.scale,
                        offset: canvasViewModel.offset,
                        dotSpacing: 20
                    )
                    .background(Color(UIColor.systemBackground))
                    .onTapGesture {
                        canvasViewModel.selectedConnectionId = nil
                        canvasViewModel.connectionTapGlobalLocation = nil
                        canvasViewModel.clearGlow()
                    }
                    
                    ZStack {
                        ForEach(canvasViewModel.drawableConnections) { conn in
                            let isSelected = canvasViewModel.selectedConnectionId == conn.id
                            let isGlowing = canvasViewModel.glowingConnectionIds.contains(conn.id)
                            let absW = abs(conn.value)
                            let glowTint: Color = conn.isUtilityLink ? .blue : .orange
                            let lineColor: Color = conn.isUtilityLink
                                ? (isGlowing ? Color.blue : (isSelected ? Color.blue : Color.blue.opacity(0.3)))
                                : isGlowing ? Color.orange
                                : (isSelected ? Color.orange : (absW < 0.05
                                    ? Color.primary.opacity(0.35)
                                    : Color.orange.opacity(0.3 + min(absW / 3.0, 1.0) * 0.7)))
                            let lineStyle = conn.isUtilityLink
                                ? StrokeStyle(lineWidth: isGlowing ? 4 : (isSelected ? 4 : 3), dash: [8, 5])
                                : StrokeStyle(lineWidth: isGlowing ? 6 : (isSelected ? 5 : 4))
                            ZStack {
                                // Glow shadow layer
                                if isGlowing {
                                    ConnectionView(from: conn.from, to: conn.to, detourY: conn.detourY)
                                        .stroke(glowTint.opacity(0.4), style: StrokeStyle(lineWidth: 12))
                                        .blur(radius: 4)
                                }
                                // Visible line
                                ConnectionView(from: conn.from, to: conn.to, detourY: conn.detourY)
                                    .stroke(lineColor, style: lineStyle)
                                    .animation(.easeInOut(duration: 0.4), value: conn.value)

                                // Hit area for tap interaction
                                ConnectionHitArea(from: conn.from, to: conn.to, detourY: conn.detourY)
                                    .fill(Color.white.opacity(0.001))
                                    .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .global)
                                        .onEnded { value in
                                            if conn.isUtilityLink {
                                                let newId = canvasViewModel.selectedConnectionId == conn.id ? nil : conn.id
                                                canvasViewModel.selectedConnectionId = newId
                                                canvasViewModel.connectionTapGlobalLocation = nil
                                            } else {
                                                let newId = canvasViewModel.selectedConnectionId == conn.id ? nil : conn.id
                                                canvasViewModel.selectedConnectionId = newId
                                                canvasViewModel.connectionTapGlobalLocation = newId != nil ? value.location : nil
                                            }
                                        }
                                    )
                            }
                        }
                        
                        // Weight value labels (inspect mode)
                        if canvasViewModel.inspectMode {
                            ForEach(canvasViewModel.drawableConnections) { conn in
                                if !conn.isUtilityLink {
                                    let pos = bezierPoint(from: conn.from, to: conn.to, detourY: conn.detourY, t: 0.2)
                                    Text(String(format: "%.2f", conn.value))
                                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(.background.opacity(0.9), in: RoundedRectangle(cornerRadius: 3))
                                        .position(pos)
                                        .allowsHitTesting(false)
                                }
                            }
                        }

                        if let wiring = canvasViewModel.temporaryWiringLine {
                            ConnectionView(from: wiring.from, to: wiring.to)
                                .stroke(checkIfWiringIsInvalid() ? Color.red : Color.primary.opacity(0.4), lineWidth: 4)
                                .opacity(0.6)
                        }
                        
                        ForEach(canvasViewModel.nodes) { node in
                            CanvasNodeView(viewModel: canvasViewModel, node: node)
                        }

                        // Delete button for selected utility connection
                        if let connId = canvasViewModel.selectedConnectionId,
                           let conn = canvasViewModel.drawableConnections.first(where: { $0.id == connId }),
                           conn.isUtilityLink {
                            let mid = CGPoint(x: (conn.from.x + conn.to.x) / 2,
                                              y: conn.detourY ?? (conn.from.y + conn.to.y) / 2)
                            Button {
                                canvasViewModel.selectedConnectionId = nil
                                canvasViewModel.deleteConnection(id: connId)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(.white, .red)
                                    .shadow(radius: 2)
                            }
                            .buttonStyle(.plain)
                            .position(mid)
                        }
                    }
                    .scaleEffect(canvasViewModel.scale, anchor: .topLeading)
                    .offset(canvasViewModel.offset)
                }
                .coordinateSpace(name: "canvas")
                .ignoresSafeArea()
                // Weight floating card — positioned at tap location
                .overlay(alignment: .topLeading) {
                    if let connId = canvasViewModel.selectedConnectionId,
                       let tapGlobal = canvasViewModel.connectionTapGlobalLocation,
                       let connection = canvasViewModel.connections.first(where: { $0.id == connId }) {

                        GeometryReader { overlayGeo in
                            let cardWidth: CGFloat = 260
                            let localX = tapGlobal.x - overlayGeo.frame(in: .global).minX
                            let localY = tapGlobal.y - overlayGeo.frame(in: .global).minY
                            let leftX = min(max(localX - cardWidth / 2, 16), overlayGeo.size.width - cardWidth - 16)

                            WeightPopoverView(viewModel: canvasViewModel, connection: connection)
                                .glassEffect(in: .rect(cornerRadius: 16))
                                .frame(width: cardWidth, alignment: .top)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.leading, leftX)
                                .padding(.top, localY + 16)
                                .transition(.scale(scale: 0.9, anchor: .top).combined(with: .opacity))
                        }
                    }
                }
                .overlay(alignment: .top) {
                    if let message = canvasViewModel.toastMessage {
                        Text(message)
                            .font(.subheadline).bold().foregroundColor(.white)
                            .padding(.vertical, 12).padding(.horizontal, 20)
                            .background(Capsule().fill(Color.black.opacity(0.8)).shadow(radius: 10))
                            .padding(.top, 60)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    VStack(spacing: 12) {
                        Button { canvasViewModel.autoLayout() } label: {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.title2)
                                .foregroundStyle(.orange)
                                .frame(width: 44, height: 44)
                                .contentShape(Circle())
                                .glassEffect(in: .circle)
                        }
                        .buttonStyle(.plain)

                        Button { canvasViewModel.fitToScreen(in: geometry.size, insets: geometry.safeAreaInsets) } label: {
                            Image(systemName: "scope")
                                .font(.title2)
                                .foregroundStyle(.orange)
                                .frame(width: 44, height: 44)
                                .contentShape(Circle())
                                .glassEffect(in: .circle)
                        }
                        .buttonStyle(.plain)
                    }.padding(24)
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in canvasViewModel.handlePan(translation: value.translation) }
                        .onEnded { _ in canvasViewModel.endPan() }
                )
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in canvasViewModel.handleZoom(magnification: value.magnification, anchor: value.startLocation) }
                        .onEnded { value in canvasViewModel.endZoom(magnification: value.magnification, anchor: value.startLocation) }
                )
                .navigationTitle("Playground")
                .onAppear {
                    DispatchQueue.main.async {
                        canvasViewModel.fitToScreen(in: geometry.size, insets: geometry.safeAreaInsets)
                    }
                }
                .overlay(alignment: .bottom) {
                    TrainingPanelView(viewModel: canvasViewModel)
                        .padding(.bottom, 32)
                }
            }
        }
        .navigationSplitViewStyle(.automatic)
    }
    
    /// Evaluate cubic bezier at parameter t, matching ConnectionView's control points.
    private func bezierPoint(from: CGPoint, to: CGPoint, detourY: CGFloat?, t: CGFloat) -> CGPoint {
        let c1: CGPoint
        let c2: CGPoint
        if let dy = detourY {
            c1 = CGPoint(x: from.x, y: dy)
            c2 = CGPoint(x: to.x, y: dy)
        } else {
            let cw = abs(to.x - from.x) * 0.5
            c1 = CGPoint(x: from.x + cw, y: from.y)
            c2 = CGPoint(x: to.x - cw, y: to.y)
        }
        let u = 1 - t
        let x = u*u*u*from.x + 3*u*u*t*c1.x + 3*u*t*t*c2.x + t*t*t*to.x
        let y = u*u*u*from.y + 3*u*u*t*c1.y + 3*u*t*t*c2.y + t*t*t*to.y
        return CGPoint(x: x, y: y)
    }

    private func checkIfWiringIsInvalid() -> Bool {
        guard let sourceId = canvasViewModel.activeWiringSource,
              let targetPos = canvasViewModel.wiringTargetPosition,
              let targetNode = canvasViewModel.findNode(at: targetPos) else { return false }
        return canvasViewModel.wouldCreateCycle(from: sourceId, to: targetNode.id)
    }
}

// MARK: - Canvas Node Dispatcher
struct CanvasNodeView: View {
    @ObservedObject var viewModel: CanvasViewModel
    var node: NodeViewModel

    var body: some View {
        switch node.type {
        case .visualization:
            VisualizationNodeView(viewModel: viewModel, node: node)
        case .dataset:
            DatasetNodeView(viewModel: viewModel, node: node)
        case .loss:
            LossNodeView(viewModel: viewModel, node: node)
        default:
            NeuronNodeView(viewModel: viewModel, node: node)
        }
    }
}

// MARK: - Component Item
struct ComponentItemView: View {
    let type: NodeViewModel.NodeType

    var body: some View {
        VStack(spacing: 8) {
            switch type {
            case .neuron:
                Circle()
                    .fill(Color.orange)
                    .frame(width: 40, height: 40)
                    .overlay(Text("N").font(.caption).foregroundColor(.white))
            case .dataset:
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue)
                    .frame(width: 40, height: 40)
                    .overlay(Text("Data").font(.caption2).foregroundColor(.white))
            case .loss:
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.red)
                    .frame(width: 40, height: 40)
                    .overlay(Image(systemName: "target").foregroundColor(.white))
            case .visualization:
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.purple)
                    .frame(width: 40, height: 40)
                    .overlay(Image(systemName: "chart.xyaxis.line").foregroundColor(.white))
            case .annotation:
                Image(systemName: "note.text")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
            }

            Text(type.rawValue)
                .font(.caption)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
    }
}

struct PlaygroundView_Previews: PreviewProvider {
    static var previews: some View {
        PlaygroundView()
            .environmentObject(CanvasViewModel())
            .preferredColorScheme(.dark)
            .previewInterfaceOrientation(.landscapeLeft)
    }
}
