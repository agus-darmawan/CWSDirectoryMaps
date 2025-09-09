
//  IntegratedMapView.swift
//  CWSDirectoryMaps
//
//  Created by Daniel Fernando Herawan on 01/09/25.
//

import SwiftUI

struct IntegratedMapView: View {
    
    @ObservedObject var dataManager: DataManager
    @Binding var pathWithLabels: [(point: CGPoint, label: String)]
    @StateObject private var mapViewManager = MapViewManager()
    @StateObject var pathfindingManager: PathfindingManager
    
    // Enhanced navigation tracking
    @State private var currentStepIndex: Int = 0
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
                                            currentStepIndex: $currentStepIndex,
                                            pathfindingManager: pathfindingManager
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
        .onChange(of: pathfindingManager.currentStepIndex) { _, newIndex in
            currentStepIndex = newIndex
        }
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
    
    private func selectInitialFloorIfAvailable() {
        if let _ = dataManager.floorData[selectedFloor] {
            mapViewManager.switchToFloor(selectedFloor, floorData: dataManager.floorData)
        } else if let _ = dataManager.floorData[.ground] {
            selectedFloor = .ground
            mapViewManager.switchToFloor(.ground, floorData: dataManager.floorData)
        }
    }
}

struct IntegratedMapOverlayView: View {
    let graph: Graph
    let pathWithLabels: [(point: CGPoint, label: String)]
    let unifiedGraph: [String: GraphNode]
    let imageGeo: GeometryProxy
    let mapViewManager: MapViewManager
    let graphScaleMultiplier: CGFloat
    @Binding var currentStepIndex: Int
    let pathfindingManager: PathfindingManager
    
    var body: some View {
        let bounds = mapViewManager.graphBounds(graph)
        let overlayScale = mapViewManager.fittingScale(bounds: bounds, in: imageGeo.size) * graphScaleMultiplier
        let overlayOffset = mapViewManager.fittingOffset(bounds: bounds, in: imageGeo.size, scale: overlayScale)
        
        let hasValidPath = pathWithLabels.count > 1
        let totalSteps = pathfindingManager.enhancedDirectionSteps.count
        let safeCurrentStepIndex = max(0, min(currentStepIndex, totalSteps > 0 ? totalSteps - 1 : 0))
        let progressRatio: Double = totalSteps > 1 ? Double(safeCurrentStepIndex) / Double(totalSteps - 1) : 0.0
        let currentPathIndex = Int(Double(pathWithLabels.count - 1) * progressRatio)
        let safeCurrentPathIndex = max(0, min(currentPathIndex, pathWithLabels.count - 1))
        
        ZStack {
            if hasValidPath {
                // Completed path
                CompletedPathView(pathWithLabels: pathWithLabels, endIndex: safeCurrentPathIndex)
                
                // Remaining path
                RemainingPathView(pathWithLabels: pathWithLabels, startIndex: safeCurrentPathIndex)
                
                // Start marker
                StartPointView(startPoint: pathWithLabels.first?.point)
                
                // Current location
                CurrentLocationView(
                    pathWithLabels: pathWithLabels,
                    currentPathIndex: safeCurrentPathIndex
                )
                
                // End marker
                EndPointView(endPoint: pathWithLabels.last?.point)
                
            }
        }
        .scaleEffect(overlayScale, anchor: .topLeading)
        .offset(overlayOffset)
    }
}

struct CompletedPathView: View {
    let pathWithLabels: [(point: CGPoint, label: String)]
    let endIndex: Int
    
    var body: some View {
        if endIndex > 0 && endIndex < pathWithLabels.count {
            let points = Array(pathWithLabels[0...endIndex]).map { $0.point }
            if points.count > 1 {
                Path { path in
                    path.move(to: points[0])
                    for i in 1..<points.count {
                        path.addLine(to: points[i])
                    }
                }
                .stroke(Color.green, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            } else {
                Color.clear.frame(width: 0, height: 0)
            }
        } else {
            Color.clear.frame(width: 0, height: 0)
        }
    }
}

struct RemainingPathView: View {
    let pathWithLabels: [(point: CGPoint, label: String)]
    let startIndex: Int
    
    var body: some View {
        if startIndex < pathWithLabels.count - 1 {
            let points = Array(pathWithLabels[startIndex...]).map { $0.point }
            if points.count > 1 {
                Path { path in
                    path.move(to: points[0])
                    for i in 1..<points.count {
                        path.addLine(to: points[i])
                    }
                }
                .stroke(Color.gray.opacity(0.6), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: [10, 5]))
            } else {
                Color.clear.frame(width: 0, height: 0)
            }
        } else {
            Color.clear.frame(width: 0, height: 0)
        }
    }
}

struct StartPointView: View {
    let startPoint: CGPoint?
    
    var body: some View {
        if let point = startPoint {
            Circle()
                .fill(Color.green)
                .frame(width: 20, height: 20)
                .position(point)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 20, height: 20)
                        .position(point)
                )
                .overlay(
                    Image(systemName: "figure.walk")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .position(point)
                )
        } else {
            Color.clear.frame(width: 0, height: 0)
        }
    }
}

struct CurrentLocationView: View {
    let pathWithLabels: [(point: CGPoint, label: String)]
    let currentPathIndex: Int
    
