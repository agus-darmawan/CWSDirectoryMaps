//
//  IntegratedMapView.swift
//  CWSDirectoryMaps
//

import SwiftUI

struct IntegratedMapView: View {
    @StateObject private var dataManager = DataManager()
    @StateObject private var mapViewManager = MapViewManager()
    @StateObject private var pathfindingManager = PathfindingManager()
    
    // 🔑 multiplier khusus buat graph
    @State private var graphScaleMultiplier: CGFloat = 0.96
    
    var body: some View {
        ZStack {
            if dataManager.isLoading {
                ProgressView("Loading map...")
            } else if let graph = mapViewManager.currentGraph {
                GeometryReader { geo in
                    Image("floor-ground")
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .overlay(
                            GeometryReader { imageGeo in
                                IntegratedMapOverlayView(
                                    graph: graph,
                                    pathWithLabels: pathfindingManager.pathWithLabels,
                                    unifiedGraph: dataManager.unifiedGraph,
                                    scale: mapViewManager.scale,
                                    imageGeo: imageGeo,
                                    mapViewManager: mapViewManager,
                                    graphScaleMultiplier: graphScaleMultiplier
                                )
                            }
                        )
                        .scaleEffect(mapViewManager.scale)
                        .offset(mapViewManager.offset)
                        .gesture(createCombinedGesture())
                }
            } else {
                Text("No graph loaded")
            }
        }
        .task {
            await dataManager.preloadAllFloorData()
            if let _ = dataManager.floorData[.ground] {
                mapViewManager.switchToFloor(.ground, floorData: dataManager.floorData)
            }
        }
        // 🔑 control tambahan biar bisa atur scale graph pas preview
        .overlay(
            VStack {
                Spacer()
                HStack {
                    Button("-") { graphScaleMultiplier -= 0.01 }
                    Text("Graph Scale: \(String(format: "%.2f", graphScaleMultiplier))")
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                    Button("+") { graphScaleMultiplier += 0.01 }
                }
                .padding()
                .background(.black.opacity(0.6))
                .cornerRadius(12)
                .padding()
            }
        )
    }
    
    // MARK: - Gestures
    private func createDragGesture() -> some Gesture {
        DragGesture()
            .onChanged { value in
                mapViewManager.offset = CGSize(
                    width: mapViewManager.lastOffset.width + value.translation.width,
                    height: mapViewManager.lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                mapViewManager.updateOffset(mapViewManager.offset)
            }
    }
    
    private func createMagnificationGesture() -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / mapViewManager.lastScale
                mapViewManager.scale *= delta
                mapViewManager.lastScale = value
            }
            .onEnded { _ in
                mapViewManager.updateLastScale()
            }
    }
    
    private func createCombinedGesture() -> some Gesture {
        SimultaneousGesture(
            createDragGesture(),
            createMagnificationGesture()
        )
    }
}

// MARK: - Overlay
struct IntegratedMapOverlayView: View {
    let graph: Graph
    let pathWithLabels: [(point: CGPoint, label: String)]
    let unifiedGraph: [String: GraphNode]
    let scale: CGFloat
    let imageGeo: GeometryProxy
    let mapViewManager: MapViewManager
    let graphScaleMultiplier: CGFloat
    
    var body: some View {
        let bounds = mapViewManager.graphBounds(graph)
        let overlayScale = mapViewManager.fittingScale(bounds: bounds, in: imageGeo.size) * graphScaleMultiplier
        let overlayOffset = mapViewManager.fittingOffset(bounds: bounds, in: imageGeo.size, scale: overlayScale)
        
        ZStack {
            // edges
            ForEach(graph.edges) { edge in
                if let from = graph.nodes.first(where: { $0.id == edge.source }),
                   let to = graph.nodes.first(where: { $0.id == edge.target }) {
                    Path { path in
                        path.move(to: CGPoint(x: from.x, y: from.y))
                        path.addLine(to: CGPoint(x: to.x, y: to.y))
                    }
                    .stroke(Color.white.opacity(0.6), lineWidth: 2 / scale)
                }
            }
            
            // pathfinding path
            if pathWithLabels.count > 1 {
                Path { path in
                    path.move(to: pathWithLabels[0].point)
                    for i in 1..<pathWithLabels.count {
                        let prevLabel = pathWithLabels[i-1].label
                        let currentLabel = pathWithLabels[i].label
                        guard let prevNode = unifiedGraph[prevLabel],
                              let currentNode = unifiedGraph[currentLabel] else {
                            path.move(to: pathWithLabels[i].point)
                            continue
                        }
                        if prevNode.floor == currentNode.floor {
                            path.addLine(to: pathWithLabels[i].point)
                        } else {
                            path.move(to: pathWithLabels[i].point)
                        }
                    }
                }
                .stroke(Color.yellow, lineWidth: 4 / scale)
            }
            
            // nodes
            ForEach(graph.nodes) { node in
                Circle()
                    .fill(Color.red)
                    .frame(width: 5 / scale, height: 5 / scale)
                    .position(x: node.x, y: node.y)
            }
        }
        .scaleEffect(overlayScale, anchor: .topLeading)
        .offset(overlayOffset)
    }
}

// MARK: - Preview
#Preview {
    IntegratedMapView()
}
