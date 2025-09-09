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
    case walk = "walk"
    case wheelchair = "wheelchair"
    
    var speed: Double { // meters per second
        switch self {
        case .walk: return 1.25 // 4.5 km/h (more realistic indoor walking speed)
        case .wheelchair: return 0.9 // 3.2 km/h (realistic wheelchair speed)
        }
    }
    
    var icon: String {
        switch self {
        case .walk: return "figure.walk"
        case .wheelchair: return "figure.roll"
        }
    }
}

// MARK: - Pathfinding Manager
class PathfindingManager: ObservableObject {
    @Published var pathWithLabels: [(point: CGPoint, label: String)] = []
    @Published var directionSteps: [DirectionStep] = []
    @Published var enhancedDirectionSteps: [EnhancedDirectionStep] = []
    @Published var pathsByFloor: [Floor: [(point: CGPoint, label: String)]] = [:]
    
    // Enhanced navigation metrics
    @Published var totalDistance: Double = 0.0 // in meters
    @Published var totalEstimatedTime: Double = 0.0 // in seconds
    @Published var currentTravelMode: TravelMode = .walk
    @Published var currentStepIndex: Int = 0
    
    private let directionsGenerator = DirectionsGenerator()
    private let pathCleaner = PathCleaner()
    
    // MARK: - Improved Distance Calculation
    private func calculateDistance(from point1: CGPoint, to point2: CGPoint) -> Double {
        let dx = Double(point2.x - point1.x)
        let dy = Double(point2.y - point1.y)
        
        // Improved conversion factor based on typical mall scale
        // Assuming 1 graph unit = approximately 0.5 meters (adjust based on your mall's actual scale)
        let graphToMeterConversionFactor: Double = 0.5
        
        let distanceInGraphUnits = sqrt(dx * dx + dy * dy)
        return distanceInGraphUnits * graphToMeterConversionFactor
    }
    
    // MARK: - Enhanced Path Distance Calculation
    private func calculateTotalPathDistance(_ pathData: [(point: CGPoint, label: String)]) -> Double {
        guard pathData.count > 1 else { return 0.0 }
        
        var totalDistance: Double = 0.0
        
        for i in 1..<pathData.count {
            let distance = calculateDistance(from: pathData[i-1].point, to: pathData[i].point)
            totalDistance += distance
        }
        
        return totalDistance
    }
    
    // MARK: - Segment Distance Calculation
    private func calculateSegmentDistances(_ pathData: [(point: CGPoint, label: String)]) -> [Double] {
        guard pathData.count > 1 else { return [] }
        
        var segmentDistances: [Double] = []
        
        for i in 1..<pathData.count {
            let distance = calculateDistance(from: pathData[i-1].point, to: pathData[i].point)
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
        
        // Map direction steps to path segments with safer bounds checking
        let stepToPathMapping = mapStepsToPathSegments(steps: directionSteps, pathData: pathData)
        
        for (index, step) in directionSteps.enumerated() {
            var cumulativeDistance: Double = 0.0
            var segmentDistance: Double = 0.0
            
            // Calculate cumulative distance up to this step
            if let pathIndex = stepToPathMapping[index], pathIndex < pathData.count {
                let safeEndIndex = min(pathIndex, pathData.count - 1)
                
                // Sum up all segment distances up to this point
                for i in 0..<min(safeEndIndex, segmentDistances.count) {
                    cumulativeDistance += segmentDistances[i]
                }
                
                // Get segment distance for this specific step
                if safeEndIndex > 0 && safeEndIndex <= segmentDistances.count {
                    segmentDistance = segmentDistances[safeEndIndex - 1]
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
        print("✅ Generated \(enhancedSteps.count) enhanced direction steps with improved metrics")
        
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
            for j in 0..<min(safeIndex, segmentDistances.count) {
                cumulativeDistance += segmentDistances[j]
            }
            
            let segmentDistance = safeIndex > 0 && safeIndex <= segmentDistances.count ? segmentDistances[safeIndex - 1] : 0.0
            let estimatedTime = cumulativeDistance / currentTravelMode.speed
            
            let description: String
            let icon: String
            
            switch i {
            case 0:
                description = "Start your journey"
                icon = "figure.walk"
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
    
    // MARK: - Map Steps to Path Segments
    private func mapStepsToPathSegments(steps: [DirectionStep], pathData: [(point: CGPoint, label: String)]) -> [Int: Int] {
        var mapping: [Int: Int] = [:]
        
        guard !steps.isEmpty && !pathData.isEmpty else {
            return mapping
        }
        
        for (stepIndex, step) in steps.enumerated() {
            var closestPathIndex = 0
            var minDistance = Double.infinity
            
            for (pathIndex, pathPoint) in pathData.enumerated() {
                let distance = calculateDistance(from: step.point, to: pathPoint.point)
                if distance < minDistance {
                    minDistance = distance
                    closestPathIndex = pathIndex
                }
            }
            
            if closestPathIndex < pathData.count {
                mapping[stepIndex] = closestPathIndex
            }
        }
        
        return mapping
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
        currentTravelMode = mode
        
        // Recalculate enhanced steps with new speed
        if !pathWithLabels.isEmpty {
            generateEnhancedDirectionSteps(from: pathWithLabels, unifiedGraph: [:])
        }
        
        // Update total estimated time
        totalEstimatedTime = totalDistance / currentTravelMode.speed
        
        print("🚶‍♂️ Travel mode updated to \(mode.rawValue)")
        print("📊 New estimated time: \(formatTime(totalEstimatedTime))")
    }
    
    // MARK: - Public Methods
    func runPathfinding(
        startStore: Store,
        endStore: Store,
        unifiedGraph: [String: GraphNode]
    ) {
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
                goalLabel: uniqueEndLabel
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
        
        do {
            self.directionSteps = directionsGenerator.generate(
                from: pathData,
                graph: simpleGraph,
                unifiedGraph: unifiedGraph
            )
            print("📋 Generated \(self.directionSteps.count) direction steps")
        } catch {
            print("❌ Error generating direction steps: \(error)")
            self.directionSteps = []
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
}
