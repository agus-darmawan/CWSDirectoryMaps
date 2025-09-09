//
//  PathfindingManager.swift - FIXED VERSION with Bounds Checking
//  CWSDirectoryMaps
//
//  Created by Steven Gonawan on 02/09/25.
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
}

// MARK: - Travel Mode (renamed from NavigationMode to avoid conflicts)
enum TravelMode: String, CaseIterable {
    case walk = "walk"
    case wheelchair = "wheelchair"
    
    var speed: Double { // meters per second
        switch self {
        case .walk: return 1.39 // 5 km/h
        case .wheelchair: return 0.83 // 3 km/h
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
    
    // MARK: - Distance Calculation Helper
    private func calculateDistance(from point1: CGPoint, to point2: CGPoint) -> Double {
        let dx = Double(point2.x - point1.x)
        let dy = Double(point2.y - point1.y)
        
        // Convert from graph units to meters (approximate conversion)
        // This conversion factor should be calibrated based on your actual mall dimensions
        let graphToMeterConversionFactor: Double = 0.1 // Adjust this based on your graph scale
        
        let distanceInGraphUnits = sqrt(dx * dx + dy * dy)
        return distanceInGraphUnits * graphToMeterConversionFactor
    }
    
    // MARK: - Path Distance Calculation
    private func calculateTotalPathDistance(_ pathData: [(point: CGPoint, label: String)]) -> Double {
        guard pathData.count > 1 else { return 0.0 }
        
        var totalDistance: Double = 0.0
        
        for i in 1..<pathData.count {
            let distance = calculateDistance(from: pathData[i-1].point, to: pathData[i].point)
            totalDistance += distance
        }
        totalDistance = totalDistance/100
        
        return totalDistance
    }
    
    // MARK: - Enhanced Direction Steps Generation (FIXED with bounds checking)
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
        
        // Then enhance them with distance and time information
        var enhancedSteps: [EnhancedDirectionStep] = []
        var cumulativeDistance: Double = 0.0
        
        // Map direction steps to path segments with safer bounds checking
        let stepToPathMapping = mapStepsToPathSegments(steps: directionSteps, pathData: pathData)
        
        for (index, step) in directionSteps.enumerated() {
            // Reset cumulative distance
            cumulativeDistance = 0.0

            // Hitung distance dari start sampai step ini (dengan bounds check)
            if let pathIndex = stepToPathMapping[index], pathIndex < pathData.count {
                let safeEndIndex = min(pathIndex, pathData.count - 1)

                if safeEndIndex >= 1 {
                    let segmentPoints = pathData.prefix(safeEndIndex + 1).map { $0.point }
                    cumulativeDistance = zip(segmentPoints, segmentPoints.dropFirst())
                        .map { calculateDistance(from: $0, to: $1) }
                        .reduce(0, +)
                }
            }

            // Hitung estimated time berdasarkan mode perjalanan
            let estimatedTime = cumulativeDistance / currentTravelMode.speed

            // Buat enhanced step
            let enhancedStep = EnhancedDirectionStep(
                point: step.point,
                icon: step.icon,
                description: step.description,
                shopImage: step.shopImage,
                distanceFromStart: cumulativeDistance,
                estimatedTimeFromStart: estimatedTime
            )

            enhancedSteps.append(enhancedStep)
        }
        
        self.enhancedDirectionSteps = enhancedSteps
        print("✅ Generated \(enhancedSteps.count) enhanced direction steps")
    }
    
    // MARK: - Create Basic Enhanced Steps (fallback method)
    private func createBasicEnhancedSteps(from pathData: [(point: CGPoint, label: String)]) {
        guard pathData.count >= 2 else {
            self.enhancedDirectionSteps = []
            return
        }
        
        var enhancedSteps: [EnhancedDirectionStep] = []
        let stepCount = min(5, pathData.count) // Create max 5 basic steps
        
        for i in 0..<stepCount {
            let pathIndex = (i * (pathData.count - 1)) / max(1, stepCount - 1)
            let safeIndex = min(pathIndex, pathData.count - 1)
            let pathPoint = pathData[safeIndex]
            
            // Calculate cumulative distance
            var cumulativeDistance: Double = 0.0
            for j in 1...safeIndex {
                if j < pathData.count {
                    cumulativeDistance += calculateDistance(from: pathData[j-1].point, to: pathData[j].point)
                }
            }
            
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
                description = "Continue straight"
                icon = "arrow.up"
            }
            
            let enhancedStep = EnhancedDirectionStep(
                point: pathPoint.point,
                icon: icon,
                description: description,
                shopImage: "floor-1",
                distanceFromStart: cumulativeDistance,
                estimatedTimeFromStart: estimatedTime
            )
            
            enhancedSteps.append(enhancedStep)
        }
        
        self.enhancedDirectionSteps = enhancedSteps
        print("✅ Generated \(enhancedSteps.count) basic enhanced direction steps")
    }
    
