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

// MARK: - Field Enum for Focus State
enum Field: Hashable {
    case start
    case destination
}

// MARK: - Floor Enum
enum Floor: String, CaseIterable, Identifiable {
    case ground = "Ground"
    case lowerground = "Lower Ground"
    
    var id: String { rawValue }
    
    var fileName: String {
        switch self {
        case .ground:
            return "ground_path"
        case .lowerground:
            return "lowerground_path"
        }
    }
}

// MARK: - Graph Container for Preloaded Data
struct FloorData {
    let graph: Graph
    let locations: [String]
}

// ✅ A new struct to hold both a location's name and its floor
struct Location: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let floor: Floor
}
