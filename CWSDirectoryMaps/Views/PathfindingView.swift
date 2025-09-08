////
////  PathfindingView.swift
////  CWSDirectoryMaps
////
////  Created by Steven Gonawan on 27/08/25.
////  Refactored on 02/09/25.
////
//
//import SwiftUI
//
//// MARK: - PathfindingView
//struct PathfindingView: View {
//    // Manager objects
//    @StateObject private var dataManager = DataManager()
//    @StateObject private var pathfindingManager = PathfindingManager()
//    @StateObject private var mapViewManager = MapViewManager()
//    @StateObject private var uiStateManager = UIStateManager()
//    
//    var body: some View {
//        VStack(spacing: 0) {
//            if dataManager.isLoading {
//                LoadingView()
//            } else {
//                MainContentView(
//                    dataManager: dataManager,
//                    pathfindingManager: pathfindingManager,
//                    mapViewManager: mapViewManager,
//                    uiStateManager: uiStateManager
//                )
//            }
//        }
//        .background(Color.black.ignoresSafeArea())
//        .task {
//            await dataManager.preloadAllFloorData()
//        }
//    }
//}
//
//// MARK: - Loading View
//struct LoadingView: View {
//    var body: some View {
//        VStack {
//            ProgressView("Loading maps...")
//                .progressViewStyle(CircularProgressViewStyle(tint: .white))
//                .foregroundColor(.white)
//            Text("Preparing floor data...")
//                .foregroundColor(.white)
//                .font(.caption)
//                .padding(.top)
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//        .background(Color.black.ignoresSafeArea())
//    }
//}
//
//// MARK: - Main Content View
//struct MainContentView: View {
//    @ObservedObject var dataManager: DataManager
//    @ObservedObject var pathfindingManager: PathfindingManager
//    @ObservedObject var mapViewManager: MapViewManager
//    @ObservedObject var uiStateManager: UIStateManager
//    
//    var body: some View {
//        VStack(spacing: 0) {
//            FloorSelectorView(
//                selectedFloor: $mapViewManager.selectedFloor,
//                onFloorChange: { floor in
//                    mapViewManager.switchToFloor(floor, floorData: dataManager.floorData)
//                }
//            )
//            
//            SearchBarsView(
//                uiStateManager: uiStateManager,
//                allLocations: dataManager.allLocations,
//                onPathfindingTrigger: {
//                    pathfindingManager.runPathfinding(
//                        startLabel: uiStateManager.startLabel,
//                        endLabel: uiStateManager.endLabel,
//                        startFloor: uiStateManager.startFloor,
//                        endFloor: uiStateManager.endFloor,
//                        unifiedGraph: dataManager.unifiedGraph
//                    )
//                }
//            )
//            
//            ZStack {
//                MapDisplayView(
//                    mapViewManager: mapViewManager,
//                    pathWithLabels: pathfindingManager.pathWithLabels,
//                    unifiedGraph: dataManager.unifiedGraph
//                )
//                
//                DirectionsView(directionSteps: pathfindingManager.directionSteps)
//            }
//        }
//        .onAppear {
//            mapViewManager.switchToFloor(.ground, floorData: dataManager.floorData)
//        }
//    }
//}
//
//// MARK: - Floor Selector View
//struct FloorSelectorView: View {
//    @Binding var selectedFloor: Floor
//    let onFloorChange: (Floor) -> Void
//    
//    var body: some View {
//        VStack {
//            Picker("Floor", selection: $selectedFloor) {
//                ForEach(Floor.allCases) { floor in
//                    Text(floor.rawValue).tag(floor)
//                }
//            }
//            .pickerStyle(SegmentedPickerStyle())
//            .onChange(of: selectedFloor) { newFloor in
//                print("Picker selection changed to: \(newFloor.rawValue)")
//                onFloorChange(newFloor)
//            }
//            
//            // Manual buttons as backup
//            HStack {
//                Button("Ground Floor") {
//                    print("Manual Ground button pressed")
//                    selectedFloor = .ground
//                    onFloorChange(.ground)
//                }
//                .foregroundColor(selectedFloor == .ground ? .yellow : .white)
//                
//                Button("Lower Ground") {
//                    print("Manual Lower Ground button pressed")
//                    selectedFloor = .lowerGround
//                    onFloorChange(.lowerGround)
//                }
//                .foregroundColor(selectedFloor == .lowerGround ? .yellow : .white)
//            }
//            .font(.caption)
//        }
//    }
//}
//
//// MARK: - Search Bars View
//struct SearchBarsView: View {
//    @ObservedObject var uiStateManager: UIStateManager
//    let allLocations: [Location]
//    let onPathfindingTrigger: () -> Void
//    
//    var body: some View {
////        VStack {
////            SearchBarView(
////                text: $uiStateManager.startLabel,
////                placeholder: "Start",
////                locations: allLocations,
////                onLocationSelected: { selectedLocation in
////                    uiStateManager.updateStartLocation(selectedLocation)
////                    onPathfindingTrigger()
////                },
////                field: .start,
////            )
////            
////            SearchBarView(
////                text: $uiStateManager.endLabel,
////                placeholder: "Destination",
////                locations: allLocations,
////                onLocationSelected: { selectedLocation in
////                    uiStateManager.updateEndLocation(selectedLocation)
////                    onPathfindingTrigger()
////                },
////                field: .destination,
////            )
////        }
////        .padding(.top)
////        .background(Color.black.opacity(0.8))
////        .padding()
//    }
//}
//
//// MARK: - Map Display View
//struct MapDisplayView: View {
//    @ObservedObject var mapViewManager: MapViewManager
//    let pathWithLabels: [(point: CGPoint, label: String)]
//    let unifiedGraph: [String: GraphNode]
//    
//    var body: some View {
//        ZStack {
//            Image("map_background")
//                .resizable()
//                .scaledToFit()
//                .overlay(
//                    GeometryReader { imageGeo in
//                        if let graph = mapViewManager.currentGraph {
//                            MapOverlayView(
//                                graph: graph,
//                                pathWithLabels: pathWithLabels,
//                                unifiedGraph: unifiedGraph,
//                                scale: mapViewManager.scale,
//                                imageGeo: imageGeo
//                            )
//                        }
//                    }
//                )
//        }
//        .scaleEffect(mapViewManager.scale)
//        .offset(mapViewManager.offset)
//        .gesture(createDragGesture())
//        .gesture(createMagnificationGesture())
//        
//        if mapViewManager.currentGraph == nil {
//            Text("No graph data available")
//                .padding()
//                .foregroundColor(.white)
//        }
//    }
//    
//    private func createDragGesture() -> some Gesture {
//        DragGesture()
//            .onChanged { value in
//                mapViewManager.offset = CGSize(
//                    width: mapViewManager.lastOffset.width + value.translation.width,
//                    height: mapViewManager.lastOffset.height + value.translation.height
//                )
//            }
//            .onEnded { _ in
//                mapViewManager.updateOffset(mapViewManager.offset)
//            }
//    }
//    
//    private func createMagnificationGesture() -> some Gesture {
//        MagnificationGesture()
//            .onChanged { value in
//                let delta = value / mapViewManager.lastScale
//                mapViewManager.scale *= delta
//                mapViewManager.lastScale = value
//            }
//            .onEnded { _ in
//                mapViewManager.updateLastScale()
//            }
//    }
//}
//
//// MARK: - Map Overlay View
//struct MapOverlayView: View {
//    let graph: Graph
//    let pathWithLabels: [(point: CGPoint, label: String)]
//    let unifiedGraph: [String: GraphNode]
//    let scale: CGFloat
//    let imageGeo: GeometryProxy
//    
//    var body: some View {
//        let bounds = graphBounds(graph)
//        let overlayScale = fittingScale(bounds: bounds, in: imageGeo.size)
//        let overlayOffset = fittingOffset(bounds: bounds, in: imageGeo.size, scale: overlayScale)
//        
//        ZStack {
//            // Draw edges
//            ForEach(graph.edges) { edge in
//                if let from = graph.nodes.first(where: { $0.id == edge.source }),
//                   let to = graph.nodes.first(where: { $0.id == edge.target }) {
//                    Path { path in
//                        path.move(to: CGPoint(x: from.x, y: from.y))
//                        path.addLine(to: CGPoint(x: to.x, y: to.y))
//                    }
//                    .stroke(Color.white.opacity(0.6), lineWidth: 2 / scale)
//                }
//            }
//            
//            // Draw path
//            if pathWithLabels.count > 1 {
//                PathView(pathWithLabels: pathWithLabels, unifiedGraph: unifiedGraph, scale: scale)
//            }
//            
//            // Draw nodes
//            ForEach(graph.nodes) { node in
//                Circle()
//                    .fill(Color.white)
//                    .frame(width: 4 / scale, height: 4 / scale)
//                    .position(x: node.x, y: node.y)
//            }
//        }
//        .scaleEffect(overlayScale, anchor: .topLeading)
//        .offset(overlayOffset)
//    }
//    
//    private func graphBounds(_ graph: Graph) -> CGRect {
//        let xs = graph.nodes.map { $0.x }
//        let ys = graph.nodes.map { $0.y }
//        guard let minX = xs.min(), let maxX = xs.max(),
//              let minY = ys.min(), let maxY = ys.max() else {
//            return .zero
//        }
//        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
//    }
//    
//    private func fittingScale(bounds: CGRect, in size: CGSize) -> CGFloat {
//        guard bounds.width > 0, bounds.height > 0 else { return 1 }
//        let scaleX = size.width / bounds.width
//        let scaleY = size.height / bounds.height
//        return min(scaleX, scaleY)
//    }
//    
//    private func fittingOffset(bounds: CGRect, in size: CGSize, scale: CGFloat) -> CGSize {
//        let graphWidth = bounds.width * scale
//        let graphHeight = bounds.height * scale
//        let x = (size.width - graphWidth) / 2 - bounds.minX * scale
//        let y = (size.height - graphHeight) / 2 - bounds.minY * scale
//        return CGSize(width: x, height: y)
//    }
//}
//
//// MARK: - Path View
//struct PathView: View {
//    let pathWithLabels: [(point: CGPoint, label: String)]
//    let unifiedGraph: [String: GraphNode]
//    let scale: CGFloat
//    
//    var body: some View {
//        Path { path in
//            path.move(to: pathWithLabels[0].point)
//            
//            for i in 1..<pathWithLabels.count {
//                let prevLabel = pathWithLabels[i-1].label
//                let currentLabel = pathWithLabels[i].label
//                
//                guard let prevNode = unifiedGraph[prevLabel],
//                      let currentNode = unifiedGraph[currentLabel] else {
//                    path.move(to: pathWithLabels[i].point)
//                    continue
//                }
//                
//                // Only draw line if nodes are on same floor
//                if prevNode.floor == currentNode.floor {
//                    path.addLine(to: pathWithLabels[i].point)
//                } else {
//                    path.move(to: pathWithLabels[i].point)
//                }
//            }
//        }
//        .stroke(Color.yellow, lineWidth: 4 / scale)
//    }
//}
//
//// MARK: - Directions View
//struct DirectionsView: View {
//    let directionSteps: [DirectionStep]
//    
//    var body: some View {
//        VStack {
//            Spacer()
//            if !directionSteps.isEmpty {
//                ScrollView(.horizontal, showsIndicators: false) {
//                    HStack {
//                        ForEach(directionSteps) { step in
//                            DirectionStepView(step: step)
//                        }
//                    }
//                    .padding()
//                }
//                .frame(height: 100)
//                .background(Color.black.opacity(0.7))
//            }
//        }
//    }
//}
//
//// MARK: - Preview
//#Preview {
//    PathfindingView()
//}
