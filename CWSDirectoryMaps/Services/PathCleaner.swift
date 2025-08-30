import Foundation
import CoreGraphics

struct PathCleaner {
    
    // MARK: - Private Helper Functions
    
    /// Creates a unique string key for a CGPoint to use in dictionaries.
    private func key(for point: CGPoint) -> String {
        return "\(point.x),\(point.y)"
    }
    
    /// Calculates the Euclidean distance between two nodes.
    private func distance(from n1: Node, to n2: Node) -> Double {
        return sqrt(pow(n2.x - n1.x, 2) + pow(n2.y - n1.y, 2))
    }
    
    /// Finds the start and end index of a continuous path segment with the same parentLabel.
    private func findSegmentBoundaries(startingAt index: Int, nodes: [Node]) -> (start: Int, end: Int)? {
        guard index < nodes.count else { return nil }
        let label = nodes[index].parentLabel
        var endIndex = index
        while endIndex + 1 < nodes.count && nodes[endIndex + 1].parentLabel == label {
            endIndex += 1
        }
        return (start: index, end: endIndex)
    }
    
    /// Calculates the angle (in degrees) formed by three points (p2 is the vertex).
    /// An angle close to 180 degrees indicates a straight line.
    private func angle(p1: Node, p2: Node, p3: Node) -> Double {
        let dx1 = p1.x - p2.x
        let dy1 = p1.y - p2.y
        let dx2 = p3.x - p2.x
        let dy2 = p3.y - p2.y
        
        let dotProduct = dx1 * dx2 + dy1 * dy2
        let mag1 = sqrt(dx1 * dx1 + dy1 * dy1)
        let mag2 = sqrt(dx2 * dx2 + dy2 * dy2)
        
        if mag1 == 0 || mag2 == 0 { return 180.0 }
        
        let cosTheta = dotProduct / (mag1 * mag2)
        let clampedCosTheta = max(-1.0, min(1.0, cosTheta))
        let angleInRadians = acos(clampedCosTheta)
        return angleInRadians * 180.0 / .pi
    }
    
