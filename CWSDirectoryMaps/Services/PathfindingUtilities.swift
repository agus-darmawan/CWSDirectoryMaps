//
//  PathfindingUtilities.swift
//  CWSDirectoryMaps
//
//  Created by Steven Gonawan on 02/09/25.
//

import Foundation
import CoreGraphics

/// Extracts the base storepath number (e.g., "317" from "ground_path_storepath317-5_point_0")
func extractStorepathBase(from label: String) -> String {
    // Look for "storepath" followed by digits
    let pattern = "storepath(\\d+)"
    
    if let regex = try? NSRegularExpression(pattern: pattern),
       let match = regex.firstMatch(in: label, range: NSRange(label.startIndex..., in: label)) {
        if let range = Range(match.range(at: 1), in: label) {
            return String(label[range])
        }
    }
    
    return ""
}

/// Validates that a storepath has proper connections to start or goal destinations
func validateStorepathConnection(storepathBase: String, startNode: GraphNode, goalNode: GraphNode, graph: [String: GraphNode], currentLabel: String) -> Bool {
    let proximityThreshold = 30.0
    
    // Find all storepath nodes with this base number in the graph
    var storepathEndpoints: [GraphNode] = []
    
    for (label, node) in graph {
        if label.contains("storepath\(storepathBase)") && label.contains("point_") {
            storepathEndpoints.append(node)
        }
    }
    
    guard storepathEndpoints.count >= 1 else {
        print("❌ Storepath \(storepathBase) rejected: found no endpoints")
        return false
    }
    
    // Check if ANY endpoint is connected to either start OR goal
    var hasValidConnection = false
    
    for endpoint in storepathEndpoints {
        let distToStart = heuristic(from: endpoint, to: startNode)
        let distToGoal = heuristic(from: endpoint, to: goalNode)
        
        if distToStart < proximityThreshold || distToGoal < proximityThreshold {
            hasValidConnection = true
            break // Found at least one valid connection, that's enough
        }
    }
    
//    if !hasValidConnection {
//        print("❌ Storepath \(storepathBase) rejected: no endpoints connected to start or goal")
//    } else {
//        print("✅ Storepath \(storepathBase) validated: at least one endpoint connected to start or goal")
//    }
    
    return hasValidConnection
}

/// Extracts floor prefix from a label (e.g., "ground_path" from "ground_path_storepath317-5_point_0")
func extractFloorPrefix(from label: String) -> String {
    let components = label.split(separator: "_")
    if components.count >= 2 {
        return "\(components[0])_\(components[1])"
    }
    return ""
}

func distanceFromPointToSegmentSquared(
    px: Double, py: Double,
    x1: Double, y1: Double,
    x2: Double, y2: Double
) -> (Double, (Double, Double)) {
    let dx = x2 - x1
    let dy = y2 - y1
    let lengthSq = dx*dx + dy*dy
    
    if lengthSq == 0 {
        let distSq = (px - x1)*(px - x1) + (py - y1)*(py - y1)
        return (distSq, (x1, y1))
    }
    
    let t = max(0, min(1, ((px - x1) * dx + (py - y1) * dy) / lengthSq))
    let projX = x1 + t * dx
    let projY = y1 + t * dy
    let distSq = (px - projX)*(px - projX) + (py - projY)*(py - projY)
    
    return (distSq, (projX, projY))
}

@inline(__always)
func heuristic(from: GraphNode, to: GraphNode) -> Double {
    let dx = to.x - from.x
    let dy = to.y - from.y
    return sqrt(dx*dx + dy*dy)
}

func reconstructPath(cameFrom: [String: String], current: String, graph: [String: GraphNode]) -> [(point: CGPoint, label: String)]? {
    var pathLabels: [String] = [current]
    var current = current
    pathLabels.reserveCapacity(20)
    
    while let prev = cameFrom[current] {
        pathLabels.append(prev)
        current = prev
    }
    
    let pathLabelsReversed = pathLabels.reversed()
    
    // Map each label to a tuple of (CGPoint, String)
    let pathData: [(point: CGPoint, label: String)] = pathLabelsReversed.compactMap { label in
        guard let node = graph[label] else { return nil }
        let point = CGPoint(x: CGFloat(node.x), y: CGFloat(node.y))
        // Return the complete tuple
        return (point: point, label: label)
    }
    
    if pathData.count == pathLabelsReversed.count {
        return pathData
    } else {
        return nil
    }
}
