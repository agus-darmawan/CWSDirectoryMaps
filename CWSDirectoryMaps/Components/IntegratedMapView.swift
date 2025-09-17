//
//  Enhanced IntegratedMapView.swift
//  CWSDirectoryMaps
//
//  Enhanced with floor transition support and current floor tracking
//

import SwiftUI

struct IntegratedMapView: View {
    
    @ObservedObject var dataManager: DataManager
    @Binding var pathWithLabels: [(point: CGPoint, label: String)]
    @StateObject private var mapViewManager = MapViewManager()
    @StateObject var pathfindingManager: PathfindingManager
    @Binding var currentFloor: Floor
    
    // Enhanced navigation tracking
    @State private var currentStepIndex: Int = 0
    @State private var showPath: Bool = false
    
    //punya daniel
    @ObservedObject var viewModel: DirectoryViewModel
    @State private var selectedStore: Store? = nil
    
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
                            Image(currentFloor.imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: geo.size.width, height: geo.size.height)
                                .overlay(
                                    GeometryReader { imageGeo in
                                        IntegratedMapOverlayView(
                                            graph: graph,
                                            pathWithLabels: getFilteredPathForCurrentFloor(),
                                            unifiedGraph: dataManager.unifiedGraph,
                                            imageGeo: imageGeo,
                                            mapViewManager: mapViewManager,
                                            graphScaleMultiplier: graphScaleMultiplier,
                                            currentStepIndex: $currentStepIndex,
                                            pathfindingManager: pathfindingManager,
                                            currentFloor: currentFloor,
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
            if !dataManager.isLoading {
                selectInitialFloorIfAvailable()
            }
        }
        .onChange(of: currentFloor) { oldValue, newValue in
            print("🏢 Floor changed from \(oldValue.displayName) to \(newValue.displayName)")
            mapViewManager.switchToFloor(newValue, floorData: dataManager.floorData)
        }
        .onChange(of: dataManager.isLoading) { oldValue, newValue in
            if newValue == false {
                selectInitialFloorIfAvailable()
            }
        }
        // FIXED: Sync currentStepIndex properly
        .onChange(of: pathfindingManager.currentStepIndex) { _, newIndex in
            currentStepIndex = newIndex
        }
        .overlay(alignment: .topTrailing) {
            FloorSelectorMenu(
                currentFloor: $currentFloor,
                availableFloors: getAvailableFloorsForPath()
            )
            .padding(.top, 50)
        }
    }
    
    // MARK: - Private Methods
    
    private func selectInitialFloorIfAvailable() {
        if let _ = dataManager.floorData[currentFloor] {
            mapViewManager.switchToFloor(currentFloor, floorData: dataManager.floorData)
        } else if let _ = dataManager.floorData[.ground] {
            currentFloor = .ground
            mapViewManager.switchToFloor(.ground, floorData: dataManager.floorData)
        }
    }
    
    private func getFilteredPathForCurrentFloor() -> [(point: CGPoint, label: String)] {
        return pathWithLabels.filter { pathItem in
            let pathFloor = extractFloorFromLabel(pathItem.label)
            return pathFloor == currentFloor
        }
    }
    
    private func getAvailableFloorsForPath() -> [Floor] {
        if pathWithLabels.isEmpty {
            return Floor.allCases
        }
        
        var floorsInPath = Set<Floor>()
        for pathItem in pathWithLabels {
            let floor = extractFloorFromLabel(pathItem.label)
            floorsInPath.insert(floor)
        }
        
        return Array(floorsInPath).sorted { floor1, floor2 in
            Floor.allCases.firstIndex(of: floor1) ?? 0 < Floor.allCases.firstIndex(of: floor2) ?? 0
        }
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
}

// MARK: - Floor Selector Menu
struct FloorSelectorMenu: View {
    @Binding var currentFloor: Floor
    let availableFloors: [Floor]
    
    var body: some View {
        Menu {
            ForEach(availableFloors, id: \.self) { floor in
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentFloor = floor
                    }
                } label: {
                    HStack {
                        Text(floor.displayName)
                        if floor == currentFloor {
                            Image(systemName: "checkmark")
                        }
                        // Show indicator if floor has path
                        if availableFloors.contains(floor) {
                            Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(currentFloor.displayName)
                    .font(.headline)
                Image(systemName: "chevron.down")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.3), radius: 3)
            .foregroundColor(.primary)
            .overlay(
                // Indicator for current floor with path
                RoundedRectangle(cornerRadius: 8)
                    .stroke(availableFloors.contains(currentFloor) ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .padding()
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
    let currentFloor: Floor
    let dataManager: DataManager
    let viewModel: DirectoryViewModel
    @Binding var selectedStore: Store?
    @State private var showTenantDetail = false
    
    var body: some View {
        let bounds = mapViewManager.graphBounds(graph)
        let overlayScale = mapViewManager.fittingScale(bounds: bounds, in: imageGeo.size) * graphScaleMultiplier
        let overlayOffset = mapViewManager.fittingOffset(bounds: bounds, in: imageGeo.size, scale: overlayScale)
        
        let hasValidPath = pathWithLabels.count > 1
        let totalSteps = pathfindingManager.enhancedDirectionSteps.count
        let safeCurrentStepIndex = max(0, min(currentStepIndex, totalSteps > 0 ? totalSteps - 1 : 0))
        
        // FIXED: Calculate progress based on current floor path with better step mapping
        let currentFloorSteps = getCurrentFloorSteps()
        let currentFloorPathIndex = getCurrentFloorPathIndex()
        
        let baseIconSize: CGFloat = 10
        let baseFontSize: CGFloat = 4
        
        let iconSize = baseIconSize / sqrt(overlayScale)
        let fontSize = baseFontSize / sqrt(overlayScale)
        
        ZStack {
            
            ForEach(graph.nodes.filter {
                let type = $0.type.lowercased()
                let label = $0.label?.lowercased() ?? ""
                return type.contains("center") &&
                !label.contains("escalator") &&
                !label.contains("elevator")
            }, id: \.id) { node in
                if let store = findStoreByNode(node) {
                    Button {
                        handleNodeTap(node: node)
                    } label: {
                        VStack(spacing: 2) {
                            if store.name.lowercased().contains("restroom")
                                || store.name.lowercased().contains("babystroller")
                                || store.name.lowercased().contains("wheelchair")
                                || store.name.lowercased().contains("atrium") {
                                
                                Circle()
                                    .fill(Color.blue.opacity(1.0))
                                    .frame(width: iconSize, height: iconSize)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 1)
                                    )
                                
                            } else {
                                Image(systemName: "handbag.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: iconSize, height: iconSize)
                                    .background(Circle().fill(Color.white))
                            }
                            StrokeText(
                                text: store.name,
                                fontSize: fontSize,
                                textColor: Color(UIColor.systemBlue),
                                outlineColor: .white,
                                lineWidth: 0.5,
                            )
                            
                        }
                    }
                    .position(CGPoint(x: node.x, y: node.y))
                }
            }
            
            
            if hasValidPath {
                // Path visualization for current floor
                CurrentFloorPathView(
                    pathWithLabels: pathWithLabels,
                    currentPathIndex: currentFloorPathIndex,
                    currentFloor: currentFloor
                )
                
                // Floor transition indicators
                FloorTransitionIndicators(
                    pathWithLabels: pathWithLabels,
                    currentFloor: currentFloor,
                    pathfindingManager: pathfindingManager
                )
                
                // FIXED: Current location indicator with better positioning
                if !pathWithLabels.isEmpty {
                    CurrentLocationView(
                        pathWithLabels: pathWithLabels,
                        currentPathIndex: currentFloorPathIndex,
                        pathfindingManager: pathfindingManager,
                        currentFloor: currentFloor
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
    
    // FIXED: Get current floor path index based on step progress
    private func getCurrentFloorPathIndex() -> Int {
        guard !pathWithLabels.isEmpty && !pathfindingManager.enhancedDirectionSteps.isEmpty else {
            return 0
        }
        
        let currentStepIndex = pathfindingManager.currentStepIndex
        
        // If we have steps, find the corresponding path index for the current step
        if currentStepIndex < pathfindingManager.enhancedDirectionSteps.count {
            let currentStep = pathfindingManager.enhancedDirectionSteps[currentStepIndex]
            
            // Find the closest path point to this step on the current floor
            var closestIndex = 0
            var minDistance = Double.infinity
            
            for (index, pathPoint) in pathWithLabels.enumerated() {
                let distance = sqrt(pow(Double(pathPoint.point.x - currentStep.point.x), 2) +
                                  pow(Double(pathPoint.point.y - currentStep.point.y), 2))
                if distance < minDistance {
                    minDistance = distance
                    closestIndex = index
                }
            }
            
            return closestIndex
        }
        
        return 0
    }
    
    private func findStoreByNode(_ node: Node) -> Store? {
        guard let rawTenant = node.parentLabel ?? node.label else { return nil }
        let tenantName = rawTenant.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !tenantName.isEmpty else { return nil }
        
        // Normalize function
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
        
        if let match = viewModel.allStores.first(where: { normalize($0.name) == normalizedTenant }) {
            return match
        }
        
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
    
    private func getCurrentFloorSteps() -> [EnhancedDirectionStep] {
        return pathfindingManager.enhancedDirectionSteps.filter { step in
            // Find the floor for this step
            if let pathItem = pathWithLabels.first(where: {
                abs($0.point.x - step.point.x) < 1.0 && abs($0.point.y - step.point.y) < 1.0
            }) {
                return extractFloorFromLabel(pathItem.label) == currentFloor
            }
            return false
        }
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
}

////Text Outline
//struct StrokeText: View {
//    let text: String
//    let fontSize: CGFloat
//    let textColor: Color
//    let outlineColor: Color
//    let lineWidth: CGFloat
//    let maxWidth: CGFloat?
//    
//    var body: some View {
//        ZStack {
//            Text(text)
//                .font(.system(size: fontSize, weight: .bold))
//                .offset(x: lineWidth, y: lineWidth)
//            Text(text)
//                .font(.system(size: fontSize, weight: .bold))
//                .offset(x: -lineWidth, y: -lineWidth)
//            Text(text)
//                .font(.system(size: fontSize, weight: .bold))
//                .offset(x: -lineWidth, y: lineWidth)
//            Text(text)
//                .font(.system(size: fontSize, weight: .bold))
//                .offset(x: lineWidth, y: -lineWidth)
//            // Isi utama
//            Text(text)
//                .font(.system(size: fontSize, weight: .bold))
//                .foregroundColor(textColor)
//                .lineLimit(1)
//                .frame(maxWidth: maxWidth)
//        }
//        .foregroundColor(outlineColor)
//    }
//}

// MARK: - Current Floor Path View
struct CurrentFloorPathView: View {
    let pathWithLabels: [(point: CGPoint, label: String)]
    let currentPathIndex: Int
    let currentFloor: Floor
    
    var body: some View {
        if pathWithLabels.count > 1 {
            // Completed portion
            if currentPathIndex > 0 {
                let completedPoints = Array(pathWithLabels[0...min(currentPathIndex, pathWithLabels.count - 1)]).map { $0.point }
                if completedPoints.count > 1 {
                    Path { path in
                        path.move(to: completedPoints[0])
                        for i in 1..<completedPoints.count {
                            path.addLine(to: completedPoints[i])
                        }
                    }
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.green.opacity(0.8), Color.green]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
                    )
                }
            }
            
            // Remaining portion
            if currentPathIndex < pathWithLabels.count - 1 {
                let remainingPoints = Array(pathWithLabels[currentPathIndex...]).map { $0.point }
                if remainingPoints.count > 1 {
                    Path { path in
                        path.move(to: remainingPoints[0])
                        for i in 1..<remainingPoints.count {
                            path.addLine(to: remainingPoints[i])
                        }
                    }
                    .stroke(
                        Color.gray.opacity(0.7),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: [10, 5])
                    )
                }
            }
            
            // Start and end markers for current floor
            if let firstPoint = pathWithLabels.first?.point {
                StartMarker(point: firstPoint)
            }
            
            if let lastPoint = pathWithLabels.last?.point {
                EndMarker(point: lastPoint)
            }
        }
    }
}

// MARK: - Floor Transition Indicators
struct FloorTransitionIndicators: View {
    let pathWithLabels: [(point: CGPoint, label: String)]
    let currentFloor: Floor
    let pathfindingManager: PathfindingManager
    
    var body: some View {
        ForEach(getFloorTransitionPoints(), id: \.point) { transitionPoint in
            FloorTransitionMarker(
                point: transitionPoint.point,
                transitionType: transitionPoint.transitionType,
                targetFloor: transitionPoint.targetFloor
            )
        }
    }
    
    private func getFloorTransitionPoints() -> [(point: CGPoint, transitionType: String, targetFloor: Floor)] {
        var transitionPoints: [(point: CGPoint, transitionType: String, targetFloor: Floor)] = []
        
        for i in 1..<pathWithLabels.count {
            let prevFloor = extractFloorFromLabel(pathWithLabels[i-1].label)
            let currentFloorLabel = extractFloorFromLabel(pathWithLabels[i].label)
            
            if prevFloor != currentFloorLabel && currentFloorLabel == currentFloor {
                let transitionType = getTransitionType(from: prevFloor, to: currentFloorLabel)
                transitionPoints.append((
                    point: pathWithLabels[i].point,
                    transitionType: transitionType,
                    targetFloor: currentFloorLabel
                ))
            }
        }
        
        return transitionPoints
    }
    
    private func getTransitionType(from: Floor, to: Floor) -> String {
        let floorOrder: [Floor] = [.lowerGround, .ground, .first, .second, .third, .fourth]
        
        guard let fromIndex = floorOrder.firstIndex(of: from),
              let toIndex = floorOrder.firstIndex(of: to) else {
            return "elevator"
        }
        
        let difference = abs(toIndex - fromIndex)
        return difference > 1 ? "elevator" : "escalator"
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
}

// MARK: - Individual Markers
struct StartMarker: View {
    let point: CGPoint
    
    var body: some View {
        Circle()
            .fill(Color.green)
            .frame(width: 20, height: 20)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: 20, height: 20)
            )
            .overlay(
                Image(systemName: "figure.walk")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            )
            .position(point)
    }
}

struct EndMarker: View {
    let point: CGPoint
    
    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 20, height: 20)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: 20, height: 20)
            )
            .overlay(
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            )
            .position(point)
    }
}

// MARK: - FIXED: Current Location View
struct CurrentLocationView: View {
    let pathWithLabels: [(point: CGPoint, label: String)]
    let currentPathIndex: Int
    let pathfindingManager: PathfindingManager
    let currentFloor: Floor
    
    // Calculate rotation angle with smooth direction handling for turns
    private var rotationAngle: Angle {
        guard currentPathIndex < pathWithLabels.count else {
            return .zero
        }
        
        // If at end of path, use direction from previous point
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
        
        // For smooth direction, use several points ahead if available
        var targetPoint: CGPoint
        
        // Try to get a point that's far enough ahead to avoid noise
        let lookAheadDistance = min(3, pathWithLabels.count - currentPathIndex - 1)
        if lookAheadDistance > 0 {
            targetPoint = pathWithLabels[currentPathIndex + lookAheadDistance].point
        } else {
            targetPoint = pathWithLabels[currentPathIndex + 1].point
        }
        
        // If points are too close (noise), use averaged direction
        let dx = targetPoint.x - currentPoint.x
        let dy = targetPoint.y - currentPoint.y
        let distance = sqrt(dx * dx + dy * dy)
        
        if distance < 10.0 && currentPathIndex + 1 < pathWithLabels.count - 1 {
            // Use averaged direction from multiple segments
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
        
        // Use normal direction
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

struct FloorTransitionMarker: View {
    let point: CGPoint
    let transitionType: String
    let targetFloor: Floor
    
    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(Color.orange)
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 28, height: 28)
                )
                .overlay(
                    Image(systemName: transitionType == "elevator" ? "arrow.up.arrow.down.circle" : "arrow.up.right.circle")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                )
            
            Text(transitionType.capitalized)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.orange)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.9))
                .cornerRadius(4)
        }
        .position(point)
    }
}

// MARK: - ZoomableScrollView (Enhanced)
struct ZoomableScrollView<Content: View>: View {
    let content: Content
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
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
                    // Start with a comfortable zoom level
                    scale = 3.0
                    lastScale = 3.0
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
                                lastScale = max(min(scale, 6.0), 1.0)
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
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if scale > 2.5 {
                                    scale = 2.0
                                    lastScale = 2.0
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 4.0
                                    lastScale = 4.0
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
