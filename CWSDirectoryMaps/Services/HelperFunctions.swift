//
//  PriorityQueue.swift
//  CWSDirectoryMaps
//
//  Created by Steven Gonawan on 27/08/25.
//

import Foundation
import CoreGraphics

func loadGraph() -> Graph? {
    guard let url = Bundle.main.url(forResource: "pathfinding_graph", withExtension: "json") else {
        print("Error: pathfinding_graph.json not found in bundle.")
        return nil
    }
    
    do {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(Graph.self, from: data)
    } catch {
        print("Error loading or decoding graph: \(error)")
        return nil
    }
}

func buildLabelGraph(from graph: Graph) -> [String: GraphNode] {
    let nodeCount = graph.nodes.count
    var nodeDict = [String: GraphNode]()
    nodeDict.reserveCapacity(nodeCount * 2)
    
    var currentNodes = graph.nodes
    currentNodes.reserveCapacity(nodeCount * 2)
    
    var currentEdges = graph.edges
    currentEdges.reserveCapacity(graph.edges.count * 2)
    
    // 1️⃣ Pre-populate node dictionary with initial nodes
    for node in currentNodes {
        let label = node.label ?? node.id
        nodeDict[label] = GraphNode(
            id: node.id,
            label: label,
            x: node.x,
            y: node.y,
            type: node.type,
            parentLabel: node.parentLabel,
            neighbors: []
        )
    }
    
    let nodeLookup = Dictionary(uniqueKeysWithValues: currentNodes.map { ($0.id, $0) })
    
    let threshold: Double = 30.0
    var splitCount = 0
    
    let eligibleNodesForSplitting = currentNodes.filter { $0.type != "ellipse-point" }
    
    var edgesToRemove = Set<String>()
    var edgesToAdd: [Edge] = []
    var nodesToAdd: [Node] = []
    
    for candidateNode in eligibleNodesForSplitting {
        var bestEdge: Edge? = nil
        var bestProjection: (Double, Double)? = nil
        var minDistanceSq = Double.infinity

        for edge in graph.edges {
            guard
                let sourceNode = nodeLookup[edge.source],
                let targetNode = nodeLookup[edge.target]
            else { continue }
            
            if candidateNode.id == sourceNode.id || candidateNode.id == targetNode.id { continue }

            let (distSq, projPoint) = distanceFromPointToSegmentSquared(
                px: candidateNode.x, py: candidateNode.y,
                x1: sourceNode.x, y1: sourceNode.y,
                x2: targetNode.x, y2: targetNode.y
            )

            if distSq < minDistanceSq {
                minDistanceSq = distSq
                bestEdge = edge
                bestProjection = projPoint
            }
        }

        if minDistanceSq < threshold * threshold, let edgeToSplit = bestEdge, let projPoint = bestProjection {
            guard
                let sourceNode = nodeLookup[edgeToSplit.source],
                let targetNode = nodeLookup[edgeToSplit.target]
            else { continue }

            splitCount += 1
            let splitId = "split_\(splitCount)"
            
            let splitNode = Node(
                id: splitId,
                x: projPoint.0,
                y: projPoint.1,
                type: "path-point",
                rx: nil, ry: nil, angle: nil,
                label: splitId,
                parentLabel: nil,
                connectionId: nil,
            )
            nodesToAdd.append(splitNode)
            
            let edgeKey = "\(edgeToSplit.source)-\(edgeToSplit.target)"
            edgesToRemove.insert(edgeKey)
            edgesToRemove.insert("\(edgeToSplit.target)-\(edgeToSplit.source)")
            
            edgesToAdd.append(contentsOf: [
                Edge(source: sourceNode.id, target: splitId, type: "line"),
                Edge(source: splitId, target: targetNode.id, type: "line"),
                Edge(source: candidateNode.id, target: splitId, type: "line")
            ])
        }
    }
    
    currentNodes.append(contentsOf: nodesToAdd)
    currentEdges.removeAll { edge in
        edgesToRemove.contains("\(edge.source)-\(edge.target)")
    }
    currentEdges.append(contentsOf: edgesToAdd)
    
    for node in nodesToAdd {
        nodeDict[node.label ?? node.id] = GraphNode(
            id: node.id,
            label: node.label ?? node.id,
            x: node.x,
            y: node.y,
            type: node.type,
            parentLabel: node.parentLabel,
            neighbors: []
        )
    }
    
    let finalNodeLookup = Dictionary(uniqueKeysWithValues: currentNodes.map { ($0.id, $0) })
    
    // --- FIX: Removed the incorrect filtering of 'ellipse-point' nodes ---
    
    for edge in currentEdges {
        // --- FIX: Simplified the guard statement ---
        guard let source = finalNodeLookup[edge.source],
              let target = finalNodeLookup[edge.target] else {
            continue
        }
        
        let sourceLabel = source.label ?? source.id
        let targetLabel = target.label ?? target.id
        
        let dx = target.x - source.x
        let dy = target.y - source.y
        let cost = sqrt(dx*dx + dy*dy)
        
        if nodeDict[sourceLabel] == nil {
            nodeDict[sourceLabel] = GraphNode(
                id: source.id,
                label: sourceLabel,
                x: source.x,
                y: source.y,
                type: source.type,
                parentLabel: source.parentLabel,
                neighbors: []
            )
        }
        if nodeDict[targetLabel] == nil {
            nodeDict[targetLabel] = GraphNode(
                id: target.id,
                label: targetLabel,
                x: target.x,
                y: target.y,
                type: target.type,
                parentLabel: target.parentLabel,
                neighbors: []
            )
        }
        
        nodeDict[sourceLabel]?.neighbors.append((node: targetLabel, cost: cost))
        nodeDict[targetLabel]?.neighbors.append((node: sourceLabel, cost: cost))
    }
    
//    print("--- Final Graph Contents ---")
//    for (label, node) in nodeDict {
//        print("Node: \(label)")
//        for neighbor in node.neighbors {
//            print("  -> Connects to: \(neighbor.node) (Cost: \(String(format: "%.2f", neighbor.cost)))")
//        }
//    }
    
    return nodeDict
}

