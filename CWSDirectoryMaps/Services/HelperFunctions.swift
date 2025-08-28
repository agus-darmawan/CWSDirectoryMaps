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
            type: node.type, // Added this line
            parentLabel: node.parentLabel,
            neighbors: []
        )
    }
    
    let threshold: Double = 30.0
    let thresholdSq = threshold * threshold
    var splitCount = 0
    
    let eligibleNodesForSplitting = currentNodes.filter { $0.type != "ellipse-point" }
    
    var edgesToRemove = Set<String>()
    var edgesToAdd: [Edge] = []
    var nodesToAdd: [Node] = []
    
    for edge in graph.edges {
        guard
            let sourceNode = currentNodes.first(where: { $0.id == edge.source }),
            let targetNode = currentNodes.first(where: { $0.id == edge.target })
        else { continue }
        
        let edgeKey = "\(edge.source)-\(edge.target)"
        
        let minX = min(sourceNode.x, targetNode.x) - threshold
        let maxX = max(sourceNode.x, targetNode.x) + threshold
        let minY = min(sourceNode.y, targetNode.y) - threshold
        let maxY = max(sourceNode.y, targetNode.y) + threshold
        
        for candidateNode in eligibleNodesForSplitting {
            if candidateNode.id == sourceNode.id || candidateNode.id == targetNode.id { continue }
            
            if candidateNode.x < minX || candidateNode.x > maxX || candidateNode.y < minY || candidateNode.y > maxY {
                continue
            }
            
            let (distSq, projPoint) = distanceFromPointToSegmentSquared(
                px: candidateNode.x, py: candidateNode.y,
                x1: sourceNode.x, y1: sourceNode.y,
                x2: targetNode.x, y2: targetNode.y
            )
            
            if distSq < thresholdSq {
                splitCount += 1
                let splitId = "split_\(splitCount)"
                
                let splitNode = Node(
                    id: splitId,
                    x: projPoint.0,
                    y: projPoint.1,
                    type: "path-point",
                    rx: nil, ry: nil, angle: nil,
                    label: splitId,
                    parentLabel: nil // Correct: split nodes don't have an original parentLabel
                )
                nodesToAdd.append(splitNode)
                
                edgesToRemove.insert(edgeKey)
                edgesToRemove.insert("\(edge.target)-\(edge.source)")
                
                edgesToAdd.append(contentsOf: [
                    Edge(source: sourceNode.id, target: splitId, type: "line"),
                    Edge(source: splitId, target: targetNode.id, type: "line"),
                    Edge(source: candidateNode.id, target: splitId, type: "line")
                ])
            }
        }
    }
    
    currentNodes.append(contentsOf: nodesToAdd)
    currentEdges.removeAll { edge in
        edgesToRemove.contains("\(edge.source)-\(edge.target)")
    }
    currentEdges.append(contentsOf: edgesToAdd)
    
    // 2️⃣.5 Update nodeDict with new split nodes (ensuring parentLabel is passed)
    for node in nodesToAdd {
        nodeDict[node.label ?? node.id] = GraphNode(
            id: node.id,
            label: node.label ?? node.id,
            x: node.x,
            y: node.y,
            type: node.type, // Added this line
            parentLabel: node.parentLabel,
            neighbors: []
        )
    }
    
    let finalEligibleNodeIds = Set(currentNodes.compactMap { node in
        node.type == "ellipse-point" ? nil : node.id
    })
    
    // 3️⃣ Build neighbors with pre-calculated distances
    for edge in currentEdges {
        guard finalEligibleNodeIds.contains(edge.source),
              finalEligibleNodeIds.contains(edge.target),
              let source = currentNodes.first(where: { $0.id == edge.source }),
              let target = currentNodes.first(where: { $0.id == edge.target }) else {
            continue
        }
        
        let sourceLabel = source.label ?? source.id
        let targetLabel = target.label ?? target.id
        
        let dx = target.x - source.x
        let dy = target.y - source.y
        let cost = sqrt(dx*dx + dy*dy)
        
        // Ensure nodes exist in dictionary (and correctly initialize GraphNode with parentLabel)
        if nodeDict[sourceLabel] == nil {
            nodeDict[sourceLabel] = GraphNode(
                id: source.id,
                label: sourceLabel,
                x: source.x,
                y: source.y,
                type: source.type, // Added this line
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
                type: target.type, // Added this line
                parentLabel: target.parentLabel,
                neighbors: []
            )
        }
        
        nodeDict[sourceLabel]?.neighbors.append((node: targetLabel, cost: cost))
        nodeDict[targetLabel]?.neighbors.append((node: sourceLabel, cost: cost))
    }
    
    return nodeDict
}

