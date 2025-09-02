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
        startLabel: String,
        endLabel: String,
        startFloor: Floor,
        endFloor: Floor,
        unifiedGraph: [String: GraphNode]
    ) {
        // Guard against missing data
        guard !unifiedGraph.isEmpty,
              !startLabel.isEmpty,
              !endLabel.isEmpty else {
            clearPath()
            return
        }
        
        // Create unique labels using floor info
        let uniqueStartLabel = "\(startFloor.fileName)_\(startLabel)"
        let uniqueEndLabel = "\(endFloor.fileName)_\(endLabel)"
        
        print("Running pathfinding from \(uniqueStartLabel) to \(uniqueEndLabel)")
        
        Task(priority: .userInitiated) {
            // Call A* on the unified graph
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