    // MARK: - Map Steps to Path Segments (FIXED with bounds checking)
    private func mapStepsToPathSegments(steps: [DirectionStep], pathData: [(point: CGPoint, label: String)]) -> [Int: Int] {
        var mapping: [Int: Int] = [:]
        
        guard !steps.isEmpty && !pathData.isEmpty else {
            return mapping
        }
        
        for (stepIndex, step) in steps.enumerated() {
            // Find the closest path point to this step with bounds checking
            var closestPathIndex = 0
            var minDistance = Double.infinity
            
            for (pathIndex, pathPoint) in pathData.enumerated() {
                let distance = calculateDistance(from: step.point, to: pathPoint.point)
                if distance < minDistance {
                    minDistance = distance
                    closestPathIndex = pathIndex
                }
            }
            
            // Ensure the mapping is within bounds
            if closestPathIndex < pathData.count {
                mapping[stepIndex] = closestPathIndex
            }
        }
        
        return mapping
    }
    
    // MARK: - Current Location Calculation (FIXED with bounds checking)
    func getCurrentLocation() -> CGPoint? {
        guard !pathWithLabels.isEmpty else { return nil }
        
        if !enhancedDirectionSteps.isEmpty && currentStepIndex < enhancedDirectionSteps.count {
            return enhancedDirectionSteps[currentStepIndex].point
        }
        
        return pathWithLabels.last?.point
    }
    
    // MARK: - Remaining Distance Calculation (FIXED with bounds checking)
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
    }
    
    // MARK: - Public Methods
    func runPathfinding(
        startStore: Store,
        endStore: Store,
        unifiedGraph: [String: GraphNode]
    ) {
        // Ensure we have graph labels
        guard let startLabel = startStore.graphLabel,
              let endLabel = endStore.graphLabel else {
            print("Missing graph labels, cannot pathfind")
            clearPath()
            return
        }
        
        // Create unique labels using floor info
        let uniqueStartLabel = "\(startLabel)"
        let uniqueEndLabel = "\(endLabel)"
        
        print("Running pathfinding from \(uniqueStartLabel) to \(uniqueEndLabel)")
        
        Task(priority: .userInitiated) {
            let foundPathData = aStarByLabel(
                graph: unifiedGraph,
                startLabel: uniqueStartLabel,
                goalLabel: uniqueEndLabel
            )
            
            await MainActor.run {
                if let pathData = foundPathData, !pathData.isEmpty {
                    print("Multi-floor path found! It has \(pathData.count) points.")
                    self.pathWithLabels = pathData
                    
                    // Calculate total distance
                    self.totalDistance = self.calculateTotalPathDistance(pathData)
                    
                    // Calculate total estimated time
                    self.totalEstimatedTime = self.totalDistance / self.currentTravelMode.speed
                    
                    // Group path by floors for better management
                    self.groupPathByFloors(pathData)
                    
                    // Generate enhanced direction steps with error handling
                    self.generateEnhancedDirectionSteps(from: pathData, unifiedGraph: unifiedGraph)
                    
                    // Reset current step index with bounds checking
                    self.currentStepIndex = 0
                    
                    print("✅ Navigation calculated:")
                    print("   Total distance: \(String(format: "%.1f", self.totalDistance))m")
                    print("   Estimated time: \(String(format: "%.1f", self.totalEstimatedTime))s (\(String(format: "%.1f", self.totalEstimatedTime/60))min)")
                    print("   Travel mode: \(self.currentTravelMode.rawValue)")
                    print("   Enhanced steps: \(self.enhancedDirectionSteps.count)")
                } else {
                    print("No multi-floor path found.")
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
        
        // Create a simplified graph for direction generation
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
        
        // Create metadata for the graph
        let metadata = Metadata(
            totalNodes: nodes.count,
            totalEdges: 0,
            nodeTypes: Array(Set(nodes.map { $0.type })),
            edgeTypes: []
        )
        
        let simpleGraph = Graph(metadata: metadata, nodes: nodes, edges: [])
        
        // Generate direction steps using the correct method signature
        do {
            self.directionSteps = directionsGenerator.generate(
                from: pathData,
                graph: simpleGraph,
                unifiedGraph: unifiedGraph
            )
            print("Generated \(self.directionSteps.count) direction steps")
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
    
    // MARK: - Step Navigation (FIXED with bounds checking)
    func moveToNextStep() {
        if currentStepIndex < enhancedDirectionSteps.count - 1 {
            currentStepIndex += 1
        }
    }
    
    func moveToPreviousStep() {
        if currentStepIndex > 0 {
            currentStepIndex -= 1
        }
    }
    
    func moveToStep(_ index: Int) {
        if index >= 0 && index < enhancedDirectionSteps.count {
            currentStepIndex = index
        }
    }
    
    // MARK: - Progress Calculation (FIXED with bounds checking)
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
    
    // MARK: - Formatting Helpers
    func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters))m"
        } else {
            return String(format: "%.1fkm", meters / 1000)
        }
    }
    
    func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds / 60)
        
        if minutes < 1 {
            return "< 1 min"
        } else if minutes < 60 {
            return "\(minutes) min\(minutes > 1 ? "s" : "")"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)min"
        }
    }
    
    // MARK: - Current Step Information (FIXED with bounds checking)
    func getCurrentStepDescription() -> String {
        guard currentStepIndex < enhancedDirectionSteps.count else { return "Arrived at destination" }
        return enhancedDirectionSteps[currentStepIndex].description
    }
    
    func getCurrentStepIcon() -> String {
        guard currentStepIndex < enhancedDirectionSteps.count else { return "mappin" }
        return enhancedDirectionSteps[currentStepIndex].icon
    }
}
