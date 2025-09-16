//
//  ImprovedPathfindingManager.swift
//  CWSDirectoryMaps
//
//  Enhanced with better distance and time calculations
//

import Foundation
import CoreGraphics

// MARK: - Enhanced Direction Step
struct EnhancedDirectionStep: Identifiable {
    let id = UUID()
    let point: CGPoint
    let icon: String
    let description: String
    let shopImage: String
    let distanceFromStart: Double // in meters
    let estimatedTimeFromStart: Double // in seconds
    let segmentDistance: Double // distance for this specific segment
}

// MARK: - Travel Mode
enum TravelMode: String, CaseIterable {
    case escalator = "escalator"   // Prioritizes Escalators
    case elevator = "elevator"
    
    var speed: Double { // meters per second
        switch self {
        case .escalator: return 0.5
        case .elevator: return 0.2
        }
    }
    
    var icon: String {
        switch self {
        case .escalator: return "figure.walk"
        case .elevator: return "figure.roll"
        }
    }
}

// MARK: - Pathfinding Manager
class PathfindingManager: ObservableObject {
    private var cachedStartStore: Store?
    private var cachedEndStore: Store?
    
    @Published var pathWithLabels: [(point: CGPoint, label: String)] = []
    @Published var directionSteps: [DirectionStep] = []
    @Published var enhancedDirectionSteps: [EnhancedDirectionStep] = []
    @Published var pathsByFloor: [Floor: [(point: CGPoint, label: String)]] = [:]
    
    // Enhanced navigation metrics
    @Published var totalDistance: Double = 0.0 // in meters
    @Published var totalEstimatedTime: Double = 0.0 // in seconds
    @Published var currentTravelMode: TravelMode = .escalator
    @Published var currentStepIndex: Int = 0
    
    private let directionsGenerator = DirectionsGenerator()
    private let pathCleaner = PathCleaner()
    
    // Store unifiedGraph for travel mode updates
    private var cachedUnifiedGraph: [String: GraphNode] = [:]
    
    // MARK: - Fixed Distance Calculation with Floor Awareness
    private func calculateDistance(from point1: CGPoint, to point2: CGPoint, fromLabel: String? = nil, toLabel: String? = nil) -> Double {
        // Check if this is a floor change
        if let fromLabel = fromLabel, let toLabel = toLabel {
            let fromFloor = extractFloorFromLabel(fromLabel)
            let toFloor = extractFloorFromLabel(toLabel)
            
            if fromFloor != toFloor {
                // Fixed: Add 2 meters per floor difference instead of calculating map distance
                let floorDifference = abs(getFloorLevel(fromFloor) - getFloorLevel(toFloor))
                let floorChangeDistance = Double(floorDifference) * 2.0 // 2 meters per floor
                print("📏 Floor change from \(fromFloor.displayName) to \(toFloor.displayName): +\(floorChangeDistance)m")
                return floorChangeDistance
            }
        }
        
        // Regular distance calculation for same floor
        let dx = Double(point2.x - point1.x)
        let dy = Double(point2.y - point1.y)
        
        // Improved conversion factor based on typical mall scale
        let graphToMeterConversionFactor: Double = 0.1
        
        let distanceInGraphUnits = sqrt(dx * dx + dy * dy)
        return distanceInGraphUnits * graphToMeterConversionFactor
    }
    
    // Helper to get floor level for calculation
    private func getFloorLevel(_ floor: Floor) -> Int {
        switch floor {
        case .lowerGround: return -1
        case .ground: return 0
        case .first: return 1
        case .second: return 2
        case .third: return 3
        case .fourth: return 4
        }
    }
    
    // MARK: - Enhanced Path Distance Calculation
    private func calculateTotalPathDistance(_ pathData: [(point: CGPoint, label: String)]) -> Double {
        guard pathData.count > 1 else { return 0.0 }
        
        var totalDistance: Double = 0.0
        
        for i in 1..<pathData.count {
            let distance = calculateDistance(
                from: pathData[i-1].point,
                to: pathData[i].point,
                fromLabel: pathData[i-1].label,
                toLabel: pathData[i].label
            )
            totalDistance += distance
        }
        
        return totalDistance
    }
    