func aStarByLabel(graph: [String: GraphNode], startLabel: String, goalLabel: String) -> [CGPoint]? {
    guard let startNode = graph[startLabel],
          let goalNode = graph[goalLabel] else {
        return nil
    }
    
    var openSet = PriorityQueue()
    openSet.enqueue((fScore: heuristic(from: startNode, to: goalNode), label: startLabel))
    
    var cameFrom = [String: String]()
    var gScore = [String: Double]()
    var fScore = [String: Double]()

    gScore[startLabel] = 0.0
    fScore[startLabel] = heuristic(from: startNode, to: goalNode)
    
    var openSetMembers = Set<String>([startLabel])
    
    var analyzedStorePaths = Set<String>()

    while !openSet.isEmpty {
        let (_, currentLabel) = openSet.dequeue()!

        // --- Proximity Debugging Logic ---
        if currentLabel.hasPrefix("storepath") {
            let components = currentLabel.split(separator: "_")
            if components.count >= 2 {
                let basePath = "\(components[0])"
                
                if !analyzedStorePaths.contains(basePath) {
                    print("--- DEBUG: Proximity Analysis for \(basePath) triggered by \(currentLabel) ---")
                    
                    let proximityThreshold = 30.0
                    let point0Label = "\(basePath)_point_0"
                    let point1Label = "\(basePath)_point_1"
                    
                    if let point0Node = graph[point0Label] {
                        print("  'ellipse-center' nodes near \(point0Node.label):")
                        for candidateNode in graph.values {
                            if candidateNode.label == point0Node.label { continue }
                            let distance = heuristic(from: point0Node, to: candidateNode)
                            if distance < proximityThreshold && candidateNode.type == "ellipse-center" {
                                 print("    - Label: \(candidateNode.label), ID: \(candidateNode.id), Parent: \(candidateNode.parentLabel ?? "N/A"), Dist: \(String(format: "%.2f", distance))")
                            }
                        }
                    } else {
                        print("  Could not find node for \(point0Label)")
                    }
                    
                    if let point1Node = graph[point1Label] {
                        print("  'ellipse-center' nodes near \(point1Node.label):")
                         for candidateNode in graph.values {
                            if candidateNode.label == point1Node.label { continue }
                            let distance = heuristic(from: point1Node, to: candidateNode)
                            if distance < proximityThreshold && candidateNode.type == "ellipse-center" {
                                 print("    - Label: \(candidateNode.label), ID: \(candidateNode.id), Parent: \(candidateNode.parentLabel ?? "N/A"), Dist: \(String(format: "%.2f", distance))")
                            }
                        }
                    } else {
                        print("  Could not find node for \(point1Label)")
                    }
                    print("---------------------------------------------------------")
                    
                    analyzedStorePaths.insert(basePath)
                }
            }
        }
        // --- End Debugging Logic ---

        if currentLabel == goalLabel {
            return reconstructPath(cameFrom: cameFrom, current: currentLabel, graph: graph)
        }
        
        openSetMembers.remove(currentLabel)
        
        guard let currentNode = graph[currentLabel] else {
            continue
        }
        
        for neighbor in currentNode.neighbors {
            let neighborLabel = neighbor.node
            guard let neighborNode = graph[neighborLabel] else { continue }

            // --- Path Restriction Logic ---
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
            } else if neighborNode.label.hasPrefix("storepath") {
                var isPathToDestination = false
                let proximityThreshold = 30.0
                
                let components = neighborNode.label.split(separator: "_")
                if components.count >= 2 {
                    let basePath = "\(components[0])"
                    let point0Label = "\(basePath)_point_0"
                    let point1Label = "\(basePath)_point_1"

                    if let point0Node = graph[point0Label] {
                        if heuristic(from: point0Node, to: startNode) < proximityThreshold ||
                           heuristic(from: point0Node, to: goalNode) < proximityThreshold {
                            isPathToDestination = true
                        }
                    }

                    if !isPathToDestination, let point1Node = graph[point1Label] {
                         if heuristic(from: point1Node, to: startNode) < proximityThreshold ||
                            heuristic(from: point1Node, to: goalNode) < proximityThreshold {
                            isPathToDestination = true
                        }
                    }
                }

                if !isPathToDestination {
                    continue
                }
            }
            // --- End Path Restriction Logic ---

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
    
    // No path was found
    return nil
}



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

private func distanceFromPointToSegmentSquared(px: Double, py: Double,
                                               x1: Double, y1: Double,
                                               x2: Double, y2: Double) -> (Double, (Double, Double)) {
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

private func reconstructPath(cameFrom: [String: String], current: String, graph: [String: GraphNode]) -> [CGPoint]? {
    var pathLabels: [String] = [current]
    var current = current
    pathLabels.reserveCapacity(20)
    
    while let prev = cameFrom[current] {
        pathLabels.append(prev)
        current = prev
    }
    
    let pathLabelsReversed = pathLabels.reversed()
    
    let pathCoordinates: [CGPoint] = pathLabelsReversed.compactMap { label in
        guard let node = graph[label] else { return nil }
        return CGPoint(x: CGFloat(node.x), y: CGFloat(node.y))
    }
    
    if pathCoordinates.count == pathLabelsReversed.count {
        return pathCoordinates
    } else {
        return nil
    }
}
