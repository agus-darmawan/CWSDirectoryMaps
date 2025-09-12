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
enum Floor: String, CaseIterable, Codable, Hashable, Identifiable {
    case fourth
    case third
    case second
    case first
    case ground
    case lowerGround

    var id: Self { self }

    // Display for menu
    var displayName: String {
        switch self {
        case .fourth: return "4th Floor"
        case .third: return "3rd Floor"
        case .second: return "2nd Floor"
        case .first: return "1st Floor"
        case .ground: return "Ground Floor"
        case .lowerGround: return "Lower Ground"
        }
    }

    // Asset names for map images
    var imageName: String {
        switch self {
        case .fourth: return "floor-4th"
        case .third: return "floor-3rd"
        case .second: return "floor-2nd"
        case .first: return "floor-1st"
        case .ground: return "floor-ground"
        case .lowerGround: return "floor-lower-ground"
        }
    }

    // Data file names for graphs/paths per floor
    var fileName: String {
        switch self {
        case .fourth: return "4th_path"
        case .third: return "3rd_path"
        case .second: return "2nd_path"
        case .first: return "1st_path"
        case .ground: return "ground_path"
        case .lowerGround: return "lowerground_path"
        }
    }

    // Custom ordering for menus (top-down)
    static var allCases: [Floor] {
        [.fourth, .third, .second, .first, .ground, .lowerGround]
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