    /// Analyzes all possible connections between three path segments to detect intersections.
    /// Returns true if Path B should be skipped (indicating an intersection pattern).
    private func analyzeMultiPathConnections(pathA: [Node], pathB: [Node], pathC: [Node], graph: Graph) -> Bool {
        print("   - Path A nodes: \(pathA.count), Path B nodes: \(pathB.count), Path C nodes: \(pathC.count)")
        print("   - Path A labels: \(pathA.map { $0.label ?? "nil" })")
        print("   - Path B labels: \(pathB.map { $0.label ?? "nil" })")
        print("   - Path C labels: \(pathC.map { $0.label ?? "nil" })")
        
        guard pathA.count >= 1, pathB.count >= 1, pathC.count >= 1 else {
            print("   - One or more paths are empty.")
            return false
        }
        
        // Helper function to find both endpoints of a path from the graph
        func findPathEndpoints(for pathNode: Node, in graph: Graph) -> (point0: Node?, point1: Node?) {
            guard let parentLabel = pathNode.parentLabel else { return (nil, nil) }
            
            let point0 = graph.nodes.first { $0.parentLabel == parentLabel && $0.label?.contains("_point_0") == true }
            let point1 = graph.nodes.first { $0.parentLabel == parentLabel && $0.label?.contains("_point_1") == true }
            
            return (point0, point1)
        }
        
        // Get both endpoints for each path segment from the graph
        let (a0, a1) = findPathEndpoints(for: pathA[0], in: graph)
        let (b0, b1) = findPathEndpoints(for: pathB[0], in: graph)
        let (c0, c1) = findPathEndpoints(for: pathC[0], in: graph)
        
        guard let a0 = a0, let a1 = a1,
              let b0 = b0, let b1 = b1,
              let c0 = c0, let c1 = c1 else {
            print("   - Could not find all endpoints in graph.")
            return false
        }
        
        print("   - Endpoints found: A0(\(a0.label ?? "nil")), A1(\(a1.label ?? "nil")), B0(\(b0.label ?? "nil")), B1(\(b1.label ?? "nil")), C0(\(c0.label ?? "nil")), C1(\(c1.label ?? "nil"))")
        
        // Calculate all 8 distances as you suggested
        let connections = [
            ("A0-B0", distance(from: a0, to: b0)),
            ("A0-B1", distance(from: a0, to: b1)),
            ("A0-C0", distance(from: a0, to: c0)),
            ("A0-C1", distance(from: a0, to: c1)),
            ("A1-B0", distance(from: a1, to: b0)),
            ("A1-B1", distance(from: a1, to: b1)),
            ("A1-C0", distance(from: a1, to: c0)),
            ("A1-C1", distance(from: a1, to: c1))
        ]
        
        print("   - All Connection Distances:")
        for (label, dist) in connections {
            print("     \(label): \(String(format: "%.2f", dist))")
        }
        
        let proximityThreshold = 5.0
        let similarityThreshold = 1.0  // How close distances need to be to be considered "similar"
        
        // Group connections by A endpoint
        let a0Connections = connections.filter { $0.0.hasPrefix("A0") }
        let a1Connections = connections.filter { $0.0.hasPrefix("A1") }
        
        // Check if either end of A connects to both B and C with similar distances
        for aEndConnections in [a0Connections, a1Connections] {
            let aEndLabel = aEndConnections.first?.0.hasPrefix("A0") == true ? "A0" : "A1"
            
            // Find close connections to B and C from this end of A
            let closeBConnections = aEndConnections.filter { $0.0.contains("-B") && $0.1 < proximityThreshold }
            let closeCConnections = aEndConnections.filter { $0.0.contains("-C") && $0.1 < proximityThreshold }
            
            // If this end of A connects closely to both B and C
            if !closeBConnections.isEmpty && !closeCConnections.isEmpty {
                for (labelB, distB) in closeBConnections {
                    for (labelC, distC) in closeCConnections {
                        let distanceDifference = abs(distB - distC)
                        
                        print("   - \(aEndLabel) Analysis: \(labelB)(\(String(format: "%.1f", distB))) vs \(labelC)(\(String(format: "%.1f", distC))) - diff: \(String(format: "%.2f", distanceDifference))")
                        
                        if distanceDifference < similarityThreshold {
                            print("   - INTERSECTION DETECTED: \(aEndLabel) connects to both B and C with similar distances (diff: \(String(format: "%.2f", distanceDifference)))!")
                            return true
                        }
                    }
                }
            }
        }
        
        // Additional check: Look for cases where A's endpoints connect to B and C respectively with similar distances
        // This handles cases where A "bridges" between B and C
        let a0ToBest = a0Connections.filter { $0.1 < proximityThreshold }.min(by: { $0.1 < $1.1 })
        let a0ToCBest = a0Connections.filter { $0.0.contains("-C") && $0.1 < proximityThreshold }.min(by: { $0.1 < $1.1 })
        let a1ToBBest = a1Connections.filter { $0.0.contains("-B") && $0.1 < proximityThreshold }.min(by: { $0.1 < $1.1 })
        let a1ToCBest = a1Connections.filter { $0.0.contains("-C") && $0.1 < proximityThreshold }.min(by: { $0.1 < $1.1 })
        
        // Check A0->C and A1->B pattern (A bridges from C through B)
        if let a0ToC = a0ToCBest, let a1ToB = a1ToBBest {
            let bridgePattern1Diff = abs(a0ToC.1 - a1ToB.1)
            if bridgePattern1Diff < similarityThreshold {
                print("   - INTERSECTION DETECTED: Bridge pattern A0->C(\(String(format: "%.1f", a0ToC.1))) and A1->B(\(String(format: "%.1f", a1ToB.1)))!")
                return true
            }
        }
        
        // Check A0->B and A1->C pattern (A bridges from B through C)
        if let a0ToB = a0ToBest, let a1ToC = a1ToCBest {
            let bridgePattern2Diff = abs(a0ToB.1 - a1ToC.1)
            if bridgePattern2Diff < similarityThreshold {
                print("   - INTERSECTION DETECTED: Bridge pattern A0->B(\(String(format: "%.1f", a0ToB.1))) and A1->C(\(String(format: "%.1f", a1ToC.1)))!")
                return true
            }
        }
        
        print("   - No clear intersection pattern detected.")
        return false
    }

