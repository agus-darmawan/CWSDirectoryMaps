//
//  Graph.swift
//  CWSDirectoryMaps
//
//  Created by Steven Gonawan on 27/08/25.
//

import Foundation

// MARK: - Models
struct Graph: Codable {
    let metadata: Metadata
    let nodes: [Node]
    let edges: [Edge]
}

struct Metadata: Codable {
    let totalNodes: Int
    let totalEdges: Int
    let nodeTypes: [String]
    let edgeTypes: [String]
}

struct Node: Codable, Identifiable, Hashable {
    let id: String
    let x: Double
    let y: Double
    let type: String
    let rx: Double?
    let ry: Double?
    let angle: Double?
    let label: String?
    let parentLabel: String?
    let connectionId: String?
}

struct Edge: Codable, Identifiable {
    let source: String
    let target: String
    let type: String
    var id: String { "\(source)-\(target)-\(type)" }
}

// MARK: - Pathfinding Node
struct GraphNode {
    var id: String
    var label: String
    let x: Double
    let y: Double
    let type: String // Add this line
    let parentLabel: String?
    var neighbors: [(node: String, cost: Double)]
    var floor: Floor?         // Add this
    var connectionId: String? 
}