    // MARK: - Segment Distance Calculation
    private func calculateSegmentDistances(_ pathData: [(point: CGPoint, label: String)]) -> [Double] {
        guard pathData.count > 1 else { return [] }
        
        var segmentDistances: [Double] = []
        
        for i in 1..<pathData.count {
            let distance = calculateDistance(
                from: pathData[i-1].point,
                to: pathData[i].point,
                fromLabel: pathData[i-1].label,
                toLabel: pathData[i].label
            )
            segmentDistances.append(distance)
        }
        
        return segmentDistances
    }
    
    // MARK: - Enhanced Direction Steps Generation
    private func generateEnhancedDirectionSteps(from pathData: [(point: CGPoint, label: String)], unifiedGraph: [String: GraphNode]) {
        guard !pathData.isEmpty else {
            self.enhancedDirectionSteps = []
            return
        }
        
        // First generate regular direction steps
        generateDirectionSteps(from: pathData, unifiedGraph: unifiedGraph)
        
        // Ensure we have direction steps to work with
        guard !directionSteps.isEmpty else {
            print("⚠️ No direction steps generated, creating basic enhanced steps")
            createBasicEnhancedSteps(from: pathData)
            return
        }
        
        // Calculate segment distances for the entire path
        let segmentDistances = calculateSegmentDistances(pathData)
        
        // Then enhance them with distance and time information
        var enhancedSteps: [EnhancedDirectionStep] = []
        
        // FIXED: Better mapping of steps to path segments
        let stepToPathMapping = mapStepsToPathSegments(steps: directionSteps, pathData: pathData)
        
        for (index, step) in directionSteps.enumerated() {
            var cumulativeDistance: Double = 0.0
            var segmentDistance: Double = 0.0
            
            // FIXED: More accurate cumulative distance calculation
            if let pathIndex = stepToPathMapping[index] {
                let safeEndIndex = min(pathIndex, pathData.count - 1)
                
                // Calculate cumulative distance using the fixed distance calculation
                for i in 0..<safeEndIndex {
                    if i < pathData.count - 1 {
                        let dist = calculateDistance(
                            from: pathData[i].point,
                            to: pathData[i + 1].point,
                            fromLabel: pathData[i].label,
                            toLabel: pathData[i + 1].label
                        )
                        cumulativeDistance += dist
                    }
                }
                
                // Get segment distance for this specific step
                if pathIndex > 0 && pathIndex < pathData.count {
                    segmentDistance = calculateDistance(
                        from: pathData[pathIndex - 1].point,
                        to: pathData[pathIndex].point,
                        fromLabel: pathData[pathIndex - 1].label,
                        toLabel: pathData[pathIndex].label
                    )
                }
            }
            
            // Calculate estimated time based on travel mode
            let estimatedTime = cumulativeDistance / currentTravelMode.speed
            
            // Create enhanced step with improved data
            let enhancedStep = EnhancedDirectionStep(
                point: step.point,
                icon: step.icon,
                description: step.description,
                shopImage: step.shopImage,
                distanceFromStart: cumulativeDistance,
                estimatedTimeFromStart: estimatedTime,
                segmentDistance: segmentDistance
            )
            
            enhancedSteps.append(enhancedStep)
        }
        
        self.enhancedDirectionSteps = enhancedSteps
        
        // Debug information
        for (index, step) in enhancedSteps.enumerated() {
            print("Step \(index + 1): \(formatDistance(step.distanceFromStart)) total, \(formatTime(step.estimatedTimeFromStart)) time")
        }
    }
    
