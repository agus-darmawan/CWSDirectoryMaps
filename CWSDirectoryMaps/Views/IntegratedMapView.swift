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
    @StateObject private var viewModel = DirectoryViewModel()
    @State private var selectedStore: Store? = nil

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
                                            graphScaleMultiplier: graphScaleMultiplier,
                                            dataManager: dataManager,
                                            viewModel: viewModel,
                                            selectedStore: $selectedStore
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
    let dataManager: DataManager
    let viewModel: DirectoryViewModel
    @Binding var selectedStore: Store?
    @State private var showTenantDetail = false
    
    var body: some View {
        let bounds = mapViewManager.graphBounds(graph)
        let overlayScale = mapViewManager.fittingScale(bounds: bounds, in: imageGeo.size) * graphScaleMultiplier
        let overlayOffset = mapViewManager.fittingOffset(bounds: bounds, in: imageGeo.size, scale: overlayScale)
        
        ZStack {
            // MARK: - Show only ellipse/circle centers
            ForEach(graph.nodes.filter {
                let type = $0.type.lowercased() ?? ""
                let label = $0.label?.lowercased() ?? ""
                return type.contains("center") &&
                !label.contains("escalator") &&
                !label.contains("lift")
            }, id: \.id) { node in
                Button {
                    handleNodeTap(node: node)
                } label: {
                    Circle()
                        .fill(Color.blue.opacity(0.7))
                        .stroke(Color.white, lineWidth: 1)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .fill(Color.white)
                                .frame(width: 4, height: 4)
                        )
                }
                .position(CGPoint(x: node.x, y: node.y))
            }
            
            // MARK: - Draw navigation path
            if pathWithLabels.count > 1 {
                Path { path in
                    let points = pathWithLabels.map { $0.point }
                    let smoothedPath = createSmoothPath(
                        points: points,
                        pathWithLabels: pathWithLabels,
                        unifiedGraph: unifiedGraph
                    )
                    path.addPath(smoothedPath)
                }
                .stroke(Color.yellow,
                        style: StrokeStyle(lineWidth: 4,
                                           lineCap: .round,
                                           lineJoin: .round))
                
                // Start point
                if let startPoint = pathWithLabels.first {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 16, height: 16)
                        .position(startPoint.point)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: 16, height: 16)
                                .position(startPoint.point)
                        )
                }
                
                // End point
                if let endPoint = pathWithLabels.last {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 16, height: 16)
                        .position(endPoint.point)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: 16, height: 16)
                                .position(endPoint.point)
                        )
                }
            }
        }
        .scaleEffect(overlayScale, anchor: .topLeading)
        .offset(overlayOffset)
        .sheet(item: $selectedStore) { store in
            TenantDetailModalView(
                store: store,
                viewModel: viewModel,
                isPresented: Binding(
                    get: { selectedStore != nil },
                    set: { if !$0 { selectedStore = nil } }
                )
            )
        }
    }
    
    private func findStoreByNode(_ node: Node) -> Store? {
        // Ambil tenant name dari parentLabel atau label
        guard let rawTenant = node.parentLabel ?? node.label else { return nil }
        let tenantName = rawTenant.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !tenantName.isEmpty else { return nil }

        // Normalize function (sama kayak di DirectoryViewModel)
        func normalize(_ name: String) -> String {
            var normalized = name.lowercased()
            if let range = normalized.range(of: "-\\d+$", options: .regularExpression) {
                normalized.removeSubrange(range)
            }
            normalized = normalized.replacingOccurrences(of: " ", with: "")
            normalized = normalized.replacingOccurrences(of: "-", with: "")
            normalized = normalized.replacingOccurrences(of: "_", with: "")
            normalized = normalized.replacingOccurrences(of: "&", with: "")
            return normalized
        }

        let normalizedTenant = normalize(tenantName)

        // ✅ PAKAI viewModel yang sudah diinject, bukan DirectoryViewModel() baru
        if let match = viewModel.allStores.first(where: { normalize($0.name) == normalizedTenant }) {
            return match
        }

        // fallback contain match
        if let partial = viewModel.allStores.first(where: { normalize($0.name).contains(normalizedTenant) }) {
            return partial
        }

        return nil
    }

    private func handleNodeTap(node: Node) {
        if let store = findStoreByNode(node) {
            selectedStore = store
            print("✅ Store found: \(store.name)")
        } else {
            print("⚠️ Store not found for node: \(node.parentLabel ?? node.label ?? "No label")")
        }
    }
}

