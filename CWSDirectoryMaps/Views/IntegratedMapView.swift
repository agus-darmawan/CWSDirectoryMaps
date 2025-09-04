//
//  IntegratedMapView.swift
//  CWSDirectoryMaps
//
//  Created by Daniel Fernando Herawan on 01/09/25.
//

// swift
import SwiftUI

struct IntegratedMapView: View {
    
    @ObservedObject var dataManager: DataManager
    @Binding var pathWithLabels: [(point: CGPoint, label: String)]
    @StateObject private var mapViewManager = MapViewManager()
    @StateObject var pathfindingManager: PathfindingManager
    
    @State private var showPath: Bool = false
    
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
                                            pathWithLabels: pathWithLabels,
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
            await MainActor.run {
                selectInitialFloorIfAvailable()
            }
        }
        .onChange(of: selectedFloor) { oldValue, newValue in
            mapViewManager.switchToFloor(newValue, floorData: dataManager.floorData)
        }
        .onChange(of: dataManager.isLoading) { oldValue, newValue in
            if newValue == false {
                selectInitialFloorIfAvailable()
            }
        }
        // Floor menu (top-right)
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
                .shadow(color: Color.black, radius: 3)
                .foregroundColor(.primary)
            }
            .padding()
        }
        // Debug controls for fitting multiplier
//        .overlay(
//            VStack {
//                Spacer()
//                HStack(spacing: 12) {
//                    Button("-") { graphScaleMultiplier -= 0.01 }
//                    Text("Graph Scale: \(String(format: "%.2f", graphScaleMultiplier))")
//                        .foregroundColor(.white)
//                    Button("+") { graphScaleMultiplier += 0.01 }
//                }
//                .padding(.horizontal, 12)
//                .padding(.vertical, 8)
//                .background(.black.opacity(0.6))
//                .cornerRadius(12)
//                .padding()
//            }
//        )
    }
    
    // ✅ Helper to always pick ground if available
    private func selectInitialFloorIfAvailable() {
        print("---- [Debug] selectInitialFloorIfAvailable ----")
        print("Currently loading? \(dataManager.isLoading)")
        
        // FloorData details
        if dataManager.floorData.isEmpty {
            print("⚠️ floorData is EMPTY")
        } else {
            for (floor, data) in dataManager.floorData {
                print("✅ Floor '\(floor.displayName)': \(data.graph.nodes.count) nodes, \(data.graph.edges.count) edges, \(data.locations.count) locations")
            }
        }
        
        // Unified graph details
        print("UnifiedGraph has \(dataManager.unifiedGraph.count) nodes")
        if !dataManager.unifiedGraph.isEmpty {
            let sample = dataManager.unifiedGraph.prefix(5)
            print("Sample unifiedGraph nodes:")
            for (label, node) in sample {
                print(" - \(label) @ floor \(node.floor) pos(\(node.x),\(node.y))")
            }
        }
        
        // Floor switching logic
        if let _ = dataManager.floorData[selectedFloor] {
            print("➡️ Switching to \(selectedFloor.displayName)")
            mapViewManager.switchToFloor(selectedFloor, floorData: dataManager.floorData)
        } else if let _ = dataManager.floorData[.ground] {
            print("➡️ Fallback to .ground")
            selectedFloor = .ground
            mapViewManager.switchToFloor(.ground, floorData: dataManager.floorData)
        } else {
            print("⚠️ No floor data found, cannot switch")
        }
        print("---- [End Debug] ----")
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
                ForEach(pathWithLabels.indices, id: \.self) { i in
                    let point = pathWithLabels[i].point
                    let label = pathWithLabels[i].label
                    let _ = print("Path point: \(point) with label \(label)")
                }
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
            } else {
                let _ = print("Path has less than 2 points, skipping path drawing. pathcount=\(pathWithLabels.count)")
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
private func makePreviewDataManager() -> DataManager {
    let previewManager = DataManager()

    if let url = Bundle.main.url(forResource: Floor.ground.fileName, withExtension: "json"),
       let data = try? Data(contentsOf: url),
       let graph = try? JSONDecoder().decode(Graph.self, from: data) {

        let processedGraph = previewManager.processGraph(graph)
        let locations = previewManager.extractLocations(from: processedGraph)

        previewManager.floorData[.ground] = FloorData(graph: processedGraph, locations: locations)
        previewManager.unifiedGraph = previewManager.buildUnifiedGraph(from: previewManager.floorData)
        previewManager.isLoading = false
    }

    return previewManager
}

//#Preview {
//    IntegratedMapView(dataManager: makePreviewDataManager())
//}