    // MARK: - Create Basic Enhanced Steps
    private func createBasicEnhancedSteps(from pathData: [(point: CGPoint, label: String)]) {
        guard pathData.count >= 2 else {
            self.enhancedDirectionSteps = []
            return
        }
        
        var enhancedSteps: [EnhancedDirectionStep] = []
        let stepCount = min(max(3, pathData.count / 10), 8) // Dynamic step count based on path length
        
        let segmentDistances = calculateSegmentDistances(pathData)
        
        for i in 0..<stepCount {
            let pathIndex = (i * (pathData.count - 1)) / max(1, stepCount - 1)
            let safeIndex = min(pathIndex, pathData.count - 1)
            let pathPoint = pathData[safeIndex]
            
            // Calculate cumulative distance more accurately
            var cumulativeDistance: Double = 0.0
            for j in 0..<safeIndex {
                if j < pathData.count - 1 {
                    let dist = calculateDistance(
                        from: pathData[j].point,
                        to: pathData[j + 1].point,
                        fromLabel: pathData[j].label,
                        toLabel: pathData[j + 1].label
                    )
                    cumulativeDistance += dist
                }
            }
            
            let segmentDistance = safeIndex > 0 && safeIndex < pathData.count ?
                calculateDistance(
                    from: pathData[safeIndex - 1].point,
                    to: pathData[safeIndex].point,
                    fromLabel: pathData[safeIndex - 1].label,
                    toLabel: pathData[safeIndex].label
                ) : 0.0
            
            let estimatedTime = cumulativeDistance / currentTravelMode.speed
            
            let description: String
            let icon: String
            
            switch i {
            case 0:
                description = "Start your journey"
                icon = currentTravelMode.icon
            case stepCount - 1:
                description = "Arrive at your destination"
                icon = "mappin.circle.fill"
            default:
                description = "Continue on your route"
                icon = "arrow.up"
            }
            
            let enhancedStep = EnhancedDirectionStep(
                point: pathPoint.point,
                icon: icon,
                description: description,
                shopImage: "floor-1",
                distanceFromStart: cumulativeDistance,
                estimatedTimeFromStart: estimatedTime,
                segmentDistance: segmentDistance
            )
            
            enhancedSteps.append(enhancedStep)
        }
        
        self.enhancedDirectionSteps = enhancedSteps
        print("✅ Generated \(enhancedSteps.count) basic enhanced direction steps")
    }
    
    // MARK: - FIXED: Map Steps to Path Segments
    private func mapStepsToPathSegments(steps: [DirectionStep], pathData: [(point: CGPoint, label: String)]) -> [Int: Int] {
        var mapping: [Int: Int] = [:]
        
        guard !steps.isEmpty && !pathData.isEmpty else {
            return mapping
        }
        
        for (stepIndex, step) in steps.enumerated() {
            var closestPathIndex = 0
            var minDistance = Double.infinity
            
            for (pathIndex, pathPoint) in pathData.enumerated() {
                // Only calculate distance on same floor to avoid cross-floor confusion
                let stepFloor = extractFloorFromLabel(pathPoint.label)
                let currentStepFloor = extractFloorFromNearestPathPoint(step.point, pathData: pathData)
                
                if stepFloor == currentStepFloor {
                    let distance = calculateDistance(from: step.point, to: pathPoint.point)
                    if distance < minDistance {
                        minDistance = distance
                        closestPathIndex = pathIndex
                    }
                }
            }
            
            mapping[stepIndex] = closestPathIndex
        }
        
        return mapping
    }
    
    // Helper to extract floor from nearest path point
    private func extractFloorFromNearestPathPoint(_ point: CGPoint, pathData: [(point: CGPoint, label: String)]) -> Floor {
        var nearestLabel = pathData.first?.label ?? ""
        var minDistance = Double.infinity
        
        for pathPoint in pathData {
            let distance = calculateDistance(from: point, to: pathPoint.point)
            if distance < minDistance {
                minDistance = distance
                nearestLabel = pathPoint.label
            }
        }
        
        return extractFloorFromLabel(nearestLabel)
    }
    
    // MARK: - Current Location Calculation
    func getCurrentLocation() -> CGPoint? {
        guard !pathWithLabels.isEmpty else { return nil }
        
        if !enhancedDirectionSteps.isEmpty && currentStepIndex < enhancedDirectionSteps.count {
            return enhancedDirectionSteps[currentStepIndex].point
        }
        
        return pathWithLabels.last?.point
    }
    
    // MARK: - Remaining Distance Calculation
    func getRemainingDistance() -> Double {
        guard currentStepIndex < enhancedDirectionSteps.count else { return 0.0 }
        
        let currentDistance = enhancedDirectionSteps[currentStepIndex].distanceFromStart
        return max(0, totalDistance - currentDistance)
    }
    
    // MARK: - Remaining Time Calculation
    func getRemainingTime() -> Double {
        let remainingDistance = getRemainingDistance()
        return remainingDistance / currentTravelMode.speed
    }
    