// MARK: - Path Smoothing Helper Function
func createSmoothPath(points: [CGPoint], pathWithLabels: [(point: CGPoint, label: String)], unifiedGraph: [String: GraphNode]) -> Path {
    guard points.count > 1 else { return Path() }
    
    var path = Path()
    
    // Group consecutive points by floor to handle multi-floor paths properly
    var floorSegments: [(floor: Floor, points: [CGPoint])] = []
    var currentFloorPoints: [CGPoint] = []
    var currentFloor: Floor? = nil
    
    for (_, pathItem) in pathWithLabels.enumerated() {
        let floor = extractFloorFromLabel(pathItem.label)
        
        if currentFloor != floor {
            if !currentFloorPoints.isEmpty {
                floorSegments.append((floor: currentFloor!, points: currentFloorPoints))
            }
            currentFloorPoints = [pathItem.point]
            currentFloor = floor
        } else {
            currentFloorPoints.append(pathItem.point)
        }
    }
    
    if !currentFloorPoints.isEmpty, let floor = currentFloor {
        floorSegments.append((floor: floor, points: currentFloorPoints))
    }
    
    // Draw smooth curves for each floor segment
    for segment in floorSegments {
        if segment.points.count < 2 { continue }
        
        let smoothedPoints = smoothPoints(segment.points)
        
        // Start the path segment
        path.move(to: smoothedPoints[0])
        
        if smoothedPoints.count == 2 {
            // Simple line for 2 points
            path.addLine(to: smoothedPoints[1])
        } else {
            // Create smooth curves for multiple points
            for i in 1..<smoothedPoints.count {
                let currentPoint = smoothedPoints[i]
                let previousPoint = smoothedPoints[i - 1]
                
                if i == 1 {
                    // First curve - start with a line then curve
                    path.addLine(to: currentPoint)
                } else {
                    // Calculate control points for smooth curve
                    let nextPoint = i < smoothedPoints.count - 1 ? smoothedPoints[i + 1] : currentPoint
                    let controlPoint1 = calculateControlPoint(
                        previous: smoothedPoints[max(0, i - 2)],
                        current: previousPoint,
                        next: currentPoint
                    )
                    let controlPoint2 = calculateControlPoint(
                        previous: previousPoint,
                        current: currentPoint,
                        next: nextPoint
                    )
                    
                    path.addCurve(
                        to: currentPoint,
                        control1: controlPoint1,
                        control2: controlPoint2
                    )
                }
            }
        }
    }
    
    return path
}

private func extractFloorFromLabel(_ label: String) -> Floor {
    if label.hasPrefix("ground_") { return .ground }
    if label.hasPrefix("lowerground_") { return .lowerGround }
    if label.hasPrefix("1st_") { return .first }
    if label.hasPrefix("2nd_") { return .second }
    if label.hasPrefix("3rd_") { return .third }
    if label.hasPrefix("4th_") { return .fourth }
    return .ground
}

private func smoothPoints(_ points: [CGPoint]) -> [CGPoint] {
    guard points.count > 2 else { return points }
    
    var smoothed: [CGPoint] = []
    let smoothingFactor: CGFloat = 0.15
    
    smoothed.append(points[0]) // Keep first point unchanged
    
    for i in 1..<(points.count - 1) {
        let prev = points[i - 1]
        let current = points[i]
        let next = points[i + 1]
        
        // Apply gentle smoothing
        let smoothedX = current.x + smoothingFactor * (prev.x + next.x - 2 * current.x)
        let smoothedY = current.y + smoothingFactor * (prev.y + next.y - 2 * current.y)
        
        smoothed.append(CGPoint(x: smoothedX, y: smoothedY))
    }
    
    smoothed.append(points.last!) // Keep last point unchanged
    
    return smoothed
}

private func calculateControlPoint(previous: CGPoint, current: CGPoint, next: CGPoint) -> CGPoint {
    let smoothness: CGFloat = 0.3
    
    let deltaX = next.x - previous.x
    let deltaY = next.y - previous.y
    
    return CGPoint(
        x: current.x + smoothness * deltaX * 0.25,
        y: current.y + smoothness * deltaY * 0.25
    )
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
