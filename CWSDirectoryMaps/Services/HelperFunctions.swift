//
//  PriorityQueue.swift
//  CWSDirectoryMaps
//
//  Created by Steven Gonawan on 27/08/25.
//


//
//  HelperFunctions.swift
//  Map Pathfinding Test
//
//  Created by Steven Gonawan on 27/08/25.
//

import math_h
import Foundation

// MARK: - Loader
func loadGraph() -> Graph? {
    guard let url = Bundle.main.url(forResource: "pathfinding_graph", withExtension: "json") else {
        return nil
    }
    
    do {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Graph.self, from: data)
    } catch {
        return nil
    }
}

// MARK: - Convert JSON Graph -> Label Graph (skip ellipse nodes)
func buildLabelGraph(from graph: Graph) -> [String: GraphNode] {
    let nodeCount = graph.nodes.count
    let edgeCount = graph.edges.count
    
    var nodeDict = [String: GraphNode]()
    nodeDict.reserveCapacity(nodeCount + 100) // Reserve extra for potential splits
    
    var newNodes = graph.nodes
    newNodes.reserveCapacity(nodeCount + 100)
    
    var newEdges = graph.edges
    newEdges.reserveCapacity(edgeCount * 2)
    
    // 1️⃣ Pre-populate node dictionary
    for node in newNodes {
        let label = node.label ?? node.id
        nodeDict[label] = GraphNode(
            id: node.id,
            label: label,
            x: node.x,
            y: node.y,
            neighbors: []
        )
    }
    
    // 2️⃣ Optimized edge splitting with spatial indexing
    let threshold: Double = 30.0
    let thresholdSq = threshold * threshold // Use squared distance to avoid sqrt
    var splitCount = 0
    
    // Create spatial lookup for faster edge-node intersection checks
    let eligibleNodes = graph.nodes.filter { $0.type != "ellipse-point" }
    var edgesToRemove = Set<String>()
    var edgesToAdd: [Edge] = []
    
    for edge in graph.edges {
        guard
            let source = graph.nodes.first(where: { $0.id == edge.source }),
            let target = graph.nodes.first(where: { $0.id == edge.target })
        else { continue }
        
        let edgeKey = "\(edge.source)-\(edge.target)"
        
        // Quick bounding box check first
        let minX = min(source.x, target.x) - threshold
        let maxX = max(source.x, target.x) + threshold
        let minY = min(source.y, target.y) - threshold
        let maxY = max(source.y, target.y) + threshold
        
        for candidate in eligibleNodes {
            if candidate.id == source.id || candidate.id == target.id { continue }
            
            // Bounding box culling
            if candidate.x < minX || candidate.x > maxX || candidate.y < minY || candidate.y > maxY {
                continue
            }
            
            let (distSq, proj) = distanceFromPointToSegmentSquared(
                px: candidate.x, py: candidate.y,
                x1: source.x, y1: source.y,
                x2: target.x, y2: target.y
            )
            
            if distSq < thresholdSq {
                splitCount += 1
                let splitId = "split_\(splitCount)"
                let splitNode = Node(
                    id: splitId,
                    x: proj.0,
                    y: proj.1,
                    type: "path-point",
                    rx: nil,
                    ry: nil,
                    angle: nil,
                    label: splitId,
                    parentLabel: nil
                )
                newNodes.append(splitNode)
                
                edgesToRemove.insert(edgeKey)
                edgesToRemove.insert("\(edge.target)-\(edge.source)")
                
                edgesToAdd.append(contentsOf: [
                    Edge(source: source.id, target: splitId, type: "line"),
                    Edge(source: splitId, target: target.id, type: "line"),
                    Edge(source: candidate.id, target: splitId, type: "line")
                ])
            }
        }
    }
    
    // Apply edge modifications in batch
    newEdges.removeAll { edge in
        edgesToRemove.contains("\(edge.source)-\(edge.target)")
    }
    newEdges.append(contentsOf: edgesToAdd)
    
    // 3️⃣ Build neighbors with pre-calculated distances
    let eligibleNodeIds = Set(newNodes.compactMap { node in
        node.type == "ellipse-point" ? nil : node.id
    })
    
    for edge in newEdges {
        guard eligibleNodeIds.contains(edge.source),
              eligibleNodeIds.contains(edge.target),
              let source = newNodes.first(where: { $0.id == edge.source }),
              let target = newNodes.first(where: { $0.id == edge.target }) else {
            continue
        }
        
        let sourceLabel = source.label ?? source.id
        let targetLabel = target.label ?? target.id
        
        let dx = target.x - source.x
        let dy = target.y - source.y
        let cost = sqrt(dx*dx + dy*dy)
        
        // Ensure nodes exist in dictionary
        if nodeDict[sourceLabel] == nil {
            nodeDict[sourceLabel] = GraphNode(
                id: source.id,
                label: sourceLabel,
                x: source.x,
                y: source.y,
                neighbors: []
            )
        }
        if nodeDict[targetLabel] == nil {
            nodeDict[targetLabel] = GraphNode(
                id: target.id,
                label: targetLabel,
                x: target.x,
                y: target.y,
                neighbors: []
            )
        }
        
        nodeDict[sourceLabel]?.neighbors.append((node: targetLabel, cost: cost))
        nodeDict[targetLabel]?.neighbors.append((node: sourceLabel, cost: cost))
    }
    
    return nodeDict
}