    // Calculate rotation angle with smooth direction handling for turns
    private var rotationAngle: Angle {
        guard currentPathIndex < pathWithLabels.count else {
            return .zero
        }
        
        // Jika di akhir path, gunakan arah dari titik sebelumnya
        if currentPathIndex >= pathWithLabels.count - 1 {
            guard currentPathIndex > 0 else { return .zero }
            let prevPoint = pathWithLabels[currentPathIndex - 1].point
            let currentPoint = pathWithLabels[currentPathIndex].point
            
            let dx = currentPoint.x - prevPoint.x
            let dy = currentPoint.y - prevPoint.y
            let angle = atan2(dy, dx) + .pi / 2
            return Angle(radians: Double(angle))
        }
        
        let currentPoint = pathWithLabels[currentPathIndex].point
        
        // Untuk smooth direction, gunakan beberapa titik ke depan jika tersedia
        var targetPoint: CGPoint
        
        // Coba ambil titik yang cukup jauh untuk menghindari noise dari titik yang terlalu dekat
        let lookAheadDistance = min(3, pathWithLabels.count - currentPathIndex - 1)
        if lookAheadDistance > 0 {
            targetPoint = pathWithLabels[currentPathIndex + lookAheadDistance].point
        } else {
            targetPoint = pathWithLabels[currentPathIndex + 1].point
        }
        
        // Jika titik terlalu dekat (kemungkinan noise), gunakan rata-rata arah
        let dx = targetPoint.x - currentPoint.x
        let dy = targetPoint.y - currentPoint.y
        let distance = sqrt(dx * dx + dy * dy)
        
        if distance < 10.0 && currentPathIndex + 1 < pathWithLabels.count - 1 {
            // Gunakan arah rata-rata dari beberapa segmen
            var avgDx: CGFloat = 0
            var avgDy: CGFloat = 0
            var segmentCount = 0
            
            let maxLookAhead = min(5, pathWithLabels.count - currentPathIndex - 1)
            for i in 1...maxLookAhead {
                let nextIdx = currentPathIndex + i
                if nextIdx < pathWithLabels.count {
                    let segDx = pathWithLabels[nextIdx].point.x - currentPoint.x
                    let segDy = pathWithLabels[nextIdx].point.y - currentPoint.y
                    avgDx += segDx
                    avgDy += segDy
                    segmentCount += 1
                }
            }
            
            if segmentCount > 0 {
                avgDx /= CGFloat(segmentCount)
                avgDy /= CGFloat(segmentCount)
                let angle = atan2(avgDy, avgDx) + .pi / 2
                return Angle(radians: Double(angle))
            }
        }
        
        // Gunakan arah normal
        let angle = atan2(dy, dx) + .pi / 2
        return Angle(radians: Double(angle))
    }
    
    var body: some View {
        if currentPathIndex < pathWithLabels.count {
            let point = pathWithLabels[currentPathIndex].point
            
            Circle()
                .fill(Color.blue)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 24, height: 24)
                )
                .overlay(
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .rotationEffect(rotationAngle)
                )
                .position(point)
        } else {
            Color.clear.frame(width: 0, height: 0)
        }
    }
}

struct EndPointView: View {
    let endPoint: CGPoint?
    
    var body: some View {
        if let point = endPoint {
            Circle()
                .fill(Color.red)
                .frame(width: 20, height: 20)
                .position(point)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 20, height: 20)
                        .position(point)
                )
                .overlay(
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .position(point)
                )
        } else {
            Color.clear.frame(width: 0, height: 0)
        }
    }
}


// MARK: - ZoomableScrollView
struct ZoomableScrollView<Content: View>: View {
    let content: Content
    
    @State private var scale: CGFloat = 3
    @State private var lastScale: CGFloat = 3
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geo in
            content
                .scaleEffect(scale)
                .offset(offset)
                .onAppear {
                    offset = .zero
                    lastOffset = .zero
                }
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = lastScale * value
                                offset = clampedOffset(offset, geo: geo)
                            }
                            .onEnded { _ in
                                lastScale = max(min(scale, 5.0), 1.0)
                                scale = lastScale
                                offset = clampedOffset(offset, geo: geo)
                                lastOffset = offset
                            },
                        DragGesture()
                            .onChanged { value in
                                let newOffset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                                offset = clampedOffset(newOffset, geo: geo)
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                )
                .gesture(
                    TapGesture(count: 2)
                        .onEnded {
                            withAnimation(.easeInOut) {
                                if scale > 3 {
                                    scale = 3
                                    lastScale = 3
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 5
                                    lastScale = 5
                                }
                            }
                        }
                )
        }
    }
    
    private func clampedOffset(_ proposed: CGSize, geo: GeometryProxy) -> CGSize {
        let screenWidth = geo.size.width
        let screenHeight = geo.size.height
        
        let contentAspect: CGFloat = 1800 / 1200
        var contentWidth = screenWidth
        var contentHeight = screenHeight
        
        if contentAspect > screenWidth / screenHeight {
            contentHeight = screenWidth / contentAspect
        } else {
            contentWidth = screenHeight * contentAspect
        }
        
        let scaledWidth = contentWidth * scale
        let scaledHeight = contentHeight * scale
        
        let maxX = max((scaledWidth - screenWidth) / 2, 0)
        let maxY: CGFloat
        let minY: CGFloat
        
        if scaledHeight > screenHeight {
            maxY = (scaledHeight - screenHeight) / 2
            minY = -maxY
        } else {
            maxY = 0
            minY = 0
        }
        
        return CGSize(
            width: min(max(proposed.width, -maxX), maxX),
            height: min(max(proposed.height, minY), maxY)
        )
    }
}

// MARK: - Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
