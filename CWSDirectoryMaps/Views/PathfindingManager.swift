//
//  PathfindingManager.swift
//  CWSDirectoryMaps
//
//  Created by Steven Gonawan on 02/09/25.
//

import Foundation
import CoreGraphics

// MARK: - Pathfinding Manager
class PathfindingManager: ObservableObject {
    @Published var pathWithLabels: [(point: CGPoint, label: String)] = []
    @Published var directionSteps: [DirectionStep] = []
    @Published var pathsByFloor: [Floor: [(point: CGPoint, label: String)]] = [:]
    
    private let directionsGenerator = DirectionsGenerator()
    private let pathCleaner = PathCleaner()
    
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
        
        // Derive floors from graphLabel
        func floorFromGraphLabel(_ label: String) -> Floor {
            // Example: if graphLabel is "ground_path_metro"
            if label.contains("ground") { return .ground }
            if label.contains("lowerground") { return .lowerGround }
            if label.contains("1st") { return .first }
            if label.contains("2nd") { return .second }
            if label.contains("3rd") { return .third }
            if label.contains("4th") { return .fourth }
            // Default fallback
            return .ground
            
        }
        
        let startFloor = floorFromGraphLabel(startLabel)
        let endFloor = floorFromGraphLabel(endLabel)
        
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
                if let pathData = foundPathData {
                    print("Multi-floor path found! It has \(pathData.count) points.")
                    self.pathWithLabels = pathData
                    
                    // Group path by floors for better management
                    self.groupPathByFloors(pathData)
                    
                    // Generate direction steps using the enhanced DirectionsGenerator
                    self.generateDirectionSteps(from: pathData, unifiedGraph: unifiedGraph)
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
        // Get current floor's graph for landmark detection
        guard let firstLabel = pathData.first?.label else {
            self.directionSteps = []
            return
        }
        
        let floor = extractFloorFromLabel(firstLabel)
        
        // Create a simplified graph for direction generation
        // We'll need to create this from the unified graph data
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
        
        // Extract CGPoints from pathData for the DirectionsGenerator
        let pathPoints = pathData.map { $0.point }
        
        // Generate direction steps using the correct method signature
        self.directionSteps = directionsGenerator.generate(
            from: pathData,
            graph: simpleGraph,
            unifiedGraph: unifiedGraph
        )
        
        print("Generated \(self.directionSteps.count) direction steps")
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
        pathsByFloor = [:]
    }
    
    func getPathForFloor(_ floor: Floor) -> [(point: CGPoint, label: String)] {
        return pathsByFloor[floor] ?? []
    }
}