// MARK: - Optimized A* Algorithm
func aStarByLabel(graph: [String: GraphNode], startLabel: String, goalLabel: String) -> [String]? {
    guard let startNode = graph[startLabel],
          let goalNode = graph[goalLabel] else {
        return nil
    }
    
    // Use a min-priority queue (min-heap) for efficient retrieval of the node with the lowest fScore.
    var openSet = PriorityQueue()
    openSet.enqueue((fScore: heuristic(from: startNode, to: goalNode), label: startLabel))
    
    var cameFrom = [String: String]()
    var gScore = [String: Double]()
    var fScore = [String: Double]()
    
    gScore[startLabel] = 0.0
    fScore[startLabel] = heuristic(from: startNode, to: goalNode)
    
    // A dictionary to quickly check if a node is in the priority queue,
    // useful for handling updates to a node's fScore.
    var openSetMembers = Set<String>([startLabel])

    while !openSet.isEmpty {
        let (currentFScore, currentLabel) = openSet.dequeue()!
        
        if currentLabel == goalLabel {
            return reconstructPath(cameFrom: cameFrom, current: currentLabel)
        }
        
        openSetMembers.remove(currentLabel)
        
        guard let currentNode = graph[currentLabel] else { continue }
        
        for neighbor in currentNode.neighbors {
            let tentativeGScore = (gScore[currentLabel] ?? .infinity) + neighbor.cost
            
            if tentativeGScore < (gScore[neighbor.node] ?? .infinity) {
                cameFrom[neighbor.node] = currentLabel
                gScore[neighbor.node] = tentativeGScore
                fScore[neighbor.node] = tentativeGScore + heuristic(from: graph[neighbor.node]!, to: goalNode)
                
                if !openSetMembers.contains(neighbor.node) {
                    openSet.enqueue((fScore: fScore[neighbor.node]!, label: neighbor.node))
                    openSetMembers.insert(neighbor.node)
                }
            }
        }
    }
    
    return nil // Path not found
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
        let parentIndex = (childIndex - 1) / 2
        
        while childIndex > 0 && heap[childIndex].fScore < heap[parentIndex].fScore {
            heap.swapAt(childIndex, parentIndex)
            childIndex = parentIndex
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

// MARK: - Optimized Utility Functions

// Squared distance to avoid expensive sqrt operations during comparison
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

// Straight-line heuristic (Euclidean distance)
@inline(__always)
private func heuristic(from: GraphNode, to: GraphNode) -> Double {
    let dx = to.x - from.x
    let dy = to.y - from.y
    return sqrt(dx*dx + dy*dy)
}

// Optimized path reconstruction
private func reconstructPath(cameFrom: [String: String], current: String) -> [String] {
    var path: [String] = []
    var current = current
    
    // Pre-calculate approximate path length to reduce array reallocations
    path.reserveCapacity(20)
    
    path.append(current)
    while let prev = cameFrom[current] {
        path.append(prev)
        current = prev
    }
    
    return path.reversed()
}
