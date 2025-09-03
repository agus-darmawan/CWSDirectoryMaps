//
//  IntegratedMapView.swift
//  CWSDirectoryMaps
//
//  Created by Daniel Fernando Herawan on 01/09/25.
//

// swift
import SwiftUI

struct IntegratedMapView: View {
    @StateObject private var dataManager = DataManager()
    @StateObject private var mapViewManager = MapViewManager()
    @StateObject private var pathfindingManager = PathfindingManager()
    
    // Selected floor for menu and image switching
    @State private var selectedFloor: Floor = .ground
    
    // Multiplier to fine-tune graph-to-image fitting
    @State private var graphScaleMultiplier: CGFloat = 0.96
    
    var body: some View {
        ZStack {
            if dataManager.isLoading {
                ProgressView("Loading map...")
            } else if let graph = mapViewManager.currentGraph {
                GeometryReader { geo in
                    ZoomableScrollView {
                        ZStack {
                            Image(selectedFloor.imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: geo.size.width, height: geo.size.height)
                                .overlay(
                                    GeometryReader { imageGeo in
                                        IntegratedMapOverlayView(
                                            graph: graph,
                                            pathWithLabels: pathfindingManager.pathWithLabels,
                                            unifiedGraph: dataManager.unifiedGraph,
                                            imageGeo: imageGeo,
                                            mapViewManager: mapViewManager,
                                            graphScaleMultiplier: graphScaleMultiplier
                                        )
                                    }
                                )
                        }
                        .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
            } else {
                Text("No graph loaded")
            }
        }
        .task {
            await dataManager.preloadAllFloorData()
            if dataManager.floorData[selectedFloor] != nil {
                mapViewManager.switchToFloor(selectedFloor, floorData: dataManager.floorData)
            }
        }
        .onChange(of: selectedFloor) { newFloor in
            mapViewManager.switchToFloor(newFloor, floorData: dataManager.floorData)
        }
        // Floor menu (top-right)
        // swift
        .overlay(alignment: .topTrailing) {
            Menu {
                ForEach(Floor.allCases, id: \.self) { floor in
                    Button {
                        selectedFloor = floor
                    } label: {
                        HStack {
                            Text(floor.displayName)
                            if floor == selectedFloor {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(selectedFloor.displayName)
                        .font(.headline)
                    Image(systemName: "chevron.down")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.2), radius: 3)
                .foregroundColor(.primary)
            }
            .padding()
        }
        // Debug controls for fitting multiplier
        .overlay(
            VStack {
                Spacer()
                HStack(spacing: 12) {
                    Button("-") { graphScaleMultiplier -= 0.01 }
                    Text("Graph Scale: \(String(format: "%.2f", graphScaleMultiplier))")
                        .foregroundColor(.white)
                    Button("+") { graphScaleMultiplier += 0.01 }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.black.opacity(0.6))
                .cornerRadius(12)
                .padding()
            }
        )
    }
}

struct IntegratedMapOverlayView: View {
    let graph: Graph
    let pathWithLabels: [(point: CGPoint, label: String)]
    let unifiedGraph: [String: GraphNode]
    let imageGeo: GeometryProxy
    let mapViewManager: MapViewManager
    let graphScaleMultiplier: CGFloat
    
    var body: some View {
        let bounds = mapViewManager.graphBounds(graph)
        let overlayScale = mapViewManager.fittingScale(bounds: bounds, in: imageGeo.size) * graphScaleMultiplier
        let overlayOffset = mapViewManager.fittingOffset(bounds: bounds, in: imageGeo.size, scale: overlayScale)
        
        ZStack {
            // Edges
            ForEach(graph.edges) { edge in
                if let from = graph.nodes.first(where: { $0.id == edge.source }),
                   let to = graph.nodes.first(where: { $0.id == edge.target }) {
                    Path { path in
                        path.move(to: CGPoint(x: from.x, y: from.y))
                        path.addLine(to: CGPoint(x: to.x, y: to.y))
                    }
                    .stroke(Color.white.opacity(0.6), lineWidth: 2)
                }
            }
            
            // Pathfinding path (draws only within the same floor segments)
            if pathWithLabels.count > 1 {
                Path { path in
                    path.move(to: pathWithLabels[0].point)
                    for i in 1..<pathWithLabels.count {
                        let prevLabel = pathWithLabels[i - 1].label
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
                .stroke(Color.yellow, lineWidth: 4)
            }
            
            // Nodes
            ForEach(graph.nodes) { node in
                Circle()
                    .fill(Color.red)
                    .frame(width: 5, height: 5)
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