// In PriorityQueue.swift

func aStarByLabel(graph: [String: GraphNode], startLabel: String, goalLabel: String) -> [(point: CGPoint, label: String)]? {
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
            
            // BLOCK circle-point and ellipse-point nodes completely
            if neighborNode.type == "circle-point" || neighborNode.type == "ellipse-point" {
                continue // Skip these node types entirely
            }
            
            // Handle split nodes
            if neighborNode.label.hasPrefix("split_") {
                var associatedStoreLabel: String? = nil
                for splitNeighborTuple in neighborNode.neighbors {
                    if let splitNeighborNode = graph[splitNeighborTuple.node] {
                        if splitNeighborNode.type == "ellipse-point" {
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
                if usedStorepaths.count >= 2 && !usedStorepaths.contains(storepathBase) {
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
                print("✅ Using storepath \(storepathBase). Total used: \(usedStorepaths)")
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

/// Extracts the base storepath number (e.g., "317" from "ground_path_storepath317-5_point_0")
private func extractStorepathBase(from label: String) -> String {
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
private func validateStorepathConnection(storepathBase: String, startNode: GraphNode, goalNode: GraphNode, graph: [String: GraphNode], currentLabel: String) -> Bool {
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
    
    if !hasValidConnection {
        print("❌ Storepath \(storepathBase) rejected: no endpoints connected to start or goal")
    } else {
        print("✅ Storepath \(storepathBase) validated: at least one endpoint connected to start or goal")
    }
    
    return hasValidConnection
}

/// Extracts floor prefix from a label (e.g., "ground_path" from "ground_path_storepath317-5_point_0")
private func extractFloorPrefix(from label: String) -> String {
    let components = label.split(separator: "_")
    if components.count >= 2 {
        return "\(components[0])_\(components[1])"
    }
    return ""
}

/// Validates that a storepath has proper connections to start or goal destination

fileprivate struct PriorityQueue {
    fileprivate var heap = [(fScore: Double, label: String)]()
    
    var isEmpty: Bool { heap.isEmpty }
    
    mutating func enqueue(_ element: (fScore: Double, label: String)) {
        heap.append(element)
        siftUp(heap.count - 1)
    }

    mutating func dequeue() -> (fScore: Double, label: String)? {
        guard !heap.isEmpty else { return nil }
        heap.swapAt(0, heap.count - 1)
        let element = heap.removeLast()
        if !heap.isEmpty { siftDown(0) }
        return element
    }
    
    private mutating func siftUp(_ index: Int) {
        var childIndex = index
        var parentIndex = (childIndex - 1) / 2
        while childIndex > 0 && heap[childIndex].fScore < heap[parentIndex].fScore {
            heap.swapAt(childIndex, parentIndex)
            childIndex = parentIndex
            parentIndex = (childIndex - 1) / 2
        }
    }
    
    private mutating func siftDown(_ index: Int) {
        var parentIndex = index
        while true {
            let leftChild = 2 * parentIndex + 1
            let rightChild = 2 * parentIndex + 2
            var smallestIndex = parentIndex
            
            if leftChild < heap.count && heap[leftChild].fScore < heap[smallestIndex].fScore {
                smallestIndex = leftChild
            }
            if rightChild < heap.count && heap[rightChild].fScore < heap[smallestIndex].fScore {
                smallestIndex = rightChild
            }
            
            if smallestIndex != parentIndex {
                heap.swapAt(parentIndex, smallestIndex)
                parentIndex = smallestIndex
            } else {
                return
            }
        }
    }
}

private func distanceFromPointToSegmentSquared(
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
private func heuristic(from: GraphNode, to: GraphNode) -> Double {
    let dx = to.x - from.x
    let dy = to.y - from.y
    return sqrt(dx*dx + dy*dy)
}

private func reconstructPath(cameFrom: [String: String], current: String, graph: [String: GraphNode]) -> [(point: CGPoint, label: String)]? {
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
