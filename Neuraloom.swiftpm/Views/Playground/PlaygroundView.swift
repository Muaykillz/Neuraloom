import SwiftUI

struct PlaygroundView: View {
    @EnvironmentObject var canvasViewModel: CanvasViewModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

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
                    }
                    
                    ZStack {
                        ForEach(canvasViewModel.drawableConnections) { conn in
                            let isSelected = canvasViewModel.selectedConnectionId == conn.id
                            ZStack {
                                // Visible line
                                ConnectionView(from: conn.from, to: conn.to)
                                    .stroke(isSelected ? Color.orange : Color.primary.opacity(0.4), lineWidth: isSelected ? 5 : 4)

                                // Hit area — strokedPath fill covers full curve including vertical lines
                                ConnectionHitArea(from: conn.from, to: conn.to)
                                    .fill(Color.white.opacity(0.001))
                                    .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .global)
                                        .onEnded { value in
                                            let newId = canvasViewModel.selectedConnectionId == conn.id ? nil : conn.id
                                            canvasViewModel.selectedConnectionId = newId
                                            canvasViewModel.connectionTapGlobalLocation = newId != nil ? value.location : nil
                                        }
                                    )
                            }
                        }
                        
                        if let wiring = canvasViewModel.temporaryWiringLine {
                            ConnectionView(from: wiring.from, to: wiring.to)
                                .stroke(checkIfWiringIsInvalid() ? Color.red : Color.primary.opacity(0.4), lineWidth: 4)
                                .opacity(0.6)
                        }
                        
                        ForEach(canvasViewModel.nodes) { node in
                            NeuronNodeView(viewModel: canvasViewModel, node: node)
                        }
                    }
                    .scaleEffect(canvasViewModel.scale, anchor: .topLeading)
                    .offset(canvasViewModel.offset)
                }
                .coordinateSpace(name: "canvas")
                .ignoresSafeArea()
                // Weight floating card — positioned at tap location
                .overlay {
                    GeometryReader { overlayGeo in
                        if let connId = canvasViewModel.selectedConnectionId,
                           let tapGlobal = canvasViewModel.connectionTapGlobalLocation,
                           let connection = canvasViewModel.connections.first(where: { $0.id == connId }) {

                            let cardWidth: CGFloat = 240
                            let cardHeight: CGFloat = 120
                            let localX = tapGlobal.x - overlayGeo.frame(in: .global).minX
                            let localY = tapGlobal.y - overlayGeo.frame(in: .global).minY
                            let clampedX = min(max(localX, cardWidth / 2 + 16), overlayGeo.size.width - cardWidth / 2 - 16)
                            let clampedY = min(max(localY + 24, cardHeight / 2), overlayGeo.size.height - cardHeight / 2 - 16)

                            WeightPopoverView(viewModel: canvasViewModel, connection: connection)
                                .glassEffect(in: .rect(cornerRadius: 16))
                                .frame(width: cardWidth)
                                .position(x: clampedX, y: clampedY)
                                .transition(.scale(scale: 0.9).combined(with: .opacity))
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
                        Button(action: { canvasViewModel.autoLayout() }) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.title2)
                                .foregroundStyle(.orange)
                                .padding(12)
                                .glassEffect(in: .circle)
                        }
                        Button(action: { canvasViewModel.fitToScreen(in: geometry.size, insets: geometry.safeAreaInsets) }) {
                            Image(systemName: "scope")
                                .font(.title2)
                                .foregroundStyle(.orange)
                                .padding(12)
                                .glassEffect(in: .circle)
                        }
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
            }
        }
        .navigationSplitViewStyle(.automatic)
    }
    
    private func checkIfWiringIsInvalid() -> Bool {
        guard let sourceId = canvasViewModel.activeWiringSource,
              let targetPos = canvasViewModel.wiringTargetPosition,
              let targetNode = canvasViewModel.findNode(at: targetPos) else { return false }
        return canvasViewModel.wouldCreateCycle(from: sourceId, to: targetNode.id)
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
        PlaygroundView().environmentObject(CanvasViewModel()).previewInterfaceOrientation(.landscapeLeft)
    }
}
