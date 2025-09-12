//
//  PathfindingAlgorithm.swift
//  CWSDirectoryMaps
//
//  Created by Steven Gonawan on 02/09/25.
//

import Foundation
import CoreGraphics

func aStarByLabel(graph: [String: GraphNode], startLabel: String, goalLabel: String, mode: TravelMode) -> [(point: CGPoint, label: String)]? {
    guard let startNode = graph[startLabel],
          let goalNode = graph[goalLabel] else {
        return nil
    }
    
    // Track storepath usage during pathfinding
    var usedStorepaths: Set<String> = []
    
    var openSet = PriorityQueue()
    openSet.enqueue((fScore: heuristic(from: startNode, to: goalNode), label: startLabel))
    var cameFrom = [String: String]()
    var gScore = [String: Double]()
    var fScore = [String: Double]()
    gScore[startLabel] = 0.0
    fScore[startLabel] = heuristic(from: startNode, to: goalNode)
    var openSetMembers = Set<String>([startLabel])

    while !openSet.isEmpty {
        let (_, currentLabel) = openSet.dequeue()!

        if currentLabel == goalLabel {
            let pathResult = reconstructPath(cameFrom: cameFrom, current: currentLabel, graph: graph)
            
            // Debug: Print path labels without coordinates
            if let path = pathResult {
                let pathLabels = path.map { $0.label }
                print("Path found - Labels: \(pathLabels.joined(separator: ", "))")
            }
            
            return pathResult
        }
        
        openSetMembers.remove(currentLabel)
        guard let currentNode = graph[currentLabel] else {
            continue
        }
        
        for neighbor in currentNode.neighbors {
            let neighborLabel = neighbor.node
            guard let neighborNode = graph[neighborLabel] else { continue }
            
            let labelLowercased = neighborNode.label.lowercased()
            
            switch mode {
            case .escalator:
                if labelLowercased.contains("elevator") {
                    continue
                }
            case .elevator:
                if labelLowercased.contains("escalator") {
                    continue
                }
            }
            
            // BLOCK circle-point and ellipse-point nodes completely
            if neighborNode.type == "circle-point" || neighborNode.type == "ellipse-point" {
                continue // Skip these node types entirely
            }
            
            // Handle split nodes
            if neighborNode.label.hasPrefix("split_") {
                var associatedStoreLabel: String? = nil
                for splitNeighborTuple in neighborNode.neighbors {
                    if let splitNeighborNode = graph[splitNeighborTuple.node] {
                        if splitNeighborNode.type == "ellipse-point" || splitNeighborNode.type == "circle-point" {
                            associatedStoreLabel = splitNeighborNode.parentLabel
                            break
                        }
                    }
                }
                if let storeLabel = associatedStoreLabel {
                    if storeLabel != goalLabel && storeLabel != startLabel {
                        continue
                    }
                }
            }
            // Enhanced storepath validation
            else if neighborNode.label.contains("storepath") {
                // Extract storepath base number (e.g., "317" from "storepath317-5_point_0")
                let storepathBase = extractStorepathBase(from: neighborNode.label)
                guard !storepathBase.isEmpty else {
                    continue
                }
                
                // Check if we're already using 2 storepaths and this is a new one
                if usedStorepaths.count > 3 && !usedStorepaths.contains(storepathBase) {
                    print("❌ Blocking storepath \(storepathBase): already using 2 storepaths \(usedStorepaths)")
                    continue // Block: already using 2 different storepaths
                }
                
                // Validate that storepath endpoints connect to start or goal
                let isValidStorepath = validateStorepathConnection(
                    storepathBase: storepathBase,
                    startNode: startNode,
                    goalNode: goalNode,
                    graph: graph,
                    currentLabel: neighborNode.label
                )
                
                if !isValidStorepath {
                    continue // Block: storepath doesn't connect properly to start/goal
                }
                
                // Track usage of this storepath base
                usedStorepaths.insert(storepathBase)
//                print("✅ Using storepath \(storepathBase). Total used: \(usedStorepaths)")
            }
            // Handle rect-corner nodes
            else if neighborNode.type == "rect-corner" {
                if let rectLabel = neighborNode.parentLabel {
                    if rectLabel != goalLabel && rectLabel != startLabel {
                        continue
                    }
                }
            }
            
            let tentativeGScore = (gScore[currentLabel] ?? .infinity) + neighbor.cost
            if tentativeGScore < (gScore[neighbor.node] ?? .infinity) {
                cameFrom[neighbor.node] = currentLabel
                gScore[neighbor.node] = tentativeGScore
                if let neighborGraphNode = graph[neighbor.node] {
                    fScore[neighbor.node] = tentativeGScore + heuristic(from: neighborGraphNode, to: goalNode)
                } else {
                    continue
                }
                if !openSetMembers.contains(neighbor.node) {
                    openSet.enqueue((fScore: fScore[neighbor.node]!, label: neighbor.node))
                    openSetMembers.insert(neighbor.node)
                }
            }
        }
    }
    
    return nil
}