    // MARK: - Main Cleaning Function

    /// Cleans a path by identifying true intersections while preserving straight or gently curving paths.
    func clean(path: [CGPoint], graph: Graph) -> [CGPoint] {
        print("--- Path Cleaning Started ---")
        
        let coordToNodeMap = Dictionary(uniqueKeysWithValues: graph.nodes.map { (key(for: CGPoint(x: $0.x, y: $0.y)), $0) })
        let pathNodes = path.compactMap { coordToNodeMap[key(for: $0)] }
        
        guard pathNodes.count > 2 else {
            print("Path too short to clean.")
            return path
        }

        var cleanedPathNodes: [Node] = []
        var i = 0
        
        while i < pathNodes.count {
            guard let (startA, endA) = findSegmentBoundaries(startingAt: i, nodes: pathNodes) else {
                cleanedPathNodes.append(pathNodes[i])
                i += 1
                continue
            }
            
            var shouldSkipPathB = false
            var endOfPathBForSkip = endA
            
            if let (startB, endB) = findSegmentBoundaries(startingAt: endA + 1, nodes: pathNodes),
               let (startC, endC) = findSegmentBoundaries(startingAt: endB + 1, nodes: pathNodes) {
                
                let labelA = pathNodes[startA].parentLabel
                let labelB = pathNodes[startB].parentLabel
                let labelC = pathNodes[startC].parentLabel

                if let lA = labelA, let lB = labelB, let lC = labelC, lA != lB, lB != lC, lA != lC {
                    let pathANodes = Array(pathNodes[startA...endA])
                    let pathBNodes = Array(pathNodes[startB...endB])
                    let pathCNodes = Array(pathNodes[startC...endC])
                    
                    print("\n-> Multi-Path Intersection Analysis:")
                    print("   - Path A ('\(lA)', indices \(startA)...\(endA)) -> Path B ('\(lB)', indices \(startB)...\(endB)) -> Path C ('\(lC)', indices \(startC)...\(endC))")
                    
                    // Use the new multi-path analysis
                    shouldSkipPathB = analyzeMultiPathConnections(
                        pathA: pathANodes,
                        pathB: pathBNodes,
                        pathC: pathCNodes,
                        graph: graph
                    )
                    
                    if shouldSkipPathB {
                        endOfPathBForSkip = endB
                        print("   - Decision: SKIPPING Path B due to intersection pattern.")
                    } else {
                        print("   - Decision: KEEPING Path B.")
                    }
                }
            }
            
            cleanedPathNodes.append(contentsOf: pathNodes[startA...endA])
            
            if shouldSkipPathB {
                i = endOfPathBForSkip + 1
            } else {
                i = endA + 1
            }
        }
        
        var finalPath: [Node] = []
        var visited = Set<String>()
        for node in cleanedPathNodes {
            if !visited.contains(node.id) {
                finalPath.append(node)
                visited.insert(node.id)
            }
        }
        
        if let lastOriginalNode = pathNodes.last, let lastCleanedNode = finalPath.last, lastCleanedNode.id != lastOriginalNode.id {
            finalPath.append(lastOriginalNode)
        }
        
        print("\n--- Path Cleaning Finished ---\n")
        
        return finalPath.map { CGPoint(x: $0.x, y: $0.y) }
    }
}
