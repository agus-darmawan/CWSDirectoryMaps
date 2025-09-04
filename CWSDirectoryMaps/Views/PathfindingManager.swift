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
                if let path = foundPathData {
                    print("Multi-floor path found! It has \(path.count) points.")
                    self.pathWithLabels = path
                    self.directionSteps = []
                } else {
                    print("No multi-floor path found.")
                    self.clearPath()
                }
            }
        }
    }

    func clearPath() {
        pathWithLabels = []
        directionSteps = []
    }
}