    // MARK: - Update Travel Mode
    func updateTravelMode(_ mode: TravelMode) {
        guard mode != currentTravelMode else { return }
        
        currentTravelMode = mode
        print("🚶‍♂️ Travel mode updated to \(mode.rawValue). Recalculating route...")

        guard let start = cachedStartStore,
              let end = cachedEndStore,
              !cachedUnifiedGraph.isEmpty else {
            return
        }

        runPathfinding(
            startStore: start,
            endStore: end,
            unifiedGraph: cachedUnifiedGraph
        )
    }
    
    // MARK: - Public Methods
    func runPathfinding(
        startStore: Store,
        endStore: Store,
        unifiedGraph: [String: GraphNode]
    ) {
        self.cachedStartStore = startStore
        self.cachedEndStore = endStore
        
        guard let startLabel = startStore.graphLabel,
              let endLabel = endStore.graphLabel else {
            print("Missing graph labels, cannot pathfind")
            clearPath()
            return
        }
        
        let uniqueStartLabel = "\(startLabel)"
        let uniqueEndLabel = "\(endLabel)"
        
        print("🗺️ Running pathfinding from \(uniqueStartLabel) to \(uniqueEndLabel)")
        
        Task(priority: .userInitiated) {
            let foundPathData = aStarByLabel(
                graph: unifiedGraph,
                startLabel: uniqueStartLabel,
                goalLabel: uniqueEndLabel,
                mode: self.currentTravelMode
            )
            
            await MainActor.run {
                if let pathData = foundPathData, !pathData.isEmpty {
                    print("✅ Multi-floor path found! It has \(pathData.count) points.")
                    self.pathWithLabels = pathData
                    
                    // Calculate total distance with improved accuracy
                    self.totalDistance = self.calculateTotalPathDistance(pathData)
                    
                    // Calculate total estimated time
                    self.totalEstimatedTime = self.totalDistance / self.currentTravelMode.speed
                    
                    // Group path by floors
                    self.groupPathByFloors(pathData)
                    
                    // Generate enhanced direction steps
                    self.generateEnhancedDirectionSteps(from: pathData, unifiedGraph: unifiedGraph)
                    
                    // Reset current step index
                    self.currentStepIndex = 0
                    
                    // Cache the unified graph for travel mode updates
                    self.cachedUnifiedGraph = unifiedGraph
                    
                    print("📍 Navigation calculated:")
                    print("   📏 Total distance: \(self.formatDistance(self.totalDistance))")
                    print("   ⏱️ Estimated time: \(self.formatTime(self.totalEstimatedTime))")
                    print("   🚶‍♂️ Travel mode: \(self.currentTravelMode.rawValue)")
                    print("   📋 Enhanced steps: \(self.enhancedDirectionSteps.count)")
                } else {
                    print("❌ No multi-floor path found.")
                    self.clearPath()
                }
            }
        }
    }
    
    private func groupPathByFloors(_ pathData: [(point: CGPoint, label: String)]) {
        var groupedPaths: [Floor: [(point: CGPoint, label: String)]] = [:]
        
        for pathItem in pathData {
            let floor = extractFloorFromLabel(pathItem.label)
            if groupedPaths[floor] == nil {
                groupedPaths[floor] = []
            }
            groupedPaths[floor]!.append(pathItem)
        }
        
        self.pathsByFloor = groupedPaths
    }
    
