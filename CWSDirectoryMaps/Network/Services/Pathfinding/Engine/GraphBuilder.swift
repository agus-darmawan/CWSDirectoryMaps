//
//  GraphBuilder.swift
//  CWSDirectoryMaps
//
//  Created by Steven Gonawan on 02/09/25.
//

import Foundation
import CoreGraphics

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
    
    for edge in currentEdges {
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
    
    return nodeDict
}