    private func generateDirectionSteps(from pathData: [(point: CGPoint, label: String)], unifiedGraph: [String: GraphNode]) {
        guard let firstLabel = pathData.first?.label else {
            self.directionSteps = []
            return
        }
        
        let floor = extractFloorFromLabel(firstLabel)
        
        let graphNodes = unifiedGraph.values.filter { $0.floor == floor }
        let nodes = graphNodes.map { graphNode in
            Node(
                id: graphNode.id,
                x: graphNode.x,
                y: graphNode.y,
                type: graphNode.type,
                rx: nil,
                ry: nil,
                angle: nil,
                label: graphNode.label,
                parentLabel: graphNode.parentLabel,
                connectionId: graphNode.connectionId
            )
        }
        
        let metadata = Metadata(
            totalNodes: nodes.count,
            totalEdges: 0,
            nodeTypes: Array(Set(nodes.map { $0.type })),
            edgeTypes: []
        )
        
        let simpleGraph = Graph(metadata: metadata, nodes: nodes, edges: [])
        
        self.directionSteps = directionsGenerator.generate(
            from: pathData,
            graph: simpleGraph,
            unifiedGraph: unifiedGraph
        )
        print("📋 Generated \(self.directionSteps.count) direction steps")
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
    
    func clearPath() {
        pathWithLabels = []
        directionSteps = []
        enhancedDirectionSteps = []
        pathsByFloor = [:]
        totalDistance = 0.0
        totalEstimatedTime = 0.0
        currentStepIndex = 0
    }
    
    func getPathForFloor(_ floor: Floor) -> [(point: CGPoint, label: String)] {
        return pathsByFloor[floor] ?? []
    }
    
    // MARK: - Step Navigation
    func moveToNextStep() {
        if currentStepIndex < enhancedDirectionSteps.count - 1 {
            currentStepIndex += 1
            print("📍 Moved to step \(currentStepIndex + 1)/\(enhancedDirectionSteps.count)")
        }
    }
    
    func moveToPreviousStep() {
        if currentStepIndex > 0 {
            currentStepIndex -= 1
            print("📍 Moved to step \(currentStepIndex + 1)/\(enhancedDirectionSteps.count)")
        }
    }
    
    func moveToStep(_ index: Int) {
        if index >= 0 && index < enhancedDirectionSteps.count {
            currentStepIndex = index
            print("📍 Jumped to step \(currentStepIndex + 1)/\(enhancedDirectionSteps.count)")
        }
    }
    
    // MARK: - Progress Calculation
    func getProgressPercentage() -> Double {
        guard enhancedDirectionSteps.count > 1 else { return 0.0 }
        return Double(currentStepIndex) / Double(enhancedDirectionSteps.count - 1)
    }
    
    func getCurrentStepDistance() -> Double {
        guard currentStepIndex < enhancedDirectionSteps.count else { return totalDistance }
        return enhancedDirectionSteps[currentStepIndex].distanceFromStart
    }
    
    func getCurrentStepTime() -> Double {
        guard currentStepIndex < enhancedDirectionSteps.count else { return totalEstimatedTime }
        return enhancedDirectionSteps[currentStepIndex].estimatedTimeFromStart
    }
    
    // MARK: - Improved Formatting Helpers
    func formatDistance(_ meters: Double) -> String {
        if meters < 1.0 {
            return "\(Int(meters * 100))cm"
        } else if meters < 1000 {
            return String(format: "%.0fm", meters)
        } else {
            return String(format: "%.1fkm", meters / 1000)
        }
    }
    
    func formatTime(_ seconds: Double) -> String {
        let totalMinutes = Int(seconds / 60)
        let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))
        
        if totalMinutes < 1 {
            if remainingSeconds < 30 {
                return "< 30 sec"
            } else {
                return "< 1 min"
            }
        } else if totalMinutes < 60 {
            if remainingSeconds > 0 {
                return "\(totalMinutes)min \(remainingSeconds)sec"
            } else {
                return "\(totalMinutes) min"
            }
        } else {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            return "\(hours)h \(minutes)min"
        }
    }
    
    // MARK: - Current Step Information
    func getCurrentStepDescription() -> String {
        guard currentStepIndex < enhancedDirectionSteps.count else { return "Arrived at destination" }
        return enhancedDirectionSteps[currentStepIndex].description
    }
    
    func getCurrentStepIcon() -> String {
        guard currentStepIndex < enhancedDirectionSteps.count else { return "mappin" }
        return enhancedDirectionSteps[currentStepIndex].icon
    }
    
    // MARK: - Step Distance Information
    func getCurrentStepSegmentDistance() -> Double {
        guard currentStepIndex < enhancedDirectionSteps.count else { return 0.0 }
        return enhancedDirectionSteps[currentStepIndex].segmentDistance
    }
    
    // MARK: - Navigation Status
    func isNavigationActive() -> Bool {
        return !pathWithLabels.isEmpty && !enhancedDirectionSteps.isEmpty
    }
    
    func isAtDestination() -> Bool {
        return currentStepIndex >= enhancedDirectionSteps.count - 1 && !enhancedDirectionSteps.isEmpty
    }
    
    func getCurrentDirectionStep() -> DirectionStep? {
        if !directionSteps.isEmpty && currentStepIndex < directionSteps.count {
            return directionSteps[currentStepIndex]
        }
        return nil
    }
}
